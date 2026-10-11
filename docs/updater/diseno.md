# Actualizador in-app — diseño

Rama `feature/in-app-updater`, worktree `../Wallet-updater`, base `master` (ba9997e).

## Alcance

- Fuente: `https://api.github.com/repos/Usiless/Wallet/releases/latest`, sin token ni credenciales.
- La consulta es **solo manual**: un ítem «Buscar actualizaciones» en Ajustes. La app no hace red por su cuenta al iniciar ni en segundo plano.
- Flujo: consulta → comparación semántica con la versión instalada → diálogo (versión + notas, «Actualizar» / «Más tarde») → descarga con progreso → verificación SHA-256 → permiso «instalar apps desconocidas» → instalador del sistema.

## Componentes y flujo

```
SettingsScreen ──tap──▶ checkForUpdates(context, ref)            [B, presentation/update_flow.dart]
                          │
                          ├─ UpdateService.checkForUpdate()       [A, data/update_service.dart]
                          │     ├─ caché 1 h en SettingsRepository (app_settings de Drift)
                          │     ├─ GET releases/latest (http)
                          │     ├─ ReleaseInfo.fromGitHubJson      [A, domain/release_info.dart]
                          │     └─ AppVersion.compareTo            [A, domain/app_version.dart]
                          ├─ UpdateDialog (versión, notas)        [B, presentation/update_dialog.dart]
                          ├─ DownloadDialog ─▶ UpdateService.download(release, onProgress, cancel)
                          │                       ├─ stream a <cache>/updates/<apk>.part
                          │                       ├─ SHA-256 contra el asset .sha256 (si existe)
                          │                       └─ renombra a <cache>/updates/<apk>
                          ├─ ApkInstaller.canInstall() / openInstallSettings()   [B, data/apk_installer.dart]
                          │     └─ al volver (AppLifecycleState.resumed) re-verifica
                          └─ ApkInstaller.install(file) ─▶ MethodChannel 'finanzas_locales/updater'
                                                          └─ UpdateInstaller.kt: FileProvider + ACTION_VIEW
```

Registro: cada paso pasa por `updaterLog` (`data/update_log.dart`, A). B lo usa para «permiso», «instalación lanzada» y errores del instalador.

## Contratos

### Ya creados por el orquestador (no modificar)

`lib/core/errors/app_exception.dart` (la clase base es `sealed`, por eso la subclase vive ahí):

```dart
enum UpdateFailure { offline, rateLimited, server, download, integrity, cancelled, installer }

final class UpdateException extends AppException {
  const UpdateException(this.failure, super.message, {super.technicalDetail});
  final UpdateFailure failure;
}
```

`message` siempre en español y apto para el usuario (`userMessage(e)` lo devuelve tal cual). El detalle técnico va en `technicalDetail` y en el log.

`lib/app/providers.dart`:

```dart
final updateServiceProvider = Provider((ref) {
  final service = UpdateService(settings: ref.watch(settingsProvider));
  ref.onDispose(service.close);
  return service;
});
final apkInstallerProvider = Provider((ref) => const ApkInstaller());
```

### A — `lib/features/updater/domain/app_version.dart`

```dart
final class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);
  final int major, minor, patch;

  /// Acepta `X.Y.Z`, con `v`/`V` inicial opcional y sufijo `+build` opcional (se ignora).
  /// Cualquier otra forma (prerelease `-beta`, menos de tres partes, negativos) → null.
  static AppVersion? tryParse(String raw);

  @override int compareTo(AppVersion other);   // numérico: 1.10.0 > 1.9.0
  bool operator >(AppVersion other);
  bool operator <(AppVersion other);
  @override bool operator ==(Object other);
  @override int get hashCode;
  @override String toString();                  // "1.2.3", sin "v"
}
```

### A — `lib/features/updater/domain/release_info.dart`

```dart
final class ReleaseAsset {
  const ReleaseAsset({required this.name, required this.downloadUrl, required this.size});
  final String name;
  final Uri downloadUrl;   // browser_download_url
  final int size;          // bytes
}

final class ReleaseInfo {
  const ReleaseInfo({required this.tag, required this.version, required this.notes,
      required this.apk, this.checksum});
  final String tag;              // "v1.2.3"
  final AppVersion version;
  final String notes;            // campo body ('' si es null)
  final ReleaseAsset apk;        // primer asset cuyo nombre termina en .apk
  final ReleaseAsset? checksum;  // "<apk>.sha256" si existe; si no, el único *.sha256

  /// null si el tag no es una versión válida o si no hay asset .apk.
  static ReleaseInfo? fromGitHubJson(Map<String, dynamic> json);

  /// Formato propio de la caché (borde de serialización).
  Map<String, Object?> toJson();
  static ReleaseInfo? fromJson(Map<String, Object?> json);
}

final class DownloadProgress {
  const DownloadProgress(this.received, this.total);
  final int received;
  final int? total;                // null si se desconoce
  double? get fraction;            // received/total acotado a 0..1, o null
}
```

### A — `lib/features/updater/data/update_service.dart`

```dart
final class UpdateService {
  UpdateService({
    required SettingsRepository settings,
    http.Client? client,                                // por defecto http.Client()
    Future<String> Function()? installedVersion,        // por defecto PackageInfo.fromPlatform().version
    Future<Directory> Function()? downloadDirectory,    // por defecto <getTemporaryDirectory()>/updates
    DateTime Function()? now,                           // por defecto DateTime.now().toUtc()
    String repository = 'Usiless/Wallet',
  });

  static const cacheDuration = Duration(hours: 1);

  /// Release más nueva que la instalada, o null si no hay.
  /// Usa la caché si tiene menos de [cacheDuration]; la comparación con la versión
  /// instalada se hace siempre al leer (la caché guarda la release, no el veredicto).
  /// Lanza UpdateException: offline (SocketException/timeout/ClientException),
  /// rateLimited (403 o 429), server (otro código ≠ 200/404, JSON inválido).
  /// 404 (repo sin releases) → null y se cachea como «sin release».
  Future<ReleaseInfo?> checkForUpdate();

  /// Descarga el APK a downloadDirectory, verifica tamaño y SHA-256 y devuelve el archivo final.
  /// Escribe en '<nombre>.part' y renombra solo tras verificar; borra el parcial en cualquier error.
  /// Borra APKs viejos del directorio antes de empezar.
  /// Si [cancel] completa, aborta y lanza UpdateException(cancelled).
  /// Sin asset .sha256: instala igual y lo registra en el log como advertencia.
  /// Hash distinto: borra el archivo, registra y lanza UpdateException(integrity).
  Future<File> download(
    ReleaseInfo release, {
    void Function(DownloadProgress progress)? onProgress,
    Future<void>? cancel,
  });

  void close();   // cierra el http.Client solo si lo creó el servicio
}
```

Claves de caché en `app_settings`: `updater_checked_at` (ISO-8601 UTC) y `updater_latest_release` (JSON de `ReleaseInfo.toJson()` o la cadena `none`). Un 403/429/sin red no escribe la caché.

Peticiones a la API: headers `Accept: application/vnd.github+json`, `X-GitHub-Api-Version: 2022-11-28`, `User-Agent: Cabal-updater`; timeout de 15 s. Descarga: timeout de inactividad de 30 s entre fragmentos. El archivo .sha256 acepta el formato de `sha256sum` (`<hex>  <archivo>`): se toma el primer token de 64 hex, sin distinguir mayúsculas.

### A — `lib/features/updater/data/update_log.dart`

```dart
/// Registro del actualizador. Va a logcat también en release (debugPrint) con prefijo
/// "[updater]". Nunca registra datos personales: solo versiones, URLs, tamaños, códigos y hashes.
void updaterLog(String message, {Object? error});
```

### B — `lib/features/updater/data/apk_installer.dart`

```dart
final class ApkInstaller {
  const ApkInstaller();
  static const _channel = MethodChannel('finanzas_locales/updater');

  /// true si Android permite que Cabal instale paquetes (siempre true en API < 26).
  Future<bool> canInstall();
  /// Abre «Instalar apps desconocidas» para Cabal (ACTION_MANAGE_UNKNOWN_APP_SOURCES).
  Future<void> openInstallSettings();
  /// Lanza el instalador del sistema. PlatformException → UpdateException(installer).
  Future<void> install(File apk);
}
```

Canal `finanzas_locales/updater`, métodos `canInstall` → bool, `openInstallSettings` → null, `install` con argumento `{'path': String}` → null. Códigos de error nativos: `install_not_allowed`, `invalid_apk_path`, `installer_unavailable`.

### B — `lib/features/updater/presentation/`

```dart
/// update_flow.dart — punto de entrada desde Ajustes.
Future<void> checkForUpdates(BuildContext context, WidgetRef ref);

/// update_dialog.dart — true = «Actualizar», false/null = «Más tarde».
Future<bool?> showUpdateDialog(BuildContext context, ReleaseInfo release);

/// download_dialog.dart — no se cierra tocando afuera; tiene «Cancelar».
/// Devuelve el APK verificado, o null si se canceló. Otros errores se propagan.
Future<File?> showDownloadDialog(BuildContext context, UpdateService service, ReleaseInfo release);
```

Textos mínimos (preferencia del proyecto): título «Versión X.Y.Z», notas en un área desplazable, botones «Más tarde» / «Actualizar», «Cancelar». Resultado sin novedad: SnackBar «Ya tenés la última versión.» Errores: SnackBar con `userMessage(e)`.

## Asignación de archivos

| Archivo | Dueño |
|---|---|
| `pubspec.yaml`, `pubspec.lock` | Orquestador (ya hecho: `http ^1.6.0`, `package_info_plus ^10.2.2`) |
| `lib/core/errors/app_exception.dart` | Orquestador (ya hecho) |
| `lib/app/providers.dart` | Orquestador (ya hecho) |
| `docs/updater/diseno.md` | Orquestador |
| `lib/features/updater/domain/app_version.dart` | A |
| `lib/features/updater/domain/release_info.dart` | A |
| `lib/features/updater/data/update_service.dart` | A |
| `lib/features/updater/data/update_log.dart` | A |
| `test/features/updater/app_version_test.dart` | A |
| `test/features/updater/release_info_test.dart` | A |
| `test/features/updater/update_service_test.dart` | A |
| `lib/features/updater/data/apk_installer.dart` | B |
| `lib/features/updater/presentation/update_flow.dart` | B |
| `lib/features/updater/presentation/update_dialog.dart` | B |
| `lib/features/updater/presentation/download_dialog.dart` | B |
| `lib/features/settings/presentation/settings_screen.dart` | B (solo el ítem «Buscar actualizaciones») |
| `android/app/src/main/AndroidManifest.xml` | B |
| `android/app/src/main/res/xml/updater_file_paths.xml` | B |
| `android/app/src/main/kotlin/py/finanzaslocales/finanzas_locales/UpdateInstaller.kt` | B |
| `android/app/src/main/kotlin/py/finanzaslocales/finanzas_locales/MainActivity.kt` | B (solo registrar el canal) |
| `test/features/updater/update_dialog_test.dart` | B (opcional) |

## Dependencias

- `http ^1.6.0`: cliente y `MockClient` (`package:http/testing.dart`) para tests.
- `package_info_plus ^10.2.2`: `PackageInfo.fromPlatform()` → `version`.
- Ya presentes y reutilizadas: `crypto` (`sha256`), `path_provider` (`getTemporaryDirectory`), `path`, `flutter_riverpod`.
- No se agregan `shared_preferences` ni paquetes de instalación (ver Bitácora).

## Bitácora

**Restricciones encontradas en el reconocimiento (2026-10-11)**

- `Usiless/Wallet` devolvía 404 sin token (privado). Decisión del usuario: hacerlo público; la app no lleva credenciales.
- El manifest de release no tenía `INTERNET` y `PRODUCT_BASELINE.md` dice «sin cuenta de usuario ni servidor». Decisión del usuario: la consulta es **solo manual** desde Ajustes; no hay verificación al iniciar. Se agrega `INTERNET` al manifest principal porque la consulta manual la necesita.
- La app ya persiste ajustes en `app_settings` (Drift) vía `SettingsRepository`. Decisión del usuario: la caché de 1 h va ahí en lugar de `shared_preferences`.
- `AppException` es `sealed`: `UpdateException` tiene que vivir en `app_exception.dart`.
- `minSdk 24`: `canRequestPackageInstalls()` existe desde API 26; por debajo se devuelve true y el sistema usa el ajuste global de orígenes desconocidos.
- Base de `master` con `.gitignore` modificado sin commitear en el repo principal; ese cambio no entra en esta rama.

**Alternativas evaluadas**

- *Instalador*: `open_filex` / `install_plugin` / canal propio. Se elige **canal propio** (`UpdateInstaller.kt` + `androidx.core.content.FileProvider`): la app ya usa `MethodChannel`s y `androidx.core` (NotificationCompat), son ~60 líneas, no suma un plugin de terceros con permisos propios y permite manejar `canRequestPackageInstalls` y `ACTION_MANAGE_UNKNOWN_APP_SOURCES` sin otro paquete.
- *Directorio de descarga*: `getTemporaryDirectory()/updates` (= `cacheDir/updates` en Android), expuesto por FileProvider con `<cache-path path="updates/">`. Solo se comparte esa subcarpeta; el sistema puede limpiarla y no entra en backups.
- *Logging*: `debugPrint` con prefijo en lugar de `developer.log`, porque `developer.log` no llega a logcat en release y el pedido es poder ver el rastro (en especial un hash que no coincide).
- *Caché*: se guarda la release, no el veredicto, para que tras instalar la nueva versión la caché no ofrezca de nuevo la misma.
- *Sin `.sha256`*: se instala igual y se registra una advertencia (el pedido dice «si la release incluye…»). Se verifica igualmente el tamaño contra `size` del asset.

**Decisiones durante la implementación y revisión**

- *Fase 2 (A)*: un 200 con JSON válido pero sin `.apk` o con tag inválido → `UpdateFailure.server`, sin escribir caché. Versión instalada no parseable → `server`. Tamaño distinto a `apk.size` → `download` («quedó incompleta»), no `integrity`; `integrity` queda reservado al hash. `.sha256` ilegible o con HTTP ≠ 200 → `download`.
- *Fase 2 (B)*: diálogo extra «Permitir instalar desde Cabal» (Cancelar / Abrir ajustes) antes de llevar a los ajustes de Android; tras abrirlos se espera `onResume` con `AppLifecycleListener` (timeout 5 min) y se re-verifica. Cancelar en cualquier punto sale sin mensaje. `settings_screen.dart` suma un campo `_checkingUpdates` para deshabilitar el ítem mientras corre el flujo.
- *Ronda 1 de revisión*: sin bloqueantes. Correcciones: imports sin uso (warning de analyze); nombres de assets que no sean un nombre de archivo simple o URLs no `https` se descartan (evita escribir fuera de `updates/`); la cancelación se atiende también durante el `.sha256` y la espera de cabeceras; se cierra el stream ante status ≠ 200; parseo del `.sha256` tolerante a BOM y líneas extra; un error en `onProgress` no aborta la descarga; el diálogo muestra solo el porcentaje. Se descartó cambiar la authority del FileProvider: `context.packageName` en runtime es el `applicationId`. Se mantienen los 2 infos `prefer_initializing_formals` (los parámetros nombrados públicos asignan a campos privados).
- *Ronda 2 de revisión*: cancelar durante el cálculo del SHA-256 todavía devolvía el archivo y abría el instalador. Se corrige con un chequeo de cancelación después de recibir, después de verificar y antes de renombrar. La lectura de caché aplica las mismas validaciones de nombre/`https`, y un `.sha256` descartado se registra en el log.
- *Ronda 3 de revisión*: convergió. Residual aceptado (menor): si «Cancelar» llega entre el `rename` y el `return` (milisegundos de I/O), el flujo sigue e Android muestra su propio diálogo de instalación, que el usuario igual puede rechazar.
- *Estado final*: `flutter analyze` sin errores ni warnings (2 infos); `flutter test` 440 pruebas OK (37 del actualizador); `flutter build apk --debug` compila (incluye Kotlin, manifest y FileProvider).
- *Pendiente fuera del código*: el repo `Usiless/Wallet` tiene que ser público para que la API responda sin token; mientras sea privado, la consulta devuelve 404 y la app informa «Ya tenés la última versión.». Sin prueba en dispositivo real del flujo completo de instalación.

## Cómo publicar una actualización

1. Subir la versión en `pubspec.yaml` incrementando **siempre** el build number (p. ej. `1.2.0+5` → `1.3.0+6`). Android rechaza instalar un `versionCode` menor o igual al instalado.
2. Compilar el APK de release firmado con **la misma keystore** de siempre (`android/key.properties`). Con otra firma, Android rechaza la actualización y obliga a desinstalar, lo que borra los datos locales.
3. Generar el hash: `sha256sum app-release.apk > app-release.apk.sha256` (mismo directorio, para que el archivo contenga el nombre del APK).
4. Crear la release en GitHub con tag `vX.Y.Z` (igual a la versión de `pubspec.yaml`, sin el `+build`), no marcada como borrador ni prerelease (`/releases/latest` las ignora). Las notas van en la descripción.
5. Adjuntar `app-release.apk` y `app-release.apk.sha256`.

Ejemplo con `gh`:

```bash
flutter build apk --release
cd build/app/outputs/flutter-apk
sha256sum app-release.apk > app-release.apk.sha256
gh release create v1.3.0 app-release.apk app-release.apk.sha256 \
  --repo Usiless/Wallet --title "v1.3.0" --notes-file NOTAS.md
```

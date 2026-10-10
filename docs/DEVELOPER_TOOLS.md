# Herramientas de desarrollo

## Configuración

Las herramientas se habilitan únicamente en modo debug y con `ENABLE_DEVELOPER_TOOLS=true`. La bandera es constante de compilación, no un ajuste guardado por el usuario. Sin bandera, con `false`, en profile y en release quedan desactivadas. Android aplica la misma condición a simulación, SMS y diagnóstico. Wallet y la opción de registro automático son funciones normales, activadas aparte en Configuración.

- `config/development.json`: bandera activada para pruebas.
- `config/production.json`: bandera desactivada para uso normal.
- `lib/core/config/feature_flags.dart`: definición central de Dart.
- `.vscode/launch.json`: perfiles «Wallet — uso normal» (profile, por defecto), «Wallet — uso normal (debug)» y «Wallet — herramientas de desarrollo» (debug), disponibles en VSCodium con la extensión Dart/Flutter.

Para ejecutar con herramientas:

```bash
flutter run --dart-define-from-file=config/development.json
```

Para ejecutar sin herramientas:

```bash
flutter run --dart-define-from-file=config/production.json
```

Los mismos argumentos se pueden agregar al comando con el que el usuario genera su APK. Cambiar el archivo requiere volver a ejecutar o compilar; hot reload no modifica las constantes de compilación. El usuario genera los APK desde VSCodium.

## Organización

Las pantallas de pruebas están en `lib/features/developer_tools/presentation/` y se acceden desde Más → Herramientas de desarrollo. Las rutas de desarrollo no se registran con la bandera apagada. Las pantallas también comprueban la bandera y el puente nativo impide activar captura experimental o diagnóstico sin ella; Wallet real se controla por su preferencia normal.

Se agrupan allí:

- Simulador de notificaciones de compra; la detección real de Wallet se configura fuera de este menú.
- Pruebas de alertas Sudameris en Google Messages.
- Activación, visualización, exportación sanitizada y eliminación del diagnóstico.
- Lectura e inspección de notificaciones activas de Wallet y Google Play Services, con creación explícita de una propuesta.

El menú no duplica los ajustes de Wallet ni el acceso de Android, disponibles en Configuración → Google Wallet y en las herramientas que requieren permisos. La cola se procesa al abrir o volver a la app y al actualizar Movimientos pendientes.

Los parsers y la lógica de candidatos permanecen en `core/notifications`: Wallet ya forma parte del uso normal y SMS sigue experimental. Cuentas, movimientos, presupuestos, reportes, exportaciones y backups permanecen en el uso normal.

Con la bandera apagada se apagan SMS y diagnóstico y se descartan eventos experimentales de la cola al abrir la app. Los eventos reales de Wallet se conservan y procesan si Wallet está habilitado, según la preferencia de registro automático. Al volver a la versión de desarrollo, hay que habilitar de nuevo las pruebas deseadas. Los movimientos confirmados y los candidatos anteriores no se eliminan. Una bandera no cifra ni elimina retroactivamente datos de diagnóstico existentes.

## Límites actuales

### Probar una compra real que sigue visible

1. Ejecutar o generar la versión debug con `config/development.json` desde VSCodium.
2. Abrir Más → Herramientas de desarrollo → Lectura de notificaciones existentes.
3. Conceder el acceso en Android si hace falta, volver y pulsar «Consultar notificaciones». Si el lector todavía no se conectó, esperar unos segundos y consultar de nuevo.
4. Seleccionar la notificación y revisar título, texto, texto ampliado, subtexto, resumen y líneas, junto con importe, comercio, identificador y cuenta sugeridos.
5. Pulsar «Crear propuesta para revisar» solo si se desea probar el registro. En la bandeja, confirmar exige una cuenta: se deja vacía si no hay coincidencia única y se permite crear cuentas.

La consulta no exige activar la detección continua ni el modo diagnóstico, no descarta notificaciones y no escribe eventos o gastos. Muestra contenido original en memoria mientras permanece la pantalla. Al crear una propuesta, se usa la deduplicación habitual y el contenido original solo se retiene si está activado el diagnóstico. No lee el historial de Wallet ni recupera notificaciones descartadas.

Al confirmar un gasto de Wallet se guarda el identificador detectado como alias de la cuenta elegida, si no existe un alias equivalente en ella, independientemente de su fuente. Las próximas compras solo sugieren cuenta cuando ese alias coincide con una cuenta activa única. No hay conexión con la cuenta de Google ni modificación de Wallet; identificadores iguales en distintas cuentas requieren selección manual.

Para repetir una compra de prueba, eliminar primero su movimiento y usar «Repetir prueba tras eliminar el movimiento» en la inspección. Reabre la misma propuesta sin afectar saldos y vuelve a exigir confirmación. Está bloqueado sin la bandera de desarrollo y mientras exista un movimiento activo para esa compra. Si se registra otra vez, deshacer la eliminación del movimiento antiguo queda bloqueado para evitar duplicar el gasto.

Implementación basada en [`NotificationListenerService.getActiveNotifications`](https://developer.android.com/reference/android/service/notification/NotificationListenerService#getActiveNotifications()), disponible después de que Android conecta el lector autorizado. Android puede limitar el acceso según el dispositivo o el perfil.

La base activa/WAL usan SQLite3MultipleCiphers y la cola AES-GCM, con clave protegida por Android Keystore; los backups portables usan una contraseña independiente. La integración y migración en teléfono siguen pendientes de validación; ver [arquitectura](ARCHITECTURE.md) y [backup](BACKUP_FORMAT.md). La limpieza de eventos vencidos ocurre al abrir/procesar, no mediante un temporizador persistente. No se debe presentar la retención de 24 horas como una garantía de eliminación automática mientras la app está cerrada.

## Criterio de diseño y fuentes

Dart documenta constantes de compilación para habilitar depuración y experimentos y permite eliminar código inalcanzable. Flutter separa debug, profile y release. Para este proyecto se usa esa separación más una bandera explícita. Si luego necesitamos instalaciones paralelas, servidores distintos o branding diferente, convendrá sumar flavors; no son necesarios para este menú local.

- https://dart.dev/libraries/core/environment-declarations
- https://docs.flutter.dev/testing/build-modes

## Simulador de compras

Más → Herramientas de desarrollo → Notificaciones de prueba. La lista inicial usa nombres de la captura aportada por el usuario y puede editarse (uno por línea). Elegir un comercio o «Aleatorio», escribir un identificador de tarjeta y definir un rango de importes PYG. Un rango con mínimo y máximo iguales permite fijar el importe.

«Enviar notificación de prueba» exige acceso al lector y permiso para mostrar notificaciones. Android muestra una notificación de esta app, marcada PRUEBA, durante hasta un minuto; no suplanta a Google Wallet. El lector la captura con metadatos de prueba y el mismo reconocimiento. Con la app visible, el lector avisa de la captura y la procesa; también se puede volver a la app o actualizar Movimientos pendientes. El acceso a la bandeja en Inicio muestra el contador de propuestas; la pestaña Inicio muestra solo un punto. Las transacciones tienen fuente `developerTest` y descripción `[PRUEBA]`; afectan los saldos y enseñan asociaciones en esta instalación. La primera compra con asociaciones nuevas requiere confirmación; si se activa el registro automático, compras siguientes reconocidas pueden registrarse solas.

Wallet real no necesita la bandera; inspeccionar notificaciones existentes y repetir una compra eliminada siguen siendo herramientas de desarrollo.

## Comprobación de las barreras

Comprobación estática del 2026-10-10 sobre `app-profile.apk` y `app-debug.apk` en modo «uso normal» (`config/production.json`), con `dexdump` y `strings`, sin compilar ni instalar nada nuevo:

- `BuildConfig` de profile: `BUILD_TYPE=profile`, `DEVELOPER_TOOLS_ENABLED=false`. De debug en uso normal: `DEVELOPER_TOOLS_ENABLED=false`.
- `app/build.gradle.kts`: el valor por defecto es `false`; solo el tipo `debug` lo toma de `--dart-define`, y release lo hereda en `false`.
- Dart: `developerToolsEnabled = kDebugMode && fromEnvironment(...)` es una constante falsa en profile y release. En el `libapp.so` de profile no aparecen las pantallas ni las rutas de simulador, diagnóstico o inspector; solo permanece la clave `sms_notifications_enabled`, que la app fuerza a `false`.
- Pruebas de host: `test/features/developer_tools/developer_tools_test.dart`.

No sustituye el recorrido en el teléfono con un profile o release instalado, ni cubre el listener real.

# Desarrollo y verificación

Para quien desarrolla o prueba Cabal. Las decisiones están en [PRODUCT_BASELINE](PRODUCT_BASELINE.md); el estado por capacidad, en [ROADMAP](ROADMAP.md). Esta guía no autoriza implementar propuestas pendientes.

## Entorno

`pubspec.yaml` requiere Dart ^3.13.0 y Flutter >=3.47.0; CI fija Flutter 3.47.6 (con Dart 3.13.5). Android mínimo API 24; `compileSdk` y `targetSdk` vienen de Flutter. Gradle usa Java/Kotlin 17 y AGP 9 con Kotlin integrado; ver `android/app/build.gradle.kts`, `android/settings.gradle.kts` y `android/gradle.properties`. La versión instalada se comprueba con `flutter --version`.

Para ejecutar en el teléfono se necesita Flutter con Android SDK y un JDK compatible. No hacen falta claves comerciales ni servidor.

## Preparar y comprobar

Desde la raíz del repositorio:

```bash
flutter pub get
flutter analyze
flutter test
flutter test --dart-define-from-file=config/development.json test/features/developer_tools/developer_tools_test.dart
```

`flutter pub get` puede actualizar el lockfile: revisar los cambios. Si se cambian las tablas o declaraciones de Drift, regenerar con `dart run build_runner build` y revisar el código generado. Las pruebas usan bases descartables en memoria; no apuntarlas a la instalación del usuario. Un error de permisos en la caché del SDK no demuestra un error de la app.

Para ejecutar:

```bash
flutter run --dart-define-from-file=config/production.json
```

Los perfiles de VSCodium están en `.vscode/launch.json`. Para SMS, diagnóstico, inspección y simulador, ver [DEVELOPER_TOOLS](DEVELOPER_TOOLS.md). Wallet real se configura en Más → Google Wallet, con el acceso especial concedido en Android.

## Generación y firma, a cargo del usuario

El usuario genera los APK desde VSCodium; el asistente solo los compila ante una petición explícita. Como referencia: `flutter build apk --debug` produce `build/app/outputs/flutter-apk/app-debug.apk`; profile, `flutter build apk --profile --dart-define=ENABLE_DEVELOPER_TOOLS=false`. Release usa `android/key.properties` (plantilla `android/key.properties.example`) y un keystore privado que no se comparte. Sin esas propiedades, release no usa la clave debug.

Para crear una clave de subida (solo al preparar una distribución):

```bash
keytool -genkeypair -v \
  -keystore android/keystore/finanzas-locales-upload.jks \
  -alias finanzas_locales -keyalg RSA -keysize 2048 -validity 10000
cp android/key.properties.example android/key.properties
```

`.github/workflows/flutter.yml` ejecuta análisis y pruebas, sin compilar APK.

Los recursos de marca se regeneran con `python3 tool/generate_launcher_icons.py` (Pillow); el concepto aprobado está en `design/branding/cabal-icon-concept.png`. Mantener `finanzas_locales` y `py.finanzaslocales.finanzas_locales` para conservar la compatibilidad de datos e instalación.

## Verificación en Android

Las pruebas de unidad y de widgets no cubren el listener, Keystore, el ciclo de vida, el Storage Access Framework, la biometría ni las barreras del binario, y no hay pruebas de integración en dispositivo. Esos recorridos se hacen a mano con el APK que prepara el usuario, en una instalación de prueba con datos descartables y un backup previo. Registrar versión, modo, dispositivo/API, pasos, esperado y observado; no copiar notificaciones personales a la documentación. Qué está verificado y qué falta: [ROADMAP](ROADMAP.md#verificación-pendiente-en-android).

Recorrido de referencia:

1. Terminar el onboarding sin cuentas; crear banco, efectivo, ahorro y dos tarjetas. Comprobar las acciones de la segunda tarjeta y el patrimonio (ahorro menos deuda).
2. Registrar ingreso de 1.000.000, gasto de 100.000, transferencia de 200.000 entre activos y compra con crédito de 90.000; pagar 30.000 desde el banco. Transferencia y pago no suman gasto. Repetir con división y con cuotas conservando totales enteros.
3. Compra de 1.000.000 en 10 cuotas con la primera fecha por defecto y otra diferida: el crédito queda comprometido completo, 100.000 por mes y el pago no es otro gasto. Probar día 31 y febrero, y que las cuotas futuras figuren como «Previstas».
4. Editar, clonar, eliminar y deshacer; devolver parcialmente y conciliar. Contrastar historial, saldos, presupuesto y reportes. Probar más de 50 movimientos, filtros, mes vacío y rango parcial.
5. Gasto bancario en tres cuotas con categorías: no cambia el saldo hasta confirmar. Pagar una parte desde otra cuenta, trasladar el resto y comprobar que la cuota siguiente propone esa cuenta. Editar, eliminar y deshacer un pago enlazado, y comprobar deuda, categorías, presupuesto y reporte.
6. Usar y editar plantillas; programar una plantilla y comprobar un solo pendiente por vencimiento, con fin de mes, atrasos y pausa. Cerrar la app no debe prometer registros financieros en segundo plano.
7. Recordatorios: conceder y denegar permisos, pagar, cancelar y editar una obligación; con la app cerrada, tras reiniciar y tocando el aviso en arranque en frío y con la app visible (solo abre el pago, nunca lo confirma). Las alarmas son inexactas.
8. Wallet real, con consentimiento y acceso Android: compra reconocida, alias ambiguo, comercio nuevo, notificación actualizada y coincidencia con un programado. Captura con la app no visible y procesamiento al volver; sin avisos de revisión ni duplicados.
9. Backup y restauración en una instalación de prueba: errores de contraseña, corrupción y esquema; actualización de una base antigua; Keystore y bloqueo, con y sin biometría. Restaurar con un formulario abierto: el formulario debe rechazarse. No probar la pérdida de claves sobre la única copia de los datos.
10. Presupuestos: editar nombre y objetivo, activar repetición, editar desde un mes intermedio conservando los anteriores y restaurar un backup sin duplicados. Anillos en 0, 100 y 120 %, y cinco pestañas conservando el mes.
11. Formulario de movimiento: salir con cambios sin guardar, «Guardar y crear otro», editar y clonar un gasto dividido, plantillas, pago de tarjeta desde Cuentas y creación de categoría.
12. Accesibilidad: teclado, texto ampliado, TalkBack, tema oscuro, importe completo sin recorte y el símbolo ₲ en las fuentes reales.
13. Barreras: en debug de desarrollo comprobar simulador y diagnóstico; en uso normal, profile y release, que rutas y operaciones experimentales estén bloqueadas. Ver [la comprobación estática](DEVELOPER_TOOLS.md#comprobación-de-las-barreras).

## Depuración

Si la app parece bloquearse con el depurador conectado, revisar Run and Debug → Breakpoints en VSCodium: desactivar All Exceptions y mantener Uncaught Exceptions. Flutter pausa también las excepciones capturadas cuando se detiene en todas, y la pausa se ve como un ANR de entrada. Si se pausa, capturar el mensaje y la pila Dart (sin importes ni datos personales); si se desconecta sin pausa visible, conservar la consola Dart/Flutter y el registro ANR. Ver [Flutter debugger](https://docs.flutter.dev/tools/devtools/debugger) y [diagnóstico de ANR](https://developer.android.com/topic/performance/anrs/diagnose-and-fix-anrs).

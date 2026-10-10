# Desarrollo y verificación

Para quien desarrolla o prueba Cabal. Las decisiones están en [PRODUCT_BASELINE](PRODUCT_BASELINE.md); la matriz y prioridades, en [ROADMAP](ROADMAP.md). Esta guía no autoriza implementar iniciativas pendientes.

## Entorno

`pubspec.yaml` requiere Dart ^3.13.0 y Flutter >=3.47.0; CI fija Flutter 3.47.6. La documentación anterior registra Dart 3.13.5 con ese SDK. Android mínimo API 24; `compileSdk`/`targetSdk` vienen de Flutter. Gradle configura Java/Kotlin 17, AGP 9 con Kotlin integrado y `android.newDsl=false`. Consultar `android/app/build.gradle.kts`, `android/settings.gradle.kts` y `android/gradle.properties`. La versión efectivamente instalada debe comprobarse con `flutter --version`.

Se necesita Flutter con Android SDK y JDK compatibles para ejecutar en teléfono. Para pruebas locales, Node ejecuta el modelo HTML y Flutter las pruebas Dart/widgets. No se requieren claves comerciales ni servidor.

## Preparar y comprobar

Desde la raíz del repositorio:

```bash
flutter --version
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter test --no-pub --dart-define-from-file=config/development.json test/features/developer_tools/developer_tools_test.dart
node --check prototype/cabal/app.js
node --check prototype/cabal/model.js
node prototype/cabal/model.test.js
```

`flutter pub get` puede actualizar resolución/caché: revisar los cambios del lockfile. Si se cambia el esquema o las declaraciones de Drift, regenerar explícitamente con `dart run build_runner build` y revisar el código generado; no hace falta para editar documentación. No ejecutar esa regeneración durante una auditoría de solo documentos.

Flutter puede necesitar escritura en la caché del SDK fuera del repositorio incluso con `--no-pub`. Un error de permisos del SDK no demuestra un error de la app. Las pruebas usan bases descartables; no apuntarlas a la instalación del usuario.

Para ejecutar, por iniciativa del desarrollador:

```bash
flutter run --dart-define-from-file=config/production.json
```

Los perfiles de VSCodium están en `.vscode/launch.json`. Para SMS, diagnóstico, inspección y simulador consultar [DEVELOPER_TOOLS](DEVELOPER_TOOLS.md). Wallet real se configura en Más → Google Wallet, con acceso especial concedido en Android. No necesita permiso para emitir avisos de revisión: esos avisos no se emiten.

## Generación y firma, a cargo del usuario

El usuario genera APKs desde VSCodium; el asistente solo los compila ante petición explícita. Como referencia manual: `flutter build apk --debug` produce `build/app/outputs/flutter-apk/app-debug.apk`. Release usa `android/key.properties` (plantilla `android/key.properties.example`) y un keystore privado; no compartir claves ni contraseñas. `flutter build appbundle --release` requiere configurar firma para distribuir. Sin propiedades release no se utiliza automáticamente la clave debug.

Referencia manual para crear una clave de subida y copiar la plantilla (solo cuando el usuario prepare distribución):

```bash
keytool -genkeypair -v \
  -keystore android/keystore/finanzas-locales-upload.jks \
  -alias finanzas_locales -keyalg RSA -keysize 2048 -validity 10000
cp android/key.properties.example android/key.properties
```

Completar contraseñas/ruta en `android/key.properties`, conservar el keystore en lugar seguro y revisar que claves/propiedades privadas no se compartan. Estos comandos no se ejecutaron en esta revisión.


**CI-01 aplicado · 2026-10-07:** `.github/workflows/flutter.yml` conserva análisis/tests y ya no compila APK automáticamente. No se disparó el workflow.

Los recursos de marca se regeneran manualmente con `python3 tool/generate_launcher_icons.py` (Pillow); el concepto aprobado está en `design/branding/cabal-icon-concept.png`. Mantener `finanzas_locales` y `py.finanzaslocales.finanzas_locales` para compatibilidad de datos/instalación.

## Verificación Android pendiente

Estado 2026-10-10: pasos 1–3 y 6 (V01 y V02) verificados por el usuario sin incidencias. Recordatorios del traslado final (pasos 1–5) verificados por el usuario el mismo día. Wallet real: comercio nuevo y compra repetida verificados. Pendientes: Wallet ambiguo, notificación actualizada, coincidencia con programado y paso 7 (barreras profile/release).

Usar una instalación de prueba y datos descartables. El APK lo prepara el usuario. Registrar versión, modo, dispositivo/API, pasos, esperado/observado y evidencia sanitizada; no copiar notificaciones personales a la documentación.

1. Terminar onboarding sin cuentas; crear banco, efectivo, ahorro y dos tarjetas. Verificar acciones de la segunda tarjeta y patrimonio con ahorro menos deuda.
2. Registrar ingreso 1.000.000, gasto 100.000, transferencia 200.000 entre activos y compra de crédito 90.000; pagar 30.000 desde banco. Banco baja 330.000 desde el saldo posterior al ingreso, destino sube 200.000 y deuda neta sube 60.000. Transferencia y pago no suman gasto. Repetir con división y cuotas conservando totales enteros.
3. Editar, clonar, eliminar/deshacer; devolver parcialmente y conciliar saldo. Contrastar historial, saldos, presupuesto y reportes con el calendario mensual único. Probar más de 50 movimientos, filtros, mes vacío y rango parcial.
4. Usar/editar plantillas; procesar fin de mes, atrasos, pausa y coincidencia con Wallet. Cerrar la app no debe prometer registros financieros en segundo plano.
5. Con consentimiento y acceso Android, capturar Wallet real: caso reconocido, alias ambiguo, comercio nuevo, notificación actualizada y compra coincidente con programado. Comprobar captura con app no visible y procesamiento al volver; sin avisos de revisión ni duplicados.
6. Crear backup y restaurar en instalación de prueba; verificar errores de contraseña, corrupción, esquema y conservación de datos. Probar actualización de base antigua, Keystore, regreso al bloqueo y alternativa sin biometría. No probar pérdida de claves sobre la única copia de datos.
7. Comprobar ausencia de accesos CSV/JSON y conservación de importados históricos y backup. En debug de desarrollo comprobar simulador/diagnóstico; en uso normal, profile y release comprobar que rutas y operaciones experimentales estén bloqueadas.

Las pruebas unitarias y widgets no prueban listener, Keystore, ciclo de vida, SAF, biometría ni barreras del binario Android. `integration_test/app_smoke_test.dart` es un smoke test; no se ejecutó en esta auditoría ni cubre por sí solo esta lista. No presentar este procedimiento pendiente como ejecución realizada.


## H01 y traslado Flutter · 2026-10-07

`BudgetService` comparte el reparto exacto de `ReportService`. La regresión se ejecuta sin bandera ni omisión: 101 dividido 51/50, cuotas 33/33/35, categorías 16/16/19 y 17/17/16. [Resultados de host y límites](IMPLEMENTATION_PLAN.md#traslado-autorizado-a-flutter--2026-10-07).

Añadir al recorrido Android: compra 1.000.000/10 con primera fecha por defecto y diferida; crédito comprometido completo, 100.000 por mes, pago sin otro gasto. Probar día 31/febrero y vuelta al día 31, editar/restaurar calendario antiguo sin desplazar fechas, futuras «Previstas» al consultar otro mes. Verificar anillos 0/100/120%, filtros Aplicar/Cancelar, cinco pestañas conservando mes y FAB sin tapar contenido; texto ampliado, TalkBack y tema oscuro. No afirmar cobro real ni ejecutar tareas financieras con la app cerrada.

## Bloqueo de Wallet con depurador · 2026-10-07

La captura «isn't responding» corresponde a un ANR. Se leyeron mediante ADB los registros históricos de salida y DropBox **solo de Cabal**, sin iniciar la app ni compilar/instalar nada. Dos ANR de entrada (espera de 10 segundos) muestran la misma cadena nativa: `dart::Debugger::PauseException` → `dart::Debugger::Pause` → `dart::Monitor::Wait`. Se simbolizó con `addr2line` el `libflutter.so` debug ya existente, comprobando igualdad de BuildId con ambas trazas. Evidencia de una pausa del depurador ante una excepción; no identifica su mensaje/origen ni demuestra un defecto de Wi-Fi, Wallet o Keystore. El usuario vio «se desconectó», compatible con el desenlace del bloqueo; causa inicial de excepción pendiente.

Flutter documenta que detenerse en **todas** las excepciones pausa incluso las capturadas. Para la próxima prueba del usuario en VSCodium: revisar Run and Debug → Breakpoints; desactivar All Exceptions, mantener Uncaught Exceptions y retirar breakpoints involuntarios. Si se pausa, capturar mensaje y pila Dart antes de continuar; omitir importes/notificaciones/datos personales. Si vuelve a desconectarse sin pausa visible, conservar consola Dart/Flutter y registro ANR correspondiente. Cambiar el ajuste del depurador no prueba por sí solo que la excepción original esté corregida. Fuentes oficiales consultadas el 2026-10-07: [Flutter debugger](https://docs.flutter.dev/tools/devtools/debugger), [diagnóstico ANR Android](https://developer.android.com/topic/performance/anrs/diagnose-and-fix-anrs).

Pendientes con APK generado por el usuario:

1. Inicio y Movimientos: «+» despliega tres FAB, cada uno abre el tipo correcto; Atrás/tocar fuera cierra, navegación no queda tapada. Revisar banner, texto ampliado, TalkBack y temas claro/oscuro.
2. Presupuesto: editar nombre/objetivo; activar repetición; comprobar siguiente mes en instalación de prueba y editar desde mes intermedio conservando anteriores; pausar, reabrir y restaurar backup comprobado sin duplicados. No cambiar reloj ni restaurar destructivamente sobre la única copia de datos reales.
3. Wallet: abrir varias veces con/sin depuración Wi-Fi siguiendo el diagnóstico anterior, activar/revocar acceso y volver. Los fallos de carga/ajustes simulados se prueban en host; no validan listener ni acreditan la corrección del ANR real.

## Verificación Android pendiente del traslado final

Sin generar APK desde el asistente. Una vez que el usuario instale su compilación, usar datos descartables y backup previo:

1. Crear gasto bancario en tres cuotas y categorías; comprobar que no cambia saldo hasta confirmar. Pagar una parte desde otra cuenta, trasladar resto y comprobar sugerencia de esa cuenta en la cuota siguiente.
2. Editar/eliminar/deshacer un pago enlazado y comprobar deuda, categorías, presupuesto y reporte. Restaurar una copia anterior con un formulario abierto: el formulario obsoleto debe rechazarse.
3. Programar una plantilla, reabrir y comprobar un solo pendiente por vencimiento, sin registro pagado automático. Cambiar calendario futuro y comprobar que no duplica vencimientos ni cambia pagos históricos.
4. Conceder/denegar permisos, bloquear el canal, pagar/cancelar/editar una obligación y verificar que la agenda no conserve avisos obsoletos ni borre avisos válidos por una actualización ajena.
5. Probar aviso con app cerrada, suspensión, reinicio, cambio horario/zona y restricciones del fabricante. Tocar aviso en arranque frío y con app visible: solo abre el pago, nunca lo confirma. Las alarmas son inexactas.
6. Recorrer móvil con teclado, texto ampliado y TalkBack; revisar importe completo, anillos activables, FAB y regreso a navegación. Verificar fuente/símbolo ₲ en Android: los fixtures gráficos de host no acreditan su fallback real.
7. Repetir Wallet opcional/autorregistro y comprobar que posibles coincidencias con pendientes exigen revisión. Verificar que SMS, inspector, diagnóstico y simuladores permanezcan bloqueados en profile/release y desactivados por defecto.

[Informe y comandos ejecutados en host](evaluation/flutter-port-2026-10-07/REPORT.md). Gradle/SAF/Keystore/entrega de Android no quedan validados por las capturas o los dobles de MethodChannel.

## APK solicitado expresamente · 2026-10-08/09

La prohibición de compilar automáticamente sigue vigente. Para esta entrega el usuario pidió explícitamente el APK; se utiliza `flutter build apk --profile --no-pub --dart-define=ENABLE_DEVELOPER_TOOLS=false`. Profile usa AOT y la firma debug existente sin configurar ni compartir una clave release privada. El APK final se encuentra en `build/app/outputs/flutter-apk/app-profile.apk`; confirmar resultados/hash/firma en [el informe](evaluation/flutter-port-2026-10-07/REPORT.md). No se instaló ni se borraron datos del teléfono. Compilar no marca los recorridos Android anteriores como ejecutados.

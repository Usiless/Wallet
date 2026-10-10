# Task7 · trabajo repetido y recordatorios nativos · 2026-10-08

## Resultado y alcance

Se corrigieron mecanismos demostrables: guardar un ajuste idéntico ya no actualiza su registro; una emisión de pendientes reutiliza la lista hidratada y no vuelve a consultarla desde el listener; una agenda idéntica no vuelve al canal nativo durante el uso en primer plano. Las operaciones nativas de reemplazar agenda y consumir la acción inicial se ejecutan en un worker serial y devuelven resultados mediante `runOnUiThread`. Abrir/reanudar fuerza una reconciliación para renovar permisos/ventana temporal. No se afirma resuelto el congelamiento real: no hay dispositivo conectado ni reproducción Android del «no abría; cerré».

Sin cambios de dominio financiero, N+1, prototipo, funciones de producto, permisos, barreras de desarrollo ni inicio antes de runApp. No se generó APK.

## Cambios

- `SettingsRepository.write`: transacción que compara el valor existente antes de upsert; preserva fecha y evita invalidaciones cuando no cambió. La transacción conserva orden/atomicidad frente a escrituras concurrentes.
- `FinanzasApp`: reutiliza el último valor emitido, mantiene coalescing de solicitudes y fuerza lectura autoritativa dentro del bloque de manejo de fallos al abrir/reanudar. El listener no añade otra hidratación. Se retiene el bridge inicial para limpiarlo en dispose: la prueba de desmontaje detectó que el anterior `ref.read()` en dispose lanza StateError con Riverpod actual. Log RED específico preservado.
- `PaymentReminderCoordinator`: encapsula la generación original, conserva históricos/validación y guarda firma exacta del payload después de respuesta nativa exitosa. Una excepción no actualiza la caché, por lo que se reintenta. Se conserva la función pública previa como wrapper sin caché persistente para compatibilidad. `force` evita saltar reconciliación al reanudar, incluso con permiso denegado anteriormente.
- `ReminderWorker`: un ExecutorService de un solo hilo por motor, sin hilo por petición. `MainActivity` deja permission/requestPermission en el hilo de plataforma; reemplazar y consumir pasan al worker. La acción consume captura el objeto Intent al recibir la petición para que un onNewIntent posterior no cambie el objetivo. El cierre drena trabajos aceptados sin esperar en UI; receptor/agenda conservan sus métodos synchronized y semántica previa.

## Evidencia RED → GREEN

1. `performance-red.log`: guardar el mismo ajuste cambiaba updatedAt; una preferencia ajena provocaba un replaceSchedule (esperado cero).
2. `performance-count-red.log`: misma preferencia provocaba dos lecturas de pendientes (esperado una). No umbral temporal ni benchmark host presentado como rendimiento Android.
3. `performance-native-red.log`: pruebas del runner con la ejecución síncrona original extraída fallaron porque storage corría en el hilo llamador y consume no esperaba al reemplazo. Tras usar executor serial, seis pruebas Kotlin (cuatro políticas anteriores y dos worker) pasan.
4. `performance-dispose-red.log`: las aserciones de optimización pasaron, pero desmontar FinanzasApp lanzó StateError por `ref.read` en dispose. Bridge retenido corrige el error observado.
5. `performance-directed-green.log`: ajustes, aplicación real con DB descartable/canales externos simulados, caché/reintento/force, coordinador, scheduler y Wallet; resultado registrado en el log.
6. `performance-native-green.log`: seis tests JVM y compilación offline de **todos** los fuentes Kotlin de la app contra Android/Flutter ya disponibles. Sin Gradle assemble ni APK. Warnings de Java 25/Jansi/Unsafe pertenecen al compilador offline; no son errores de la app.

Los canales simulados sustituyen Android/Keystore/AlarmManager inaccesibles en host; las pruebas ejercitan FinanzasApp, Riverpod, SQLite, SettingsRepository y PendingPaymentService reales. El conteo después de preferencia ajena pasa de dos listas/una llamada nativa a una lista/cero llamadas; editar el horario sigue enviando una actualización. La prueba nativa verifica hilo, FIFO, despacho explícito de respuestas y continuidad después de fallo, no tiempos de disco Android.

Comandos:

```sh
flutter test --no-pub test/core/settings/settings_write_regression_test.dart test/app/reminder_work_regression_test.dart test/core/notifications/payment_reminder_cache_regression_test.dart test/features/payments/payment_reminder_coordinator_test.dart test/core/notifications/payment_reminder_test.dart test/features/notifications/wallet_settings_test.dart test/features/notifications/wallet_automation_test.dart
python3 .superpowers/sdd/flutter-port-2026-10-07/task7-native-check.py
```

Análisis y suite Flutter completos coordinados por root para evitar ejecución duplicada. Al redactar, root informa lint de estilo asignado a integración y un fallo de expectativa antigua de Plantillas en file picker, también asignado a integración; no se presenta la suite global como verde hasta su cierre. No hay fallo funcional dirigido pendiente de Task7.

## Límites y revisión

- La hidratación N+1 sigue siendo coste dependiente del volumen, fuera de esta ronda. La preparación de plantillas y coincidencias Wallet todavía pueden leer listas completas.
- La cola de capturas Wallet mantiene commits síncronos nativos; no se modificó en este cambio focalizado.
- El BroadcastReceiver todavía ejecuta sus operaciones síncronamente; la agenda mantiene un monitor synchronized que puede causar espera si coincide con el worker. No se acredita ausencia total de bloqueo del hilo Android ni fin del ANR.
- El camino de apertura previo a runApp y la obtención nativa de clave no cambian. El ANR histórico con pausa de depurador no prueba la causa del congelamiento actual.
- Hace falta comprobar apertura fría con el APK del usuario, permisos, captura real, entrega/tap y reanudación en Android.

Diff: `task7.diff`. Baselines app/MainActivity/settings provistos por root en `performance-before`; el baseline del coordinador se reconstruyó exactamente de la lectura inicial registrada antes de la modificación, porque no estaba incluido en aquellas tres copias. Archivos nuevos aparecen contra /dev/null. Si integración aplica cambios de estilo después de este informe, regenerar diff final.

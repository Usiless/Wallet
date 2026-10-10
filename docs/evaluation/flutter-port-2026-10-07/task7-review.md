# Task7 · revisión independiente de especificación y calidad

2026-10-08. Revisión de lectura del brief, investigación, diff, informe final, AGENTS.md, PRODUCT_BASELINE y fuentes/pruebas afectadas. Sin ejecutar pruebas, modificar producción/prototipo ni generar APK.

## Veredicto

**Aprobado dentro del alcance Task7. Sin hallazgos de regresión nuevos que requieran corrección.** No hay severidad/disparador/línea de defecto que informar. La aceptación corresponde a los mecanismos demostrados y al cambio focalizado; no acredita solución del congelamiento real ni una suite global verde.

## Especificación

- `lib/core/settings/settings_repository.dart:22`: compara dentro de una transacción antes de escribir. Una escritura idéntica preserva timestamp y evita la invalidación por upsert; cambios reales siguen escribiéndose. No cambia claves/valores de producto.
- `lib/app/app.dart:48`: recibe el valor hidratado del provider, conserva el último valor y solicita otra pasada cuando hay cambios durante una reconciliación. La firma representa el payload completo, no un count. Una actualización de hora/revisión/identidad o desaparición de un pago cambia la agenda; los pagos saldados/cancelados siguen filtrándose. No observé pérdida nueva de cambios en el recorrido normal serializado.
- `lib/app/app.dart:195`: la apertura/reanudación mantiene una lectura autoritativa y fuerza reconciliación. `payment_reminder_coordinator.dart:65` actualiza firma solo después de completarse el canal sin excepción. `false` es permiso denegado, no un error de persistencia: la agenda nativa igualmente se reemplaza y la reanudación fuerza un nuevo intento. Históricos y validación conservan la semántica anterior.
- `MainActivity.kt:57–85`: replace/consume se encolan en un único worker; permisos y peticiones de UI mantienen el handler de plataforma. Consume captura el Intent antes de encolar y `onNewIntent` sustituye la referencia de actividad, sin cambiar la capturada.
- `ReminderWorker.kt:13–24`: ejecución FIFO de un executor único, respuesta a través del dispatcher UI, excepciones convertidas a Result y cierre mediante shutdown que drena trabajos aceptados. `MainActivity.kt:200` cierra el worker en cleanup; no espera en UI. Los métodos synchronized de agenda mantienen la exclusión con receiver/rebuild. No se descartaron peticiones históricas ni se añadieron hilos por petición.
- `lib/app/app.dart:206`: conservar el bridge para desmontarlo corrige el StateError observado; no altera autorización Wallet ni bandera de desarrollo.

## Calidad y evidencia inspeccionada

Los tests nuevos observan efectos útiles: timestamp persistido, consultas reales SQLite y llamadas de canal desde FinanzasApp, edición de hora que sí llega al canal, clear de agenda, fuerza explícita y reintento tras excepción. No se limitan a replicar el algoritmo de implementación ni dependen de umbrales de velocidad. Los tests JVM observan hilo distinto, espera FIFO con latches, despacho explícito de respuesta y continuidad tras fallo. La integración MainActivity/Android se revisó estáticamente y compiló según el log; las pruebas JVM no acreditan un Looper Android real.

Logs leídos bajo `docs/evaluation/flutter-port-2026-10-07/`:

- `performance-red.log`: valor idéntico cambió timestamp y agenda nativa recibió una llamada frente a cero esperado.
- `performance-count-red.log`: dos lecturas frente a una esperada.
- `performance-dispose-red.log`: StateError de ref durante desmontaje.
- `performance-native-red.log`: dos fallos de hilo/FIFO con ejecución síncrona.
- `performance-directed-green.log`: siete archivos dirigidos, **20 pruebas pasan**, incluyendo las nuevas regresiones y las suites previas de coordinador/scheduler/Wallet.
- `performance-native-green.log`: **6 tests JVM pasan** y todos los Kotlin de la app compilan offline; no APK.

El reporte final está completo y no afirma haber eliminado el ANR. La suite global y análisis corresponden a integración/root; la expectativa antigua del picker y ajustes de estilo no se atribuyen a Task7. No repetí sus pruebas.

## Límites sin bloqueo

No hay test widget específico que retenga una respuesta de canal mientras emite dos cambios ni uno que dispare lifecycle resumed; su contrato se comprueba por código y por la prueba de force del coordinador. Añadir esos casos sería una ampliación útil de cobertura, no evidencia de defecto actual. El receiver aún puede esperar el monitor de agenda en UI, y Wallet conserva trabajo nativo síncrono ajeno al cambio. N+1, arranque previo a runApp y congelamiento real siguen pendientes según informe. Se requiere validación en el teléfono para cerrar esos puntos.

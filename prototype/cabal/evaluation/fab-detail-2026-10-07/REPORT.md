# FAB compartido y detalle · 2026-10-07

Feedback del usuario: Inicio+ y MovimientosNuevo hacen lo mismo pero se comportan distinto; franja vacía bajo listado; no convence metadata en tabla del detalle. Pregunta adicional sobre recordatorios. Refinamiento sobre identidad y funcionalidades existentes; sinFlutter niAPK.

## Causas y corrección

Reproducción anterior390: history-create tenía altura68px y acción new, abría gasto directamente. Inicio usaba movement-actions. Ambos renderizan ahora el mismo homeActions, con mismo nombre accesible, tamaño y hoja de cuatro opciones. Se elimina contenedor history-create del render. FAB absoluto dentro app sobre contenido; padding final96px permite desplazar última fila por encima. No se reserva una franja fija.

El detalle sustituye filas con bordes por dl de etiquetas/valores en dos columnas; Nota usa todo el ancho. Conserva cuenta/destino/categoría/canal/nota/disponible para devolución, divisiones, cuotas y acciones. Es propuesta visual para juicio del usuario, no aprobación estética del revisor. No se modifican cálculos.

## Navegador comprobado

-390: hojas Inicio/Movimientos contienen exactamente Gasto, Ingreso, Transferir, Compra en cuotas; Ingreso desde historial abre tipo correcto. Capturas antes/después history390 y detail390.
-390: contenedor franja ausente; contentBottom=navTop766; al desplazar al final lastBottom669.5 < fabTop692, última fila visible por encima. history-end390. Durante scroll intermedio FAB puede ocluir temporalmente parte de una fila; se conserva desplazamiento para descubrirla, no se afirma ausencia de toda superposición.
-320: lista con datos y búsqueda vacía; FAB sigue disponible y hoja cierra con Escape, devuelve foco a Nuevo movimiento y0dialogs. Capturas history320/empty320.
-320: edición real del movimiento ficticio con comercio largo y nota larga; detalle ancho documento=scroll320; cada par de metadata ancho=scroll131 y Nota278. No se altera importe45.000.
-1280: listado y detalle largo en marco teléfono. Ancho contenido458=scroll458, documento1280=scroll1280. Capturas history1280/detail-long1280.
-Recarga final recupera escena base, elimina alteraciones de prueba en memoria.

## Pruebas y revisión

Suite modelo final55/55,0fallos. Sintaxis app.js salida0. Evaluación independiente REVIEW.md compara helpers anteriores/actuales sobre25movimientos, fuente, capturas y suite propia; sin navegador independiente disponible. No se confunden VM y recorridos browser. Detector impeccable una vez: avisos heredados Inter/sombra/microtexto; no se cambia identidad por preferencias del detector. JSON íntegro disponible, salida2 por avisos.

## Estado de notificaciones y límites

HTML: configuraciones de recordatorio y aviso de ejemplo. No programa ni emite notificaciones del sistema. Lectura local Flutter y Android: sin rutas de reminder/recordatorio/scheduleNotification/zonedSchedule/AlarmManager/WorkManager para estos pagos; NativeNotificationBridge sirve captura deWallet y pruebas de desarrollo, no un scheduler de cuotas/plantillas. Recordatorios de pago reales siguen pendientes de implementar y probar en Android. Esto es inspección de código, no ejecución en dispositivo.

No se implementan notificaciones como parte de un ajuste visual. No se valida entrega con appcerrada, permisos, reinicio, horario, TalkBack, teclado virtual ni tacto real. No se vuelve a ejecutar todo el ciclo funcional anterior; se corren regresiones de modelo y recorridos afectados. Sin Flutter ni APK.

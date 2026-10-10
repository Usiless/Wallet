# Propuesta: formulario de movimiento

**Estado (2026-10-10): puntos 1–5 aprobados por el usuario («puedes hacerlo directo en el Flutter») e implementados sin prototipo HTML; probados en host, Android pendiente. Selector «Cuándo» aprobado e implementado el mismo día.** Surge de la revisión del usuario sobre la longitud del formulario tras la unificación de pendientes ([UNIFICATION_PROPOSAL](UNIFICATION_PROPOSAL.md)). Cualquier cambio sigue el proceso del [ROADMAP](ROADMAP.md#proceso-para-cualquier-trabajo-posterior).

## Observación
El formulario de gasto (`lib/features/transactions/presentation/transaction_form_screen.dart`) concentra importe, cuenta, comercio, categoría o división, «Pagar después», cuotas, fecha, recordatorios, repetir, canal, nota y plantilla en una sola lista larga. Ingreso y Transferir reutilizan la misma pantalla con campos que aparecen o desaparecen y son cortos; el problema se concentra en Gasto.

## Propuesta
1. **Núcleo siempre visible:** importe, cuenta, comercio y categoría, con guardado claro. El gasto simple y ahora conserva un camino corto.
2. **«Más detalles» único:** fecha, canal, nota y «Pagar después» (con cuotas, fecha de pago, recordatorios y repetir) en un solo bloque plegable, en lugar de varias secciones sueltas.
3. **Plantilla fuera del cuerpo:** «Guardar como plantilla» pasa al selector del botón de plantillas.
4. **Ingreso y Transferir sin cambios** salvo heredar la ubicación de fecha, canal y nota.
5. **No usar pasos ni pestañas:** se pierde el registro rápido.

Sin textos explicativos nuevos, conforme a [AGENTS](../AGENTS.md).

## Decisión: selector «Cuándo» · aprobada 2026-10-10
El usuario aprueba reemplazar los interruptores «Pagar después» y «En cuotas» por un único selector «Cuándo» (Ahora / Pagar después / En cuotas). Con cuenta de tarjeta solo muestra Ahora y En cuotas (deuda inmediata dividida en cuotas). En cuentas sin crédito, «En cuotas» crea pagos pendientes mensuales; «Pagar después» crea un pendiente único con «Repetir». Implementado en `transaction_form_screen.dart`; sin cambios de almacenamiento. 256 pruebas y análisis limpio; Android pendiente.

## Validación propuesta
Prototipo HTML revisado primero si el usuario lo desea; luego Flutter con pruebas de widget (320 px, texto 2x, teclado) y recorrido Android: gasto simple en pocos toques, gasto pendiente con recordatorio, ingreso, transferencia y gasto en tarjeta con cuotas.

## Implementación
El núcleo (importe, tipo, cuentas, comercio, categoría) queda visible. «Más detalles» agrupa Pagar después, cuotas, repetir, fecha de pago, recordatorios, fecha, canal y nota; no se puede ocultar mientras «Pagar después» o «En cuotas» estén activos. «Guardar como plantilla» pasa al selector del botón de plantillas de la barra (el ícono cambia cuando está marcado). Ingreso y Transferir conservan su contenido. `flutter analyze` limpio y 254 pruebas sin fallos.

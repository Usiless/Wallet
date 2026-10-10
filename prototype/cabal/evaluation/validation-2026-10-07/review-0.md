# Revisión independiente · tanda 0 · 2026-10-07

## Dictamen basado en evidencia

Se identifican tres P1 y un P2 reproducibles. No se puede cerrar la validación mientras permanezcan los errores de distribución financiera y duplicación. No se detectó P0 en los casos examinados; esto no acredita ausencia general de corrupción.

Revisión sin modificar producto ni pruebas compartidas. Se leyeron AGENTS.md, PRODUCT_BASELINE, PROTOTYPE_STATUS, README, PLAN y RESULTS de esta tanda. Prima el alcance posterior registrado en PLAN: cuotas fuera de crédito, pendientes, pagos parciales, factura variable y recordatorios simulados están autorizados. No se consideran defectos las integraciones Android excluidas ni se solicitan funciones nuevas.

## Evidencia ejecutada

- `node prototype/cabal/model.test.js`: **48/48**, salida 0. Evidencia propia: `review-0-suite.tap`. Pasar esta suite no demuestra recorridos de interfaz.
- `node prototype/cabal/evaluation/validation-2026-10-07/review-0-probes.cjs`: salida 0; observaciones reproducibles en `review-0-probes.txt`. No son regresiones compartidas ni una suite que deba pasar; imprimen el comportamiento defectuoso.
- R01 usa funciones reales del modelo. R02 ejecuta la función real `rankings` de app.js extraída y evaluada en Node vm con dependencias mínimas; no es ejecución DOM/navegador. R03/R04 reproducen en Node las asignaciones del handler de edición de plantilla y después ejecutan el modelo real; el paso de formulario todavía requiere comprobación en navegador.
- Inspección visual de `round-0-credit.jpg`: cuota 1/3 de 101 muestra 33, Alimentación 16 y Hogar 17; etiqueta Prevista y compra original 101 coherentes. Una captura no prueba acciones, medidas de viewport, contraste ni foco.
- No se controló el navegador para evitar interferencia con el agente coordinador. Los recorridos descritos por RESULTS son evidencia del coordinador, no ejecuciones propias.

## R01 · P1 · La programación pierde divisiones por categoría

**Localización:** model.js:249 (creación del pendiente), model.js:259 (filtro de categoría), model.js:282 (pago). app.js:149 permite divisiones en el formulario de plantilla.

**Reproducción:** plantilla mensual bancaria de 100.000, categoría principal Alimentación, divisiones 40.000 Alimentación y 60.000 Hogar, próxima fecha 2026-10-06. `validateTemplate` la acepta. Ejecutar `processSchedules`; consultar `pendingAmount` por categorías; confirmar pago completo con `payObligation`.

**Observado:** pendiente Alimentación 100.000/Hogar 0; movimiento pagado contiene una sola parte Alimentación 100.000; reportes pagados Alimentación 100.000/Hogar 0.

**Oráculo:** conservar los 40.000/60.000 admitidos y guardados por la plantilla, tanto en previsión como al confirmar el pago completo. El saldo total es correcto, pero presupuestos y reportes por categoría se desvían 60.000. El pendiente no copia `splits` y el pago los fuerza a `[]`.

**Validación:** modelo real. Formulario y cifras de interfaz pendientes de reproducción en navegador. La suite no combina plantilla programada dividida con pendiente, confirmación y presupuesto/reportes categorizados.

## R02 · P1 · Ranking «Sin categoría» infla las cuotas divididas

**Localización:** app.js:110, rama `rankings` de categoría vacía; model.js:105–107 explica el resultado.

**Reproducción:** compra crédito 101 en tres cuotas, dividida 51 Alimentación y 50 sin categoría. Consultar octubre 2026, vista Categorías.

**Observado en función real de presentación:** gasto total del mes 33; Alimentación 16 (48%); Sin categoría 33 (100%). Las filas suman 49 y porcentajes 148%.

**Oráculo:** primera cuota 33 = 16 Alimentación + 17 Sin categoría; por tanto Sin categoría debe mostrar 17, aproximadamente 52%.

**Causa:** la rama construye una compra con `splits` limitados a sin categoría pero conserva `amount:101`. `installmentSchedule` vuelve a distribuir el total de cada cuota entre esa única parte. Alterar los pesos antes de calcular el calendario transforma una selección de categoría en una reasignación del importe total.

**Validación:** modelo y función de render real en vm; no navegador. Las pruebas 101/51/50 solo usan dos categorías identificadas y prueban presupuesto/modelo, no ranking con categoría vacía.

## R03 · P1 · Editar próxima fecha duplica compromisos ya preparados

**Localización:** app.js:301–302; model.js:242–250.

**Reproducción:** crear plantilla de 100.000 mensual con próxima fecha 2026-10-06. Procesar: pendientes 2026-10-06 y 2026-11-06, siguiente fecha de plantilla diciembre. Editar su próxima fecha a 2026-10-07 y guardar.

**Observado al reproducir las mismas asignaciones:** quedan 2026-10-06, 2026-11-06, 2026-10-07 y 2026-11-07. Pendiente octubre pasa de 100.000 a 200.000.

**Oráculo:** una edición de la fecha de programación no debe multiplicar el mismo compromiso mensual pendiente. Si los vencimientos ya preparados deben conservar sus fechas, como mínimo no se puede preparar otro compromiso para esos meses al editar la misma plantilla; si se aplica a este mes y siguientes, deben actualizarse sus fechas preservando pagos/historial. El formulario promete aplicar las ediciones a este mes y siguientes.

**Causa:** el handler actualiza importe/cuenta/categoría/nombre/recordatorio de los pendientes pero no reconcilia sus fechas ni identidad. El procesador deduplica exclusivamente `templateId@fecha`, así que las nuevas fechas tienen claves diferentes y se insertan además de las originales.

**Validación:** fuente y reproducción de handler+modelo. Requiere recorrido de formulario real para cerrar evidencia navegador. La suite prueba repetir procesamiento de la misma clave, no editar la fecha tras proyectar obligaciones.

## R04 · P2 · Comercio editado no llega a pendientes futuros ni a sus pagos

**Localización:** app.js:301; model.js:282.

**Reproducción:** preparar pendientes de plantilla cuyo comercio es «Factura demo». Editar plantilla: comercio «Proveedor nuevo», nombre «Factura nueva». Confirmar un pendiente futuro existente.

**Observado:** plantilla guarda «Proveedor nuevo»; pendiente presenta «Factura nueva»; movimiento pagado queda con comercio «Factura demo».

**Oráculo:** vencimientos futuros todavía sin pagos deben usar el comercio editado, conservando únicamente pagos históricos. La edición propaga `name` y omite `merchant`; la confirmación toma este último. Esto afecta búsqueda, desglose por comercio y aprendizaje de preferencias.

**Validación:** fuente y handler+modelo; formulario real pendiente. No hay prueba de edición de comercio en plantilla con obligaciones existentes.

## Usabilidad y móvil

La captura revisada permite leer importe, categoría y relación con compra original. No presenta un defecto visual confirmable en esa escena. No se atribuye a la captura un ancho 320/390 porque el archivo no acredita viewport CSS ni escala. Faltan capturas/medidas actuales 320/390 y escritorio de pagos pendientes, edición de factura, plantillas, reportes y diálogos; también foco inicial, Tab, Escape, inert y retorno de navegación. La ausencia de evidencia es una brecha, no un defecto móvil confirmado.

Por fuente, los pagos confirmados abren el detalle del pendiente (`app.js:185`) y no el detalle normal de movimiento. No se califica como fallo sin confirmar qué acciones de edición/devolución deben admitir estos pagos en el alcance autorizado.

## Cobertura y límites restantes

Las 48 pruebas cubren conservación entera de cuotas, saldos, parciales/arrastre, total variable, programación idempotente, Wallet y restauración de libro simulado. Faltan cruces entre esas capacidades: divisiones+programación+pago, cuota+sin categoría+ranking, edición de calendario/comercio tras preparar vencimientos, y formulario real con estado ya pagado o arrastrado.

A01/A02 están descritos por el coordinador y A04 tiene captura. No hay evidencia propia suficiente para declarar completados A03/A05–A13, pruebas móviles, recordatorios o backup UI. La sintaxis base está registrada por el coordinador; esta revisión no la volvió a ejecutar porque no editó producto. No se verificó Flutter, APK, Android, Wallet/SMS reales, SAF, cifrado, biometría, entrega real de recordatorios, proceso cerrado, teclado virtual ni TalkBack. Los backups de memoria no demuestran integridad del almacenamiento de producción.

# Revisión independiente · tanda 2 · 2026-10-07

## Dictamen y alcance temporal

R05/R06 quedan resueltos en los casos originales y en probes independientes de aumento, reducción, pago completo, arrastre y rechazo transaccional de fecha duplicada. Se confirma **un P2 nuevo: R07**, deriva del calendario al editar únicamente el importe de una ocurrencia ajustada a fin de mes. Fue comunicado inmediatamente al coordinador y reparado mientras esta revisión terminaba. Por ello el dictamen sobre la tanda 2 de **54 pruebas** es «requiere corrección R07»; los archivos propios ejecutados al final ya corresponden al código posterior de tanda 3 (**55/55**), distinción necesaria para no atribuir resultados a una versión diferente.

Solo se escribieron este informe y probes/evidencias de revisión. No se modificaron producto, Flutter, APK ni pruebas compartidas. Se leyeron AGENTS, PRODUCT_BASELINE, README, PLAN, RESULTS y revisiones 0/1. Se aplicó investigación de causa de systematic-debugging.

## R07 · P2 · Editar solo importe hace derivar fechas de fin de mes

**Localización inicial:** `model.js`, `editObligation`: asignación incondicional `n.due=addMonths(due,offset)` y sustitución incondicional de `t.anchor` al aplicar a siguientes.

**Reproducción propia inicial, modelo real:** crear un plan de débito de 300.000 en tres cuotas desde 2027-01-31. Calendario inicial enero31/febrero28/marzo31. Editar la cuota de febrero a 120.000, conservar su fecha febrero28 y aplicar a siguientes. Resultado observado: enero31/febrero28/**marzo28**. No se cambió el vencimiento solicitado.

**Segunda reproducción propia:** plantilla mensual desde 2026-10-31, obligaciones octubre31/noviembre30, cursor diciembre31 y ancla octubre31. Editar únicamente importe de noviembre30 con aplicación a siguientes. Resultado: cursor **diciembre30**, ancla **noviembre30**.

**Oráculo:** una edición de importe que conserva el campo fecha debe conservar las fechas y el día original del calendario. El ajuste al último día de un mes corto no debe convertirse en un cambio permanente del día previsto ni anticipar recordatorios/pagos posteriores.

**Causa:** el handler centralizado interpretaba cualquier edición como una reprogramación a partir del día ajustado de la ocurrencia seleccionada. Las pruebas nuevas R06 empezaban en un día existente en todos los meses y no distinguían modificar importe frente a modificar fecha en un mes corto.

**Estado al terminar:** el coordinador confirmó el caso, añadió regresión RED y corrigió condicionando la reprogramación al cambio real de fecha. Evidencia suya: `round-3-red.tap` / `round-3-tests.tap`. Los probes propios ejecutados posteriormente confirman marzo31 y diciembre31 conservados; esto es un recheck del modelo, no recorrido de formulario ni evaluación completa de tanda 3.

## Evidencia propia y R01–R06

- `review-2-probes.cjs` / `.txt`: funciones reales del modelo, ejecución Node, salida 0 después de la corrección R07. No ejecutan DOM ni handlers simulados. Las aserciones R07 verifican el comportamiento final corregido; las observaciones iniciales defectuosas están transcritas arriba y fueron comunicadas antes de su reparación.
- `review-2-suite.tap`: **55/55**, cero fallos; se ejecutó después de que el coordinador incorporara R07. Las **54/54** de tanda 2 constan en `round-2-tests.tap`, evidencia del coordinador.
- Sintaxis `model.js` / `app.js`: ambas salida 0.
- Hash del código final examinado: modelo `05859fb4358e614ab1d7e1bb4c21c93f242f822900db6545c7c2c45d9a0e117d`; app `67c1b9e341f961d7196c47ff31ce47bbab081c5a0b418959197e5e8d88722ae2`.
- **R01/R06:** aumentar factura dividida 100.000→200.000 conserva pesos 80.000/120.000 y plantilla válida; reducir a 50.000 y pagar por completo deja previsión cero. La suite conserva el arrastre categorizado 4.000/6.000. Sin pendiente fantasma en los casos repetidos.
- **R02:** cuota de compra 101/3 con parte sin categoría devuelve 17 de total33. Se verifica el modelo; no se repite ranking DOM propio.
- **R03/R04:** mover plantilla a octubre31 produce octubre31/noviembre30 sin duplicación al reprocesar; pago usa comercio corregido.
- **R05:** vencimiento resuelto por pago90.000+arrastre10.000 conserva saldo cero, cambia recordatorio seleccionado y siguiente a5d/10:30, sin modificar movimientos históricos.
- **Protecciones:** editar vencimiento con pagos/arrastre se rechaza sin cambios; mover un pendiente sobre otra fecha del mismo grupo se rechaza sin cambios. No se declara exploración exhaustiva de frecuencias o todas las permutaciones de cancelación/edición.

## Captura, navegador y móvil

Inspección propia de `round-2-reminder-paid.jpg`: Electricidad vencimiento10oct, previsto50.000, pagado50.000, porpagar0 y recordatorio5d/10:30 son coherentes; navegación inferior visible, texto legible y contenido desplazable en esa imagen. No se confirma un defecto móvil relevante en esta escena.

El coordinador informó reproducción real de formulario R05/R06 y su resultado correcto. Se distingue esa evidencia de la inspección estática propia: no se controló el navegador compartido, ni se midieron viewport CSS, foco, Tab, Escape, inert, blancos táctiles o reflujo personalmente. Los recorridos A01–A13 y las medidas documentadas en RESULTS siguen siendo evidencia del coordinador, no ejecución propia. No se verificó Android, APK, entrega real de notificaciones, proceso cerrado, Wallet/SMS reales, teclado virtual, TalkBack, cifrado ni archivos reales.

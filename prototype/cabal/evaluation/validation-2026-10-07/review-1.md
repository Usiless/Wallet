# Revisión independiente · tanda 1 · 2026-10-07

## Dictamen

Las correcciones de tanda 1 resuelven los casos originales cubiertos por las nuevas regresiones; la suite propia pasa **52/52**. Persisten **un P1 nuevo (R06)** y **un P2 nuevo (R05)** confirmados. No corresponde cerrar la evaluación financiera mientras R06 permanezca.

Revisión sin modificar producto, Flutter, APK ni pruebas compartidas. Se leyeron AGENTS.md, PRODUCT_BASELINE, PROTOTYPE_STATUS, README, PLAN, RESULTS y review-0; el alcance posterior de PLAN prevalece sobre las exclusiones históricas de recordatorios y compras pendientes. Se aplicó investigación de causa de systematic-debugging; no se implementaron correcciones.

## Evidencia propia

- `node prototype/cabal/model.test.js`: **52/52**, salida 0, guardado en `review-1-suite.tap`.
- `node --check prototype/cabal/model.js` y `node --check prototype/cabal/app.js`: salida 0.
- `node prototype/cabal/evaluation/validation-2026-10-07/review-1-probes.cjs`: salida 0, observaciones en `review-1-probes.txt`.
- Los probes extraen del archivo actual el cuerpo real de los handlers `obligation-edit` y `reminder` y lo ejecutan en Node vm con los valores del formulario y efectos de render sustituidos. Después usan el modelo real. Esto confirma código y estado de datos; **no es ejecución DOM ni navegador**.
- Hash revisado de model.js: `a86d32c1730736e27adf364328b97077f34fb14e51cb7b139e72a0c7110dcfee`; app.js: `a9d3322bdcc4186f66189da3c4d127a2310445aa9ac96cb5cc2c5f4aedbaac40`.

## R06 · P1 · Editar el importe del pendiente conserva divisiones del total anterior

**Localización:** app.js:290–291; model.js:259–269 y 314–315. Ruta: detalle del pendiente → Editar pendiente.

**Reproducción A:** plantilla programada de 100.000, dividida 40.000 Alimentación y 60.000 Hogar; preparar pendientes octubre/noviembre. Editar pendiente de octubre a 200.000 y activar «Aplicar también a los siguientes pendientes».

**Observado:** `obligationRemaining` muestra 200.000, pero `pendingAmount` y las partidas del presupuesto siguen sumando 100.000. El handler cambia `amount` y omite `splits`. También actualiza `template.amount` a 200.000 manteniendo divisiones 40.000/60.000: `validateTemplate` falla con «Las divisiones deben ser positivas y sumar el importe total». La plantilla ya no puede preparar correctamente vencimientos posteriores cuando se alcance la próxima fecha.

**Reproducción B:** misma factura 100.000 dividida; editar solo este pendiente a 50.000 y confirmar el pago de 50.000.

**Observado:** pendiente saldado (`obligationRemaining=0`) y un pago correcto de 50.000, pero `pendingAmount` conserva **50.000 ficticios**: Alimentación 20.000 y Hogar 30.000. El presupuesto contabiliza pago + pendiente fantasma, manteniendo el total anterior 100.000.

**Oráculo:** después de editar total, las divisiones deben sumar exactamente el nuevo importe; un pendiente pagado no puede aportar previsión restante. Si se aplica a futuros vencimientos, la plantilla también debe seguir siendo válida. El modelo ya escala divisiones al corregir importe final en `payObligation`; el handler de edición no mantiene ese invariante.

**Evidencia:** reproducción independiente con handler real + modelo. Falta reproducción en navegador de este recorrido; no se atribuye a la captura revisada. El pago completo aumentado funciona, pero no elimina la incoherencia durante la previsión ni el bloqueo de programación futura.

## R05 · P2 · Recordatorio editable de un vencimiento resuelto ignora el cambio seleccionado

**Localización:** app.js:52 ofrece Editar sin condición; app.js:281 exige `remaining(n)>0` incluso para el vencimiento abierto.

**Reproducción:** factura 100.000, pagar 90.000 y trasladar 10.000. En el vencimiento de saldo cero, editar recordatorio de 3 días/09:00 a 5 días/10:30 y guardar.

**Observado:** se informa «Recordatorios actualizados», pero el vencimiento seleccionado continúa con 3 días/09:00. El siguiente y la plantilla sí muestran 5 días/10:30. Reproducido por handler real en probe; el coordinador comunicó la misma reproducción de navegador en esta tanda. No se presenta esa ejecución como propia.

**Oráculo:** el diálogo promete «Se aplica a este vencimiento y los siguientes». El cambio del vencimiento seleccionado debe reflejar lo guardado si el control permite editarlo. Un recordatorio resuelto no vuelve a producir avisos por cambiar su configuración: la vista de aviso ya exige saldo pendiente. Severidad P2 por acción engañosa y configuración incoherente; no altera saldos y no es P1.

## Reevaluación de tanda 0

- **R01:** la regresión pasa con previsión 40.000/60.000, pago 90.000 repartido 36.000/54.000 y arrastre 4.000/6.000. El modelo conserva ahora las partidas. R06 muestra una combinación posterior no cubierta, no invalida el caso original reparado.
- **R02:** prueba independiente adicional devuelve Sin categoría **17 de 33** para cuota de compra 101 dividida 51/50. La regresión de selección estricta pasa. No se recorrió nuevamente el ranking real DOM.
- **R03/R04:** regresiones pasan; probe adicional edita octubre 6 a octubre 31 y conserva dos vencimientos octubre 31/noviembre 30; un reprocesamiento agrega cero. Conservación de pago previo y cambio de comercio están cubiertos por las nuevas pruebas. No se afirma exploración exhaustiva de todos los cambios de frecuencia/fechas.

## Captura, móvil y límites

Se inspeccionó `round-1-payment-320.jpg`: importe cero, 10.000 trasladados y etiqueta «Saldo trasladado» coherentes; texto legible en esa captura, navegación inferior visible. El selector del escenario trunca su etiqueta, sin impedir identificar/abrir el control en la imagen. No se confirma un defecto de usabilidad relevante solo por ese truncamiento.

La captura no prueba foco, Tab, Escape, inert, tamaño táctil ni ausencia global de desborde; no se controló navegador compartido. Su nombre no sustituye medición CSS propia. Quedan a cargo del coordinador recorridos reales 320/390/1280 y demás criterios A01–A13 no ejecutados aquí. No se verificó Android, notificaciones reales, tareas con app cerrada, teclado virtual, TalkBack, cifrado ni almacenamiento de producción.

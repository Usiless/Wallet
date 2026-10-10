# Cabal · mejora de interfaz · 2026-10-07

Informe separado del testing funcional de `validation-2026-10-07/`. Base:55/55 pruebas, siete fallos funcionales corregidos. Solo HTML/CSS/JS del prototipo; sin Flutter ni APK.

## Alcance y método

Refinamiento acotado con Superpowers e impeccable, modo Operate. Conservar verde profundo, jade, menta, ícono, banner, anillos, cinco pestañas y cálculos. AGENTS y PRODUCT_BASELINE actuales exigen quitar subtítulos, bajadas y explicaciones, sin sustituirlos por ayudas desplegables. Se conservan etiquetas, valores, estados, errores y confirmaciones necesarias para ejecutar una acción. El marcador global Datos ficticios y los nombres de acciones simuladas siguen identificando el entorno.

El usuario ya define ejecución autónoma por tandas; esa instrucción sustituye puertas genéricas de confirmación de diseño. No hay Git accesible; copias de base en `before/`. Context de impeccable ejecutado una vez: noPRODUCT/DISEÑO, refinamiento permitido sobre identidad existente; detector manual al terminar.

Máximo cinco tandas. En cada una: elegir hasta tres problemas relevantes comprobados, corregirlos conjuntamente, comprobar móvil/escritorio/estados, evaluación independiente y regresiones funcionales. Detener si no aparecen problemas relevantes nuevos confirmados. No usar notas estéticas.

## Evaluación inicial en navegador

| ID | Impacto y evidencia | Diseño de mejora | Aceptación |
|---|---|---|---|
| UI01 | P2: explicaciones repetidas en Inicio, pendientes, formulario, Más, cuentas, reportes y ajustes contradicen la preferencia aprobada. En formulario de pago, párrafo de ayuda sobre factura variable incluso para una cuota deTele. `before/home-320`, `payment-form-390`, `error-390` | Quitar explicaciones y subtítulos; preservar metadatos y estados. Sin nuevas ayudas | Recorridos identificables por títulos/etiquetas/valores; acciones y cálculos iguales |
| UI02 | P2: FAB superpuesto al importe deBicicleta320px, documentado en testing y reproducido `before/home-320.jpg` | Zona reservada para FAB encima de navegación; menú conserva opciones. Renglones con nombres/importes largos adaptables | Botón cerrado no intersecta filas; opciones abiertas utilizables; nav visible; sin overflow320/390/1280 |
| UI03 | P2: valores iniciales500000 sin separadores, etiquetas/datos12–13px; error al final del formulario no recibe foco. `before/error-390.jpg` | Lectura consistente14px en datos/controles, cantidades tabulares y preformateadas; error enfocable/anunciado; valores largos ajustan sin romper página | Error positivo/recuperable con foco; guardar válido funciona; nombres/importes largos legibles y acciones accesibles |

Es evidencia de viewport de navegador, no prueba táctil física. El primer intento de captura1280 dentro de la misma llamada de cambio de viewport produjo389×900: se descarta como evidencia de escritorio y se reemplaza con captura asentada. Similar captura larga320 tenía alto693; se recapturó para comparación exacta (320×740).

## Recorridos de regresión de interfaz

- Inicio→FAB→Gasto/Ingreso/Transferir; Escape; registrar/cancelar.
- Pendiente→Confirmar pago→importe0/error→corregir90k/otra cuenta→pago parcial/traslado; editar recordatorio.
- Reportes→cinco vistas→filtros→historial→detalle→volver.
- Plantillas→editar fecha/importe dividido; conservar pendientes y comercio.
- Vacío por búsqueda; sin cuentas; nombres largos y cantidades de ocho/nueve cifras.
- Wallet y backup: controles/estados identificables sin agregar explicaciones; acciones ficticias y errores intactos.
- Móvil320×740/390×844, escritorio1280×900; foco/inert/Tab/Escape; ancho y áreas táctiles. Cualquier recorrido no ejecutado se declara al cierre.

## Tanda 1

Finalizada una tanda: UI01–UI03. Antes:55/55, `baseline-tests.tap`. Capturas comparables en `before/` y `after/`.

### Cambios y primeras comprobaciones

- UI01: retiradas explicaciones de pantallas/formularios, subtítulos de encabezados/menús y ayudas vacías de reportes. Se conserva información real (cuenta, tipo, fecha, cuotas, origen, resto, próxima fecha, motivos de revisión, importes), errores y confirmaciones. MarcadorDatosficticios y botones de simulación permanecen. Cifrado se presenta comoSimulado, no como mecanismo implementado.
- UI02: FAB en zona propia sobre navegación, menú conserva cuatro opciones yEscape. A320, área de contenido termina587px y FAB empieza595px: separación8px, no oclusión. El primer probe usó rectángulos sin recortar por overflow del contenedor y dio falso negativo; se corrigió el oráculo usando el límite real del área desplazable. En lista estrecha, importe y nombre en primera línea; metadatos y estado debajo. Navegación conserva pestaña de origen en detalles, en vez de seleccionarMás automáticamente.
- UI03: datos/acciones14px, metadatos13px, cantidades tabulares; camposmonetarios muestran500.000 al abrir. Error rolealert/tabindex−1 recibe foco y permanece visible. Tras importe0, navegador confirma activeElement=form-error, ancho390 sin overflow. Corregir a90k y elegirEfectivo registra parcial deTele500k con410k trasladados; recordatorio de saldada5d10:30 se guarda.
- Capturas antes/después deInicio320/1280, detalle/formulario/error390. La captura escritorio se repitió después de asentar viewport; ambos archivos1280×900. Comparación de cifras base:727k disponible/790k pendiente/−838k patrimonio, sin cambio de cálculo.

### Verificación final y revisión independiente

- Reportes en navegador320: Resumen, Evolución, Categorías, Comercios y Cuentas, sin overflow horizontal. Filtro Efectivo→movimientos→Viaje demo→volver dos veces conserva vista Cuentas, cuenta y período. Capturas de las cinco vistas y report-checks.json.
- Contenido largo320: nombre de compra de más de100 caracteres, total123.456.789, cuota41.152.263, lista/detalle/formulario/error. Nombre e importe legibles, sin overflow. Error visible, acciones dentro del alto740; también captura de error1280. Listado recapturado sin toast para comparar.
- Vacío de búsqueda390 y primera vez320: CTA de agregar cuenta abre formulario. Modal Nueva cuenta: Tab desde Guardar vuelve a Cerrar; Shift+Tab desde Cerrar vuelve a Guardar. No se prueba teclado virtual físico.
- Backup320: etiqueta indica mínimo8; abc produce error y foco en form-error; cabal-demo permite avanzar a Elegir destino. Se cancela allí: no se vuelve a ejecutar restauración completa en este ciclo. Wallet320: estados y controles visibles, sin permiso; no se repiten capturas reales ni permisos Android.
- Evaluación independiente en REVIEW-1.md y adendas: inspección de capturas, diff,28 probes de helpers mediante VM y55 pruebas modelo. No pudo acceder a pestañas desde su sesión; no ejecutó recorridos propios en navegador. Los recorridos interactivos descritos arriba pertenecen al agente principal.
- Observación menor del revisor: toast de plan conservaba una explicación. Confirmado contra AGENTS y reducido a «Plan registrado.» dentro de esta tanda.
- Detector impeccable ejecutado una vez: salida2 con avisos, JSON íntegro guardado. Confirmado marcador de entorno10px: se subió a11px con espaciado.6px; navegador confirma computed11px, ancho=scroll320. Avisos Inter y sombra son preferencias sobre identidad existente, no defectos de tarea. Avisos7px/10px de estilos heredados y tracking se contrastan con CSS efectivo: controles principales14, metadatos13, marcador11; no se cambia marca por un detector. No se afirma certificación WCAG.
- Regresión final fresca: final-tests.tap55/55, final-render-probes.txt28/28. node --check app.js y model.js salida0. Modelo/model.test sin cambios en esta tanda. Diff de producto completo en changes.diff.

## Cierre y límites

Se detiene después de una tanda: no quedan fallos relevantes confirmados en las pantallas y recorridos probados. Se conservan identidad y funciones de la base; no se agregan propuestas pendientes. Capturas equivalentes home320×740, home1280×900, long320×740 y formularios390 en before/after. Algunas capturas complementarias muestran estados distintos y no son comparaciones equivalentes.

No se repitieron todos los recorridos del ciclo funcional anterior: edición de plantillas con divisiones, restauración completa, creación de gasto/ingreso/transferencia y simulaciones Wallet quedan cubiertas por su evidencia anterior y regresión del modelo, no por un nuevo recorrido completo en navegador en esta tanda. Los helpers VM no prueban layout ni interacción. No se ejecutó una revisión interactiva independiente por falta de pestañas accesibles al revisor. Android real, TalkBack, teclado virtual, notificaciones del sistema, SMS, cifrado y backups reales no están validados. Sin Flutter ni APK.

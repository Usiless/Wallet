# Revisión independiente · feedback Android

2026-10-07. Revisión acotada al menú +, compositor de movimientos y encabezado Más. Fuentes: diff de app/styles/index frente a `before/`, capturas before/after, AGENTS vigente y PRODUCT_BASELINE. Sin modificar producto, Flutter ni APK. Impeccable se aplica a comprobar los objetivos del feedback y regresiones concretas, sin sustituir la identidad por preferencias arbitrarias.

## Resultado

Los tres objetivos están reflejados en fuente/capturas: el + abre una hoja inferior dentro del área de la aplicación con cuatro acciones; el compositor ocupa el área de la aplicación y usa barra Volver/Guardar, tipo segmentado y filas; Más conserva el contenido y navegación sin encabezado redundante.

No hay defecto funcional relevante confirmado pendiente en el código actual dentro del alcance examinado. Se comunicó inicialmente el riesgo de tocar un tipo ya seleccionado: la primera versión limpiaba cuenta/categoría/divisiones/cuotas. La fuente actual incluye `if(draft.type===id)break` y la simulación del handler confirma que ese toque no regenera ni limpia el borrador. Queda cerrado.

## Evidencia propia

- Browser: `cua.getState()` devuelve `apps:[]`, `browsers:[]`; sin recorridos propios de navegador ni capturas propias. No se declara validación nativa Android.
- Inspección visual de before/actions390, before/composer390; after/actions390, composer390, income320, more390, composer1280 y more1280. Hoja inferior conserva cuatro acciones legibles; barra Guardar visible; editor se limita al dispositivo del prototipo en escritorio; Más conserva acciones y cinco pestañas.
- Suite fresca propia `node prototype/cabal/model.test.js`: 55/55, cero fallos; `review-model-tests.tap`. Sintaxis app.js: salida 0.
- `review-probes.cjs` / `review-probes.json`: ejecución del handler real composer-type en VM con seams inyectados para lectura de borrador y compositor. Tipo activo devuelve sin invocar compositor, conservando el fixture. Simulación lógica; no prueba foco/layout/submit del navegador.

## Riesgos revisados en fuente

- El submit de barra usa `type=submit form=modal-form`; eliminar las acciones inferiores del compositor no elimina el formulario ni el manejo delegado de submit.
- Tipo oculto conserva `f.elements.type.value`, usado en readDraft/updateComposer/template-picker/transferencias. Los botones segmentados son type=button y tienen aria-pressed.
- `formSnapshot` copia inputs/selects/textarea y el formulario completo. Dirty keep conserva presentation/submitLabel, payload y baseline; renderModal evita volver a envolver campos ya envueltos. El guardado y conservación efectiva tras errores/descartar requieren los recorridos del principal.
- `overlayBounds` se calcula al renderizar y al resize; screen/sheet reciben left/top/width/height del área #app. El fondo de la app queda inert y los controles continúan dentro de role=dialog. No se comprobó teclado virtual Android ni gesto Atrás del sistema.
- Más tiene aria-label y tabindex, y focusHeading utiliza `.more-content` como fallback después de retirar h2. No se pierde el destino programático de foco por esa eliminación.
- No se alteran model.js, reglas financieras, cuotas ni banderas de desarrollo en este ajuste visual.

## Límite concreto

La captura income320 muestra el segmento Transferencia muy ajustado al borde. Se pidió al principal medir el texto frente al ancho útil del botón antes de clasificarlo; una captura por sí sola no acredita recorte funcional. No se solicita cambio estético ni nueva tanda por densidad. No hay evidencia propia en 692px; el código se revisó, pero no se inventa una prueba de ese viewport.

El principal comunica gasto12k con error vacío/foco y borrador conservado, transferencia5k y geometría editor1280 coincidente con #app. Es cobertura del principal, no recorridos propios de esta revisión.

## Adenda · segmento a 320px

El principal confirma por DOM el recorte menor: Transferencia tenía clientWidth91/scrollWidth93; Gasto/Ingreso91/91. Se clasifica P2 de adaptación, no preferencia visual: el texto de una acción excedía su botón. Corrección acotada aplicada por el principal: a ≤360px, Transferencia usa flex1.4 para reservar ancho sin reducir la fuente. Se revisó la regla; la aceptación final de ausencia de recorte queda sujeta a su nueva medición y captura. No se requiere otra tanda por motivos estéticos.

### Cierre del recorte

Medición final del principal a320: Gasto82/82, Ingreso82/82, Transferencia109/109 (clientWidth/scrollWidth); `after/income-320.jpg` recapturado. Queda resuelto el P2 sin otro defecto relevante confirmado. Continúan los límites de navegador independiente y Android real; no es certificación nativa.

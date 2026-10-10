# Revisión independiente · tanda UI 1

2026-10-07. Alcance: `app.js`, `styles.css`, `index.html` frente a las copias de `before/`; AGENTS actual, PRODUCT_BASELINE, RESULTS del testing funcional y REPORT de esta mejora. Impeccable aplicado como revisión técnica acotada, modo Operate. No se modificó producto, Flutter ni APK.

## Dictamen

No confirmé regresiones funcionales relevantes nuevas en los cambios UI01–UI03 examinados. Esta revisión no justifica una segunda tanda por preferencias de color, densidad o estilo. La aceptación de los recorridos interactivos depende de la evidencia del agente principal: no pude ejecutar recorridos propios en navegador.

## Evidencia propia

- `cua.getState()` devolvió navegador IAB sin pestañas (MCP Apps también vacío); `cua.getTab('1', {browser:'iab'})` devolvió `Tab not found in browser 2`. No se tomó control ni se generaron capturas propias.
- Inspección visual de `before/home-320.jpg`, `after/home-320.jpg`, ambos `home-1280.jpg`, ambos `payment-form-390.jpg`, `after/error-390.jpg`, `after/fab-open-320.jpg`, `after/long-320.jpg` y `after/empty-390.jpg`.
- `review-1-probes.cjs`: 28 comprobaciones de helpers reales ejecutados mediante VM y documento simulado; todas pasan. Ver `review-1-probes.txt`. Comprueba formatos iniciales 0/500.000/999.999.999/vacío; alert/tabindex; cifras Inicio; selección de navegación de origen desde cinco pestañas; render de ocho pantallas y cinco vistas de reporte; CTA sin cuentas; búsqueda vacía; escape de nombres largos e importe intacto.
- Suite fresca `node prototype/cabal/model.test.js`: 55/55, cero fallos, `review-1-suite.tap`. `node --check` para app/model: salida 0.
- La primera ejecución del harness VM falló por faltar el stub `window.addEventListener`; se corrigió el harness. No fue un fallo del producto.

## Evaluación de los tres cambios

| Cambio | Evidencia y conclusión |
|---|---|
| UI01 | El diff elimina ayudas/subtítulos y conserva tipo, fecha, cuenta, categoría, importe, programación, estado, errores y confirmaciones destructivas. Las etiquetas de campos permiten ejecutar pago; la captura posterior conserva el saldo, importe, fecha, cuenta y elección de traslado. No se agregan ayudas desplegables de reemplazo. Quitar las explicaciones sigue una decisión explícita de producto; no se penaliza como falta de onboarding. |
| UI02 | CSS coloca el FAB relativo como hermano del contenido desplazable con altura y márgenes reservados. Las capturas cerradas 320/1280 corroboran separación de la zona de filas; el menú abierto presenta cuatro acciones y cerrar. La fila parcialmente recortada en el borde inferior del scroll no prueba pérdida de acceso. Los probes de navegación preservan la pestaña de origen en detalles de pago. |
| UI03 | Campo inicial de pago pasa de 500000 a 500.000; formato helper conserva los casos válidos, cero y vacío. `form-error` tiene `role=alert`, `tabindex=-1`, y la función usa focus/scrollIntoView. La captura confirma mensaje y acciones legibles. Datos principales pasan a 14px, secundarios 13px. No se afirma validación TalkBack ni teclado virtual. |

## Observaciones y límites

- La captura `after/long-320.jpg` contiene un toast superpuesto a parte de una fila larga. Es un estado temporal, también existente antes de esta tanda; sin prueba de bloqueo persistente no lo clasifico como defecto relevante nuevo. Conviene usar la recaptura sin toast del principal para evaluar el nombre/importe completos.
- El toast «Plan registrado. El dinero sigue en tu cuenta.» conserva una frase explicativa. Es una omisión menor de la limpieza de copy aprobada, no un fallo de tarea ni razón suficiente para otra tanda. Puede quedar «Plan registrado.» dentro de la tanda actual si el principal considera exhaustiva UI01.
- La VM prueba generación de HTML y lógica de helpers; no prueba layout, hit targets, foco efectivo, Tab/Escape, guardado, restauración ni navegación completa. Los stubs no simulan un navegador.
- Sin medición propia de contraste ni gestos táctiles; no se asigna puntaje global WCAG ni certificación de accesibilidad con esta evidencia parcial. Sin inferencias sobre Android real.
- No se encontraron motivos para introducir funciones, subtítulos, explicaciones o ayudas. Las funciones pendientes de PRODUCT_BASELINE no se tratan como aprobaciones nuevas.

## Adenda · cierre de tanda 1

Inspección de las recapturas finales `after/home-320.jpg`, `after/long-320.jpg`, las cinco `after/report-*.jpg` a 320px y `after/long-error-1280.jpg`. En Inicio se ve el importe 110.000 ₲ junto a Bicicleta; el FAB permanece separado. La fila larga limpia conserva nombre completo, importe 41.152.263 ₲, fecha, cuota y estado. No muestra oclusión por toast. En las cinco vistas de reportes se conservan selector, período, filtros y navegación, con cifras/nombres dentro del ancho visible; parte del contenido queda bajo el borde del scroll, como corresponde al contenedor desplazable. El error de pago con nombre largo en escritorio mantiene mensaje y botones visibles.

Comprobación de fuente: el toast de crear plan es ahora únicamente «Plan registrado.» (`app.js:275`), por lo que queda cerrada la observación menor de copy anterior. No se confirmó defecto relevante residual en estas capturas ni motivo para una tanda adicional.

El principal comunica recorridos completos de las cinco vistas de reporte, filtro Efectivo → historial → detalle → volver con filtro conservado, estados Wallet y backup con contraseña inválida/ válida. Son evidencia del principal; esta revisión solo corrobora sus capturas y fuente. Se mantiene el límite de navegador independiente sin pestañas y la ausencia de validación táctil física/TalkBack.

## Adenda · marcador final

Revisada la regla final `.demo-strip{font-size:11px;letter-spacing:.6px}` y las recapturas finales Inicio 320/1280. El marcador «DATOS FICTICIOS» y la fecha permanecen completos y separados; las cifras, FAB y navegación no presentan regresión visual en las capturas. La medición de computed font 11px y scrollWidth 320 pertenece al principal; mi evidencia sigue siendo fuente/capturas, sin navegador propio. Ajuste mínimo aceptado, sin defecto relevante nuevo ni necesidad de otra tanda. Las preferencias del detector sobre tipografía/sombras existentes no acreditan un defecto de tarea y no justifican sustituir la identidad conservada.

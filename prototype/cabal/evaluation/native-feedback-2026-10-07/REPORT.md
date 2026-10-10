# Corrección de interfaz tras feedback · 2026-10-07

El usuario rechaza tres tratamientos por parecer web: desplegable del FAB, compositor modal con campos de formulario y encabezado Más redundante. La revisión anterior comprobó layout y funcionalidad pero no detectó esta distancia respecto de la app Android objetivo. Se corrige la presentación manteniendo identidad y datos. AGENTS/PRODUCT_BASELINE y autorización previa permiten ajustes dentro del alcance sin confirmación entre tandas.

## Cambios

1. FAB: botón abre una hoja de acciones inferior dentro del marco de la app, con Gasto, Ingreso, Transferir y Compra en cuotas. Fondo inerte, cerrar/Escape y selección mantienen recorridos. Sin desplegable anclado encima de filas.
2. Nuevo movimiento, edición, revisión y plantillas que usan compositor: pantalla dentro de la app, barra con Volver y Guardar/Registrar, contenido desplazable. Tipo segmentado, importe prominente, campos en filas, sin botones Cancelar/Guardar movimiento al pie ni caja modal flotante. Formularios secundarios conservan diálogo. Se mantienen selectores HTML como simulación; no se afirma que estos sean componentes Android reales.
3. Más: se elimina encabezado visible repetido. Conserva región etiquetada Más, grupos, navegación y accesos.

## Comprobado en navegador

- Hoja abre y Gasto lleva al compositor390×844. Capturas actions-390 y composer-390; antes equivalentes en before/.
- Guardar vacío: error «Ingresá un importe entero mayor que cero.» recibe foco form-error.
- Gasto12.000 desde Efectivo con comercio Prueba interfaz nativa: Volver abre confirmación; Seguir editando conserva importe/cuenta/comercio; Guardar registra movimiento. Disponible727.000→715.000, Efectivo307.000→295.000.
- Ingreso abre tipo correcto320; cambio a Transferencia muestra origen/destino y oculta comercio/categoría. Transferencia5.000 de Efectivo a Cuenta diaria se registra.
- 320×740: ancho del documento320=scroll320; editor ancho310=scroll310. Sin desbordamiento horizontal. Se conserva desplazamiento vertical.
- 1280×900: rectángulos de editor y app coinciden exactamente: x571 y85 ancho458 alto769. No ocupa todo el navegador; permanece en el marco del teléfono. Capturas composer-1280 y more-1280.
- Más390: cero encabezados app-header y región accesible Más. Captura more-390.

## Regresión y límites

Suite fresca55/55, cero fallos, model-tests.tap. Sintaxis app.js comprobada con node --check, salida0. Sin cambios modelo, Flutter ni APK. Diff en changes.diff. Revisión independiente en REVIEW.md: fuente, capturas y suite propia55/55; sin acceso propio a pestañas para recorridos interactivos.

Impeccable detect ejecutado una vez al cierre; salida2 por avisos, JSON íntegro. Sus avisos Inter/sombra heredada son preferencias sobre identidad preservada; microtexto del entorno no es el compositor. No se usa su puntuación para aprobar UX.

No se repitió el ciclo completo funcional. Cuotas, backups, SMS, Wallet y Android real conservan límites previos; no se validan teclado virtual, botón Atrás del sistema, gestos, TalkBack ni selectores nativos físicos. Las capturas y pruebas son del prototipo HTML. El usuario determina si esta dirección representa mejor Cabal como app Android; la suite funcional no acredita esa aprobación.

## Corrección menor de revisión

A320, Transferencia tenía clientWidth91 y scrollWidth93. Se asignó flex1.4 solo a ese segmento en anchos hasta360. Medición final: Gasto82=82, Ingreso82=82, Transferencia109=109. Captura income-320 actualizada. Sin bajar fuente ni renombrar acción. La recarga intermedia encontró servidor detenido y pestaña de error bloqueada por política URL; se reinició servidor local, se comprobó HTTP200 y se recuperó una pestaña nueva. La medición final es de navegador recuperado, no simulación. No se omite ese intento fallido como si hubiese probado producto.

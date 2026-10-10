# Simplificación de pestañas y anillos — 2026-10-07

Alcance: feedback sobre leyenda, colores, textura y títulos duplicados. Solo prototipo HTML; modelo financiero intacto.

## Cambios
- Eliminada la leyenda de presupuestos, sin ayudas sustitutivas.
- Anillos conservan verde dentro del objetivo y rojo para exceso. Pagado con color pleno, pendiente con opacidad 0.42; eliminados patrones rayados. Proporciones y porcentajes intactos.
- Eliminados encabezados repetidos de Inicio, Movimientos, Cuentas y Análisis; Más ya no tenía uno. Se mantienen encabezados y Volver en detalles y movimientos abiertos desde Reportes.
- Acciones integradas en contenido: bandeja en saldo, búsqueda junto a plantillas/filtros, agregar cuenta junto a tipos y movimientos del reporte junto a pestañas. Regiones conservan nombre accesible y foco al navegar.

## Comprobado en navegador
- 320×740: cuentas, movimientos, presupuestos y reportes; sin desbordamiento horizontal de página. Tipos de cuenta conservan desplazamiento horizontal.
- 390×844: Inicio, abrir/cerrar bandeja y búsqueda sin coincidencias.
- 1280×900: presupuestos, sin desbordamiento horizontal.
- Tamaño normal 692×876: Inicio y presupuestos.
- Movimiento → detalle Gasto → Volver: conserva título en detalle y vuelve con foco a región Movimientos.
- Reportes → movimientos: conserva encabezado y botón Volver en navegación secundaria.
- DOM: sin leyenda ni patrones SVG; segmentos rojo/verde, pendientes 0.42 y pagos 1. Importes accesibles conservados.

## Evidencias
- `before.png` y `home-after.png`: Inicio antes/después al mismo tamaño.
- `after.png`: presupuestos finales al tamaño normal.
- `accounts-320.png`, `budgets-320.png`, `home-390.png`, `history-empty-390.png`, `budgets-1280.png`.
- `ring-tests.tap`: 9/9; `model-tests.tap`: 55/55. Verificación de sintaxis app.js correcta.

## Evaluación independiente
Agente ui_review1 revisó fuentes, capturas y ejecutó ambas suites; comprobó también identificación/foco de las cinco raíces e importes/opacidades. Sin defectos relevantes confirmados en este alcance. No tuvo navegador propio: revisión de capturas y pruebas, no segunda ejecución interactiva.

## Límites
La revisión de navegador usa datos ficticios y viewports simulados. Esta tanda no vuelve a ejecutar todos los recorridos funcionales anteriores. No valida TalkBack, notificaciones del sistema, contraste perceptual de cada combinación, ni Android real. El tono suave es la propuesta visual para revisar con el usuario. No se modificó Flutter ni se generó APK.

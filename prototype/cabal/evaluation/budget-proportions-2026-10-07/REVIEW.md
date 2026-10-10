# Revisión independiente · proporciones de presupuesto

2026-10-07. Alcance: regla aprobada para anillo único, color proporcional dentro/exceso y textura pagado/pendiente. Sin modificar producto, Flutter ni model.js. Revisión de helper, SVG/CSS y capturas existentes; no atribuye validación Android real.

## Dictamen

No se confirmó defecto relevante nuevo. La regla está implementada: para250 sobre100, verde40% y rojo60%; pendiente rayado y pagado sólido. Un único radio y segmentos consecutivos reemplazan el arco interior de exceso. El centro conserva250%, expresando relación gasto/objetivo, mientras los arcos reparten la circunferencia según la composición del total.

## Evidencia propia

- `node prototype/cabal/budget-ring.test.cjs`: 8/8, cero fallos, `review-ring-tests.tap`.
- Matriz independiente de160 casos con el helper real mediante VM: cuatro objetivos, ocho pagos incluyendo negativos por devolución, cinco pendientes. Verifica proporción verde/rojo, longitudes positivas/ finitas, offsets consecutivos y suma ≤100%. `review-probes.cjs` / `review-probes.json`. No es simulación de navegador.
- Suite financiera fresca: 55/55, cero fallos, `review-model-tests.tap`.
- Capturas inspeccionadas: budgets390 (130%), pending250390 y pending250320.250pending390 muestra40%verde rayado/60%rojo rayado.320 no muestra el anillo250 completo por posición de scroll: confirma ajuste del grid/nombre, no se presenta como prueba visual completa de ese anillo.

## Comprobaciones de implementación

- Escala `max(objetivo,total,1)`: bajo objetivo queda tramo vacío; sobre objetivo suma100% y divide por total. Total negativo se representa sin arcos, conservando el porcentaje textual neto. Pago negativo no inventa un tramo sólido.
- El pago ocupa primero la parte dentro del presupuesto; si la supera continúa sólido rojo. Pendiente completa las partes restantes con su color y rayado. Ejemplos aprobados y casos mixtos cubiertos por pruebas.
- Patrones tienen ID índice/zona y se referencian por segmento. La pantalla genera un único grid; no se observa colisión de IDs en esa composición.
- `dl` no aplica aquí; SVG decorativo conserva `aria-hidden`, y el botón informa nombre, porcentaje, exceso, pagado y pendiente en aria-label. El detalle sigue accesible por el handler existente; no se modifican cálculos de presupuesto.
- Leyenda separa color y textura. El CSS específico `.budget-legend .pending-key` prevalece sobre la antigua leyenda de pagos. Las reglas antiguas del arco interior quedan sin elementos asociados; no afectan el nuevo SVG.

## Cobertura y límites

El principal comunica creación UI de categoría aislada, plan250k de una cuota y objetivo100k, DOM40/60pending y detalle pagado0/pendiente250/total250/exceso150. Son recorridos/mediciones del principal. Mi navegador independiente no tiene pestañas, por lo que esta revisión no afirma interacción propia ni contraste/gestos/lectura TalkBack medidos. Se espera evidencia del pago parcial100k para corroborar la transición de textura en navegador. No se requieren nuevas propuestas estéticas.

## Adenda · pago parcial

Inspeccionadas mixed250390 y mixed2501280: el anillo250% cambia a verde sólido40% y rojo rayado60%, preservando el mismo total. El principal confirma pago100k mediante UI y DOM within/paid40, excess/pending60. La transición concuerda con la regla aprobada y el helper; no aparece defecto relevante nuevo. La prueba explícita340% se agregará por el principal antes de cierre; el conteo8 anterior corresponde a mi ejecución previa, no a esa prueba posterior.
La captura mixta390 contiene toast sobre parte del anillo; la corroboración visual completa del estado mixto proviene de1280 y la medición DOM del principal, sin atribuir visibilidad completa a390.

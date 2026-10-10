# Cabal · Evaluación y mejora del prototipo

**Informe histórico del primer ciclo visual.** La aceptación registrada corresponde a este ciclo. El [segundo ciclo](ITERATION_2.md) queda pendiente de revisión final; el estado/prioridades se consolida en [ROADMAP](../../../docs/ROADMAP.md).

Fecha: 6 de octubre de 2026. Una ronda de cambios; evaluación inicial realizada antes de modificar archivos. Umbral: promedio ≥ 8, ningún criterio < 7 y sin bloqueos críticos conocidos en los flujos principales.

La misma rúbrica se aplica a ambas evaluaciones. Las notas son una valoración de diseño y funcionamiento del prototipo HTML, no una certificación de accesibilidad ni una validación de Android.

| Criterio | Inicial | Ronda 1 |
| --- | ---: | ---: |
| Jerarquía visual y legibilidad | 7 | 8 |
| Coherencia del diseño y los componentes | 8 | 8 |
| Claridad de la navegación y las acciones | 7 | 8 |
| Usabilidad y adaptación a pantallas móviles | 6 | 8 |
| Accesibilidad básica | 5 | 8 |
| Funcionamiento de las interacciones y fidelidad a las decisiones de producto aprobadas | 8 | 8 |
| **Promedio** | **6,83** | **8,00** |

## Observaciones y justificación por criterio

1. **Jerarquía y legibilidad, 7 → 8.** Inicialmente el patrimonio y las acciones principales tenían buena jerarquía, pero metadatos de movimientos/cuentas de 10 px, navegación de 9 px y ayudas claras dificultaban leer información necesaria. La ronda aumenta textos secundarios a 12 px, etiquetas a 13 px y formularios a 16 px; oscurece el texto secundario y conserva el protagonismo del patrimonio. Se inspeccionaron Inicio, Cuentas, formularios y Reportes. Se mantiene densidad de información y necesidad de desplazarse: no merece una nota superior.
2. **Coherencia, 8 → 8.** La paleta verde, tarjetas, iconos y acciones primarias/secundarias ya eran consistentes. Se preservan y se regularizan tamaños de controles. La interfaz continúa mezclando escenarios de simulación con pantallas propuestas claramente señaladas; el cambio no justifica subir la nota.
3. **Navegación y acciones, 7 → 8.** Al inicio varias pantallas secundarias no tenían destino principal activo. Se asigna Inicio a la bandeja, Cuentas a sus fichas y Más a la administración; los grupos de selección exponen su estado mediante aria-pressed. Al navegar se enfoca el título. Se separan los avisos de la barra inferior tras observar que un aviso de guardado podía interceptar el acceso a Análisis. La navegación anidada aún depende de Volver y conserva margen de mejora.
4. **Usabilidad móvil, 6 → 8.** Los controles iniciales incluían iconos de 42 px, cierre de diálogo pequeño y acciones de texto de menor altura. Se establecen alturas mínimas de 44 px para acciones, 46 px en campos y ajustes para 320 px; las etiquetas y campos de cierre/vencimiento se agrupan correctamente. El diseño compacto se extiende hasta 980 px para evitar estrechar el escritorio de dos columnas. Se inspeccionaron 320×740, 390×844, 800×900 y 1280×900. En 320 y 800 px, scrollWidth de la página coincidió con el ancho del viewport y la navegación quedó dentro de su altura. Los formularios largos requieren desplazamiento; no se probó teclado virtual real.
5. **Accesibilidad básica, 5 → 8.** Existían etiquetas, avisos de error, Escape y una trampa de Tab, pero el fondo seguía expuesto al abrir un diálogo, el contraste era débil y la recuperación del formulario podía perder el foco. La ronda aplica inert al fondo, enfoca el cierre en cada diálogo reconstruido, elimina el enfoque diferido que podía robar el campo activo, mejora contraste/foco visible, nombra los interruptores explícitamente y anuncia el total de divisiones. Se comprobó que el árbol accesible del diálogo excluye el fondo, Shift+Tab vuelve a Guardar movimiento, y cancelar un formulario intacto devuelve el foco a Gasto. No se hizo auditoría WCAG completa ni prueba con lector de pantalla real.
6. **Interacciones y fidelidad, 8 → 8.** La evaluación inicial incluyó rechazo de importe vacío, navegación de cuentas, lectura de PRODUCT_BASELINE y 16 pruebas del modelo aprobadas. Tras cambiar, se verificaron gasto manual, borrador, Wallet, pago y ambas modalidades de reportes con cifras conocidas. Se corrige la referencia inicial del formulario después de normalizar los controles para que cancelar sin cambios no pida descartar. Las decisiones asentadas se mantienen: patrimonio con ahorros menos deuda, pago fuera de gastos, revisión Wallet conjunta y canales por fuente. Las propuestas señaladas siguen siendo propuestas. La nota permanece en 8 porque las integraciones son ficticias y no se recorrieron todos los escenarios ni todas las combinaciones.

## Verificación realizada en la ronda 1

- Importe vacío: muestra «Ingresá un importe entero mayor que cero».
- Gasto manual de 50.000 ₲ en Efectivo: saldo 307.000 → 257.000; patrimonio 14.462.000 → 14.412.000.
- Cerrar borrador modificado y «Seguir editando»: conserva importe, comercio y cuenta; luego permite guardar.
- Cancelar formulario intacto: cierra sin confirmación adicional y devuelve foco a Gasto.
- Wallet: confirmar 185.000 ₲ de Mercado Verde en Crédito demo reduce pendientes 3 → 2 y aumenta deuda 905.000 → 1.090.000.
- Pago de 100.000 ₲ desde Cuenta diaria a Crédito demo: destino se mantiene en la tarjeta elegida; saldo bancario 10.510.000 → 10.410.000; deuda 1.090.000 → 990.000; patrimonio permanece 14.227.000 tras el gasto y Wallet anteriores.
- Reportes del mismo libro de prueba: compras completas 2.008.000 ₲; consumo por cuotas 2.208.000 ₲. Transferencias y pagos no se suman como gasto.
- Nueva cuenta de crédito: inspección visual de campos y cancelación/descartar en 320 px; no se guardó esa cuenta.
- Revisión visual de Inicio, Cuentas, Reportes y diálogos en los tamaños indicados.
- Sintaxis de app.js/model.js y las 16 pruebas de model.test.js.

## Resultado y límites

**Apto para revisión del usuario.** Promedio 8,00; mínimo individual 8. Se detiene después de una ronda. No se realizaron rondas 2 ni 3. No se conocen bloqueos críticos en los recorridos comprobados. La aceptación final corresponde al usuario.

No se compiló ni generó APK. No se probaron permisos Android, captura real Wallet, SMS, biometría, cifrado ni archivos reales. No se hicieron pruebas exhaustivas de todos los escenarios, lector de pantalla, ampliación de texto o teclado virtual. Las escenas simuladas y sus límites se conservan en README.md.

Se dejaron los datos iniciales de Uso diario limpios para revisión. Abrir ../index.html o http://127.0.0.1:8765/?scenario=daily&revision=1-final mientras esté activo el servidor local.

Capturas del resultado: round-1-mobile.jpg y round-1-desktop.jpg.

## Seguimiento posterior

El usuario aceptó la versión resultante de esta evaluación. Una revisión documental posterior contrastó el código con las variantes F01–F23 y registró diferencias adicionales en [PROTOTYPE_STATUS.md](../../../docs/PROTOTYPE_STATUS.md). Las notas anteriores corresponden a la evaluación y recorridos efectivamente probados; no certifican cumplimiento exhaustivo del plan ni paridad con Flutter. No se realizaron nuevas rondas de cambios como parte de esa actualización documental.

## Segundo ciclo posterior

El usuario pidió completar faltantes razonables del HTML. La evaluación y los cambios posteriores están en [ITERATION_2.md](ITERATION_2.md); las notas de este informe permanecen como registro histórico del primer ciclo.

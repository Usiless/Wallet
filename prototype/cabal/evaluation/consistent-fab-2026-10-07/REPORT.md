# Botones flotantes consistentes — 2026-10-07

## Alcance y cambios
Feedback aprobado: reemplazar el + desalineado de Cuentas y Crear de Presupuestos por el mismo FAB de Inicio/Movimientos; sustituir el bottom sheet de movimientos por botones flotantes individuales al estilo indicado por el usuario. Sin nuevos formularios ni cambios financieros.

- Componente creationAction centraliza las altas de estas cuatro pantallas.
- Inicio y Movimientos: + expandible; cuatro botones independientes con etiqueta e icono, sin panel. Cuentas: alta directa de cuenta. Presupuestos: alta directa de presupuesto del mes actual, conservando la regla existente.
- Mismos tamaño, color, radio y posición del FAB principal. El contenido conserva espacio al final para desplazarse por encima del botón.
- Escape, selección, clic fuera y salida de foco cierran el desplegable. Al seleccionar una opción se enfoca primero el + para que cerrar el formulario restituya foco visible.

## Verificación de navegador
- 390×844: expansión en Inicio y Movimientos; Gasto, Ingreso, Transferir y Compra en cuotas abren sus formularios. Alta de cuenta de prueba guardada y visible. FAB de presupuesto abre formulario.
- Teclado: Enter en +, Tab a Gasto, Enter, Volver → foco en Nuevo movimiento, desplegable cerrado.
- 320×740: cuatro acciones visibles, dentro del viewport, altura táctil 48px; sin desbordamiento horizontal. Navegar a Cuentas cierra el grupo.
- 1280×900: expansión en Inicio; alta de presupuesto de prueba guardada y visible; captura del listado de presupuestos.
- Las altas usan exclusivamente datos ficticios. Recarga final limpia las pruebas con el escenario de demostración.

## Regresión y evaluación independiente
9/9 pruebas de anillos y 55/55 del modelo; sintaxis app.js correcta. Resultados adjuntos en TAP.
Agente ui_review1 revisó fuentes, capturas y probes de selección del FAB por pantalla y orden de cierre/foco/acción. Detectó el retorno a opción oculta, corregido y confirmado con teclado en navegador principal. Sin otros defectos relevantes confirmados. El evaluador no dispuso de navegador propio.

## Evidencias y límites
Capturas home-expanded-390, history-expanded-390/320, accounts-390/320, budgets-390/1280 y home-expanded-1280. La prueba de escritorio usa el marco del prototipo Android. No se validaron Android real ni TalkBack. Sin modificaciones Flutter ni APK.

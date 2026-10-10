# Estado del prototipo HTML

Actualizado documentalmente: 2026-10-08; HTML aceptado el 2026-10-07, tras aceptación del usuario y solicitud de documentación. Este documento describe el HTML actual. El traslado anterior a Flutter se registra en [IMPLEMENTATION_PLAN](IMPLEMENTATION_PLAN.md#traslado-autorizado-a-flutter--2026-10-07); no implica paridad con las revisiones posteriores descritas aquí. Las [decisiones aprobadas](PRODUCT_BASELINE.md#prototipo-revisado-y-aceptado--2026-10-07) y la [matriz general](ROADMAP.md) conservan sus funciones respectivas.

## Estado vigente

- Cinco pestañas raíz sin encabezados repetidos; títulos y Volver en detalles. Inicio concentra disponible, pendiente del mes, patrimonio y próximos pagos. Las listas de cuentas y movimientos se consultan en sus pestañas; Cuentas usa tarjetas.
- Inicio y Movimientos comparten FAB desplegable con Gasto, Ingreso y Transferir. Cuentas y Presupuestos tienen FAB directo con el mismo diseño/posición. Retorno de foco al cerrar formularios, sin barra vacía inferior.
- Gasto incluye Descripción y En cuotas: crédito conserva compra/deuda total y cuotas mensuales; otras cuentas crean obligaciones pendientes, sin descontar saldo al crearlas. Se puede confirmar importe parcial, fecha y cuenta efectiva y trasladar resto a la siguiente cuota existente. Sin intereses ni extractos calculados.
- Plantillas programadas preparan pendientes de pago al procesarse en la demostración. No acreditan cobro. Recordatorios editables y aviso de ejemplo, sin notificación del sistema.
- Una categoría o reparto entre varias del mismo catálogo; selector único oculto al dividir. Planes divididos conservan sumas por categoría y residuos enteros.
- Anillos ajustados a consumo/objetivo: verde dentro, rojo para exceso, tonos suaves para pendientes y plenos para pagos. Sin rayado ni leyenda. Porcentaje real y detalle con importes. A 300%, un tercio verde y dos tercios rojo.
- Presupuestos se consultan por mes; el alta HTML sigue limitada al mes actual ficticio. No asumir edición/repetición HTML por existir en Flutter.
- Registro, ingresos, transferencias, devoluciones, edición, cuentas/catálogos, reportes, Wallet y backup conservan sus recorridos. CSV/JSON retirados. Las simulaciones no acreditan persistencia o integraciones nativas.

## Evidencia vigente

Última regresión: **57/57 pruebas financieras** y **9/9 pruebas de anillos**, más sintaxis de app.js. [Resultados](../prototype/cabal/evaluation/unified-expense-2026-10-07/REPORT.md). Los dos casos nuevos del modelo verifican conservación de repartos/saldo en planes y rechazo de división inválida sin crear obligaciones.

| Ciclo | Evidencia y alcance |
| --- | --- |
| Funcional | [Resultados y hallazgos](../prototype/cabal/evaluation/validation-2026-10-07/RESULTS.md): recorridos, correcciones y evaluaciones independientes. |
| Interfaz inicial | [Informe](../prototype/cabal/evaluation/ui-2026-10-07/REPORT.md). |
| Composición de app Android | [Informe](../prototype/cabal/evaluation/native-feedback-2026-10-07/REPORT.md): editor y navegación. |
| FAB y detalle | [Informe](../prototype/cabal/evaluation/fab-detail-2026-10-07/REPORT.md): acciones compartidas y metadatos de movimiento. |
| Inicio/Cuentas | [Informe](../prototype/cabal/evaluation/home-accounts-2026-10-07/REPORT.md). |
| Proporciones | [Informe](../prototype/cabal/evaluation/budget-proportions-2026-10-07/REPORT.md): matemática; su textura/leyenda fueron sustituidas por la revisión siguiente. |
| Simplificación | [Informe](../prototype/cabal/evaluation/quiet-tabs-2026-10-07/REPORT.md): tonos suaves, sin leyenda ni títulos redundantes. |
| Altas consistentes | [Informe](../prototype/cabal/evaluation/consistent-fab-2026-10-07/REPORT.md): botones individuales; la cuarta opción fue integrada posteriormente en Gasto. |
| Gasto unificado | [Informe final](../prototype/cabal/evaluation/unified-expense-2026-10-07/REPORT.md): cuotas, categorías, errores y conservación de borradores. |

En la última tanda se comprobó en navegador: plan de 100.001 en tres cuotas 33.333/33.333/33.335, dividido 60.001/40.000 por categoría, sin descontar disponible; crédito de 120.000 en tres cuotas, rechazo de121 cuotas; recordatorio personalizado conservado tras crear categoría; selector único oculto al dividir. Capturas a 320/390/1280 px, sin desbordamiento horizontal a 320.

Los informes distinguen ejecución del navegador principal de probes/simulaciones del evaluador. Las evaluaciones independientes finales no tuvieron navegador propio. Cada pasada tiene su alcance; 66 pruebas automatizadas no equivalen a reejecutar todos los recorridos en Android.

## Diferencias y límites nativos

Esta revisión solo modificó HTML/JS/CSS y documentación, sin Flutter ni APK. El traslado posterior expresamente autorizado incorpora esas capacidades a Flutter; [plan de diferencias](superpowers/plans/2026-10-07-approved-prototype-flutter.md) e [informe de ejecución y límites](evaluation/flutter-port-2026-10-07/REPORT.md). El HTML se conserva intacto durante ese trabajo. La inspección, las pruebas de host y las capturas Flutter no certifican ejecución Android.

El bloqueo/cifrado, Wallet, permisos, backup/archivos y recordatorios del HTML son simulaciones. No demuestra notificaciones reales, ejecución con app cerrada, programación persistente, reinicios, batería/OEM, TalkBack, teclado Android o cifrado/rollback de producción. El defecto histórico H01 fue corregido en el traslado previo según el plan; no está pendiente como fallo actual del HTML.

Fecha ficticia fija: 6 octubre de 2026, PYG entero, localStorage sin cifrado. [Cómo abrir/reiniciar](../prototype/cabal/README.md). Los resultados antiguos y las puntuaciones de los primeros ciclos son historia, no criterio único de aceptación. La presente aceptación corresponde a la experiencia del prototipo revisada con el usuario; SMS por ejemplos y otras apps siguen como dirección futura, sin implementación aprobada en este encargo.

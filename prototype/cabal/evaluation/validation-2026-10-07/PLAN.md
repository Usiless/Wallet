# Validación del prototipo Cabal · 2026-10-07

> Ejecución: Superpowers `executing-plans`, diagnóstico sistemático, regresiones RED→GREEN y revisión independiente. El usuario autoriza continuar sin confirmaciones entre tandas. Máximo cinco tandas de corrección/evaluación; detener antes si no quedan fallos relevantes confirmados en los criterios probados.

**Objetivo:** verificar y reparar los recorridos HTML existentes, preservando el alcance aprobado y dejando evidencia reproducible.

**Arquitectura:** libro ficticio `model.js`, interfaz `app.js`, estilos `styles.css` e inicio `index.html`; pruebas Node del modelo y recorridos manuales en navegador. Sin dependencias nuevas ni reestructuración general.

**Fuentes:** `AGENTS.md`, `docs/PRODUCT_BASELINE.md`, `docs/PROTOTYPE_STATUS.md`, `docs/PROTOTYPE_PLAN.md`, `prototype/cabal/README.md`, evaluaciones históricas y conversación de esta sesión. Las decisiones posteriores sustituyen las incompatibles anteriores.

## Alcance y decisiones

- Solo `prototype/cabal/`; sin Flutter, APK, CI, publicación ni integraciones reales.
- CSV/JSON retirados. No agregar ahorro con intereses, monedas, sincronización ni SMS por ejemplos.
- Créditos: deuda total inmediata; cuotas en su calendario, primera fecha editable, fin de mes sin deriva; devoluciones en fecha real. Pago de tarjeta/transferencia no son gasto.
- Autorización posterior para HTML: compras en cuotas fuera de tarjeta, pendientes/vencidos/pagados, confirmación de fecha/importe/cuenta, pago parcial y traslado del resto, plantillas que crean pendientes, recordatorios editables (3 días antes y al vencer, 09:00 inicialmente), separación previsto/pagado.
- Inicio con disponible protagonista y patrimonio menos deudas es una variante de diseño autorizada para probar; no implica aceptación definitiva ni traslado nativo. Los gastos recurrentes futuros se proyectan; su consideración como deuda desde vencimiento es el comportamiento actual a examinar, no nueva política financiera aprobada.
- Presupuestos editables/recurrentes y menú flotante en Movimientos están aprobados en producto pero documentados como brechas HTML. No inventar criterios de recurrencia en esta auditoría; registrar la brecha si no se recorre.
- Permisos, notificaciones, bloqueo y backups son simulaciones. Fecha fija 2026-10-06; localStorage sin cifrado. Solo datos ficticios.

## Criterios de aceptación y recorridos

| ID | Recorrido / oráculo | Verificación prevista |
|---|---|---|
| A01 | Primera vez sin cuentas; nueva cuenta reanuda gasto; cancelar no registra | Navegador + modelo |
| A02 | Gasto/ingreso/transferencia; importe inválido; división exacta; canal compatible | Navegador + modelo |
| A03 | Historial→detalle→editar/clonar/eliminar/deshacer; filtros y retorno conservados | Navegador + modelo |
| A04 | Crédito 101 en 3 cuotas: 33/33/35, categorías 51/50; primera fecha y fin de mes; pago/devolución sin duplicación | Navegador + modelo |
| A05 | Cuentas: editar/archivar/reactivar/conciliar; ahorro incluido en disponible sin alterar saldo | Navegador + modelo |
| A06 | Plantilla manual y programada, crear/editar/pausar/omitir; pendientes sin descuento y sin regeneración | Navegador + modelo |
| A07 | Compra en cuotas: saldo intacto; confirmar otra cuenta; 100.000−90.000→10.000 trasladados, última cuota conserva resto | Navegador + modelo |
| A08 | Factura variable: corregir total frente a pago parcial; edición futura conserva pagos e historial | Navegador + modelo |
| A09 | Recordatorios editables/desactivables; cerrar aviso no confirma pago | Navegador; entrega Android excluida |
| A10 | Presupuestos/reportes: pendiente por vencimiento, pago por fecha real; filtros; cinco vistas y neto negativo | Navegador + modelo |
| A11 | Wallet ficticio: permiso separado, reconocido/ambiguo/duplicado, revisar/cancelar/descartar; desarrollo restringido | Navegador + modelo; captura Android excluida |
| A12 | Backup ficticio: contraseña errónea, restauración, estado previo, borrador obsoleto y datos pendientes preservados | Navegador + modelo; cifrado/SAF excluidos |
| A13 | Móvil 320/390 y escritorio 1280: reflujo, navegación visible, controles utilizables, foco/inert/Escape/Tab | Navegador, mediciones DOM y capturas |

## Plan de ejecución

- [x] Leer fuentes, separar decisiones y propuestas, tomar copia inicial y ejecutar suite base.
- [x] Tanda 0: recorrer interfaces, capturar evidencias y registrar discrepancias con reproducción y oráculo; ejecutar pruebas pertinentes.
- [x] Solicitar evaluación independiente del código, criterios, pruebas y evidencias, sin edición concurrente del producto.
- [x] Por cada tanda 1–5 necesaria: confirmar hallazgos, escribir regresión que falle cuando corresponda, corregir causa y repetir pruebas/recorridos afectados.
- [x] Tras cada tanda: nueva evaluación independiente; registrar hallazgos resueltos, nuevos y no reproducidos.
- [x] Cierre: suite y sintaxis frescas, revisar aceptación, archivar resultados y límites; dejar prototipo abierto.

## Evidencia y severidad

P0: pérdida/corrupción grave de datos. P1: cálculo financiero incorrecto, duplicación, bloqueo de recorrido principal. P2: comportamiento o acceso aprobado que falla, edición incoherente, problema móvil importante. P3: defecto menor de presentación. Una limitación Android declarada no es un fallo HTML.

Guardar TAP por tanda, pruebas RED, capturas JPG, revisiones independientes y `RESULTS.md` con pasos y cifras. No usar notas numéricas como sustituto de pruebas. Solo declarar comprobados los recorridos efectivamente ejecutados.

## Adaptaciones del proceso

- No hay Git accesible (`git rev-parse --show-toplevel` falla). Se trabaja en el directorio pedido, con copia de los seis archivos iniciales en `/tmp/cabal-validation-baseline/`; sin commits/worktrees ficticios.
- El usuario ya fijó ejecución por tandas y autorizó correcciones sin confirmación. Se omiten las puertas genéricas de aprobación de diseño/plan de las skills que contradicen esa instrucción; las ampliaciones fuera de alcance se documentan, no se implementan.
- Libro de progreso y paquetes de revisión en esta carpeta, ubicación solicitada por el usuario. No se requieren scripts de ledger basados en commits inexistentes.

## Cierre de ejecución

Se ejecutaron tres tandas de corrección (R01–R07) y cuatro evaluaciones independientes. Se detiene antes del máximo de cinco: sin nuevos fallos relevantes confirmados en la cobertura examinada. Los límites de prueba por criterio están en RESULTS; no se presume validación exhaustiva ni Android.

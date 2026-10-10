# Cabal · Prototipo HTML

Demostración independiente con datos ficticios. Diseño revisado y aceptado por el usuario el 2026-10-07. [Decisiones vigentes](../../docs/PRODUCT_BASELINE.md#prototipo-revisado-y-aceptado--2026-10-07), [estado y evidencia](../../docs/PROTOTYPE_STATUS.md). El traslado anterior a Flutter no acredita paridad con estos cambios posteriores; esta revisión no modificó Flutter ni generó APK.

## Abrir

Desde la raíz del proyecto:

```bash
python3 -m http.server 8765 --bind 127.0.0.1
```

Abrir `http://127.0.0.1:8765/prototype/cabal/?scenario=payments`. Selector y reinicio afectan solo los datos de demostración. Escenarios: daily, first, credit, wallet, payments, scheduled, analysis, files y developer. Recargar con un escenario en la URL reinicia sus datos.

## Experiencia actual

- Inicio resume dinero disponible, pendiente del mes, patrimonio y próximos pagos; cuentas y movimientos en sus pestañas.
- FAB de Inicio/Movimientos despliega Gasto, Ingreso y Transferir. Cuentas/Presupuestos usan el mismo FAB para alta directa.
- Gasto incluye Descripción y En cuotas. Crédito registra deuda completa y calendario mensual; las demás cuentas preparan pagos pendientes sin descontar hasta confirmar. Pago parcial, fecha/cuenta efectiva y traslado de resto a siguiente cuota existente.
- Plantillas programadas preparan pendientes; recordatorios editables y aviso de ejemplo. No hay notificaciones reales.
- Categoría única o reparto: al dividir se oculta el selector único. Repartos enteros exactos también en cuotas.
- Anillos ajustados al consumo: verde dentro del objetivo, rojo para exceso; tono suave pendiente, pleno pagado; sin rayado ni leyenda. A 300%, un tercio verde y dos tercios rojo.
- Detalles conservan título/Volver; pestañas raíz sin títulos repetidos. Presupuestos consultables por mes, alta limitada al mes actual ficticio. CSV/JSON retirados; reportes, Wallet, backup y administración conservados.

## Verificación

```bash
node --check prototype/cabal/app.js
node --check prototype/cabal/model.js
node prototype/cabal/model.test.js
node prototype/cabal/budget-ring.test.cjs
```

Última regresión: 57 pruebas financieras +9 de anillos, todas correctas. Informe final y capturas; [índice de ciclos funcionales y visuales](../../docs/PROTOTYPE_STATUS.md#evidencia-vigente). Los informes anteriores son históricos: no describen necesariamente la interfaz actual ni acreditan repetición integral de pruebas.

## Datos y límites

Fecha fija: 6 octubre de 2026; PYG entero. localStorage bajo cabal-prototype-v1, sin cifrado; memoria como alternativa. No introducir datos personales ni contraseñas reales. Wallet, bloqueo, permisos, backup/archivos y notificaciones son simulaciones. Copias/contraseñas ficticias solo en memoria, se pierden al recargar. Sin criptografía, archivo real ni tareas con app cerrada. El servidor local solo sirve archivos del prototipo.

Capturas y recorridos en navegador a 320/390/1280 px; no prueban Android real, TalkBack, teclado virtual ni entrega de notificaciones. El escenario developer no valida las barreras nativas de desarrollo. SMS por ejemplos y fuentes de otras apps quedan para definición posterior.

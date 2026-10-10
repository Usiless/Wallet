# Registro de gasto unificado — 2026-10-07

## Alcance aprobado
Unificar Gasto y Compra en cuotas en un formulario. Opción En cuotas con cantidad/primera fecha, conservando mecanismos financieros diferentes. Descripción reemplaza el lenguaje conversacional. Al dividir categorías, ocultar categoría única. Solo HTML; sin Flutter/APK.

## Resultado
El FAB ofrece Gasto, Ingreso y Transferir. Gasto admite En cuotas: crédito registra el movimiento original con cuotas; cuenta no crédito prepara pendientes sin descontar hasta pagar, con recordatorios. Accesos desde Pagos pendientes abren el mismo formulario y usan «Gasto en cuotas». La categoría única queda oculta y deshabilitada al dividir.

Los planes admiten reparto por categoría y conservan totales exactos, fecha y nota. No se ofrece guardar un plan pendiente como plantilla desde este formulario. La edición de movimientos registrados no se convierte en un nuevo plan pendiente: conserva la validación de crédito existente. Los pendientes existentes conservan su editor de vencimientos.

## Comprobado en navegador
- Crear gasto no crédito de 100.001 dividido Alimentación 60.001 / Hogar 40.000, tres cuotas: 33.333, 33.333 y 33.335. Disponible sigue 727.000, pendiente aumenta por la cuota correspondiente.
- Crédito: 121 cuotas muestra error; tres cuotas sobre 120.000 guardan fila de 40.000.
- Personalizar recordatorio 7 días / 10:30 → crear categoría inline → guardar: descripción, cantidad y recordatorio preservados.
- Categoría única oculta al dividir; desplegable FAB sin opción independiente de compra en cuotas.
- Capturas a390×844,320×740 y1280×900. Sin desbordamiento horizontal a320. Evidencias unified-*.png y final.png.
- Recarga final descarta fixtures y deja formulario unificado abierto.

## Pruebas y evaluación independiente
57 pruebas financieras y9 de anillos pasan; TAP adjunto. Dos regresiones nuevas: reparto de plan conserva totales/saldo y rechazo atómico de división inválida.
Evaluador ui_review1 detectó riesgos de duplicar pendiente al editar, rango de cuotas y pérdida de metadatos al retomar borrador. Corregidos. Reejecutó suites, probes del formulario y matriz de12 planes divididos con saldos exactos; sin otros fallos relevantes confirmados. Sin navegador propio: pruebas interactivas hechas por agente principal.

## Límites
Datos ficticios, viewports simulados. Sin Android real, TalkBack ni notificaciones del sistema. No constituye nueva validación integral de los recorridos anteriores.

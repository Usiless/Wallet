# Limitaciones conocidas

Google Wallet y el registro automático de compras reconocidas están en Más → Google Wallet. El simulador, SMS, la inspección de notificaciones existentes y el diagnóstico requieren la bandera de desarrollo y el modo debug; están bloqueados en release/profile. Ver [herramientas de desarrollo](DEVELOPER_TOOLS.md).

## Seguridad y datos

- La base activa y el WAL usan SQLite3MultipleCiphers y la cola usa AES-GCM, con la clave protegida por Android Keystore. No se promete recuperación automática ante la pérdida de esa clave: la vía de recuperación es el backup portable, con su propia contraseña, que no puede recuperarse si se olvida.
- Backup y restauración usan copias SQLite temporales descifradas dentro del caché privado; se borran al terminar y, si hubo una interrupción, al siguiente inicio. Los backups y los respaldos previos persistentes están cifrados y autenticados.
- La restauración valida la integridad SQLite, las tablas, las columnas y las referencias antes de aplicar los datos. Conserva un respaldo cifrado previo y revierte la transacción si falla una escritura.
- El diagnóstico y los eventos vencidos se limpian al abrir o procesar; no hay eliminación programada mientras la app está cerrada.
- No hay backup programado ni integración con la API de Drive. El backup manual puede guardarse en Drive mediante el selector del sistema.
- CSV y JSON están retirados; la historia importada se conserva en la base y en los backups.

## Captura de compras

- El extractor de Google Wallet tiene fixtures sanitizados y una prueba manual con compras reales. Android y Google pueden cambiar textos y campos; faltan pruebas con más formatos, idiomas y dispositivos.
- No se emiten avisos del sistema para revisar propuestas. La captura puede ocurrir en segundo plano, pero el procesamiento y el registro ocurren al abrir o volver a la app, o mientras está visible.
- SMS funciona solo cuando Google Messages muestra una alerta Sudameris reconocible. No lee SMS directamente y no soporta otros bancos. La asociación de transferencias SMS sin contraparte queda para que el usuario elija la cuenta faltante.
- La detección de posibles duplicados con Wallet usa cuenta, comercio, importe y una ventana de tres días; no hay un identificador bancario de pago.

## Planificación

- Los gastos programados de importe fijo se procesan al abrir o volver a la app, con frecuencia mensual o anual y recuperación de atrasos; la preparación financiera no se ejecuta con la app cerrada. Cada pasada procesa hasta 120 vencimientos por plantilla. Los conflictos quedan en Plantillas, donde se puede editar, pausar u omitir un vencimiento.
- La agenda de recordatorios es independiente y persiste alarmas Android inexactas. La entrega se verificó con la app abierta, cerrada y tras reiniciar; las restricciones de cada fabricante pueden afectarla.
- Los reportes consultan todos los movimientos confirmados del período, con las cuotas mensuales enlazadas como criterio único. Las devoluciones impactan en su fecha; no se reprograman las cuotas futuras de la compra devuelta. El historial carga bloques de 50 movimientos.
- El tipo, la moneda y el saldo inicial de una cuenta existente no se editan; para corregir un saldo se usa la conciliación.

## Verificación y rendimiento

- Las pruebas manuales en el teléfono son parciales y no equivalen a una validación integral ni a una revisión de publicación en Google Play. Estado en el [roadmap](ROADMAP.md).
- La lentitud al abrir reportada el 2026-10-08 no se reproduce desde la verificación del 2026-10-10. Siguen sin medirse la hidratación con consultas repetidas, el trabajo previo a `runApp`, la cola de Wallet y la espera del receptor.

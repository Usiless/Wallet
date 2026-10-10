# CSV/JSON · referencia histórica

**Retirados del producto el 2026-10-07**, tanto HTML como Flutter. No hay pantalla, ruta ni exportadores CSV/JSON. Se preservan tablas `import_batches`/`import_rows`, huellas, movimientos y metadatos en la base y los backups. El código de importación/reversión se eliminó el 2026-10-10 por no tener uso; si se pide de nuevo, se reimplementa desde cero.

La antigua cabecera era `fecha;tipo;importe;moneda;cuenta_origen;cuenta_destino;categoria;subcategoria;comercio;canal;nota;referencia`, con importes enteros y huella por fila. La exportación abierta JSON tampoco se utiliza para restauración. La recuperación vigente es [`.finbackup`](BACKUP_FORMAT.md).

Evidencia: [regresión de backup con lotes importados](../test/core/backup/backup_service_test.dart) y [plan](IMPLEMENTATION_PLAN.md#traslado-autorizado-a-flutter--2026-10-07).

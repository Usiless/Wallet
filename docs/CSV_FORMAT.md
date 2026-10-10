# CSV/JSON · referencia histórica

**Retirados del producto el 2026-10-07**, tanto HTML como Flutter. No hay pantalla, ruta ni exportadores CSV/JSON. Se preservan tablas `import_batches`/`import_rows`, huellas, movimientos y metadatos en la base y los backups. Parser y métodos internos de importación/reversión quedan como compatibilidad histórica sin acceso de UI; no amplían alcance ni prometen reversión atómica.

La antigua cabecera era `fecha;tipo;importe;moneda;cuenta_origen;cuenta_destino;categoria;subcategoria;comercio;canal;nota;referencia`, con importes enteros y huella por fila. La exportación abierta JSON tampoco se utiliza para restauración. La recuperación vigente es [`.finbackup`](BACKUP_FORMAT.md).

Evidencia: [servicio histórico](../lib/features/imports/data/csv_import_service.dart), [parser](../lib/features/imports/domain/csv_import_parser.dart), [regresión de metadatos](../test/features/imports/csv_import_service_test.dart) y [plan](IMPLEMENTATION_PLAN.md#traslado-autorizado-a-flutter--2026-10-07).

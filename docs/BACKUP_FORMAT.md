# Formato `.finbackup`

El formato actual es un sobre JSON versionado (`formatVersion: 1`) codificado en UTF-8. No depende de un proveedor cloud: Android Storage Access Framework decide el destino.

## Sobre exterior

- `magic`: `FINANZAS_LOCALES_BACKUP`.
- `formatVersion` y `summary` con fecha UTC, esquema, cantidad de cuentas/movimientos y monedas.
- `databaseSha256`: checksum SHA-256 de la base SQLite clara.
- `kdf`: PBKDF2-HMAC-SHA256, 310.000 iteraciones y salt aleatorio de 16 bytes.
- `cipher`: AES-256-GCM, nonce, ciphertext comprimido con gzip y etiqueta MAC.

`magic`, versión, resumen y checksum forman los datos autenticados adicionales (AAD): no pueden alterarse sin invalidar AES-GCM. La clave de 256 bits se deriva de una contraseña mínima de ocho caracteres. Nonce y salt son nuevos para cada backup. AES-GCM proviene de `cryptography`; PBKDF2 utiliza el proveedor Android fuera del hilo de interfaz o una implementación Dart en isolate como alternativa. El formato se mantiene común. No se inventan primitivas criptográficas; ver `BackupCodec._deriveKey` y `DeviceCrypto.deriveBackupKey`.

La carga clara es un snapshot consistente creado con SQLite `VACUUM INTO`; contiene configuración y datos relacionales, incluidas plantillas y programación. Si hereda cifrado local, la copia temporal se convierte a SQLite claro antes del cifrado portable. No depende de la clave Keystore del dispositivo de origen.

## Restauración observada

`BackupService.restore` descifra y exige **igual versión de esquema** que la base activa (actualmente v1); no implementa una ruta de importación de backups con esquema anterior. Valida `integrity_check`, `foreign_key_check`, `user_version` y el conjunto de tablas/columnas esperado. Esto no debe describirse como validación exhaustiva de todas las reglas financieras.

Antes de modificar datos crea `before-restore-<uuid>.finbackup` en soporte privado, cifrado con la contraseña utilizada para restaurar. El reemplazo de filas ocurre en una transacción de la conexión existente; se difieren y vuelven a comprobar claves foráneas. Ante fallo de escritura se revierte esa transacción. La copia previa se conserva como recuperación adicional; no es un archivo SQLite claro ni se usa para sustituir físicamente la conexión. Los streams se notifican y no se exige reiniciar la app.

Los temporales `backup-<uuid>.sqlite` y `restore-<uuid>.sqlite` pueden contener datos claros; se eliminan en `finally` y `cleanupBackupWorkingFiles` limpia restos al siguiente inicio. No prometer eliminación instantánea tras una interrupción con la app cerrada.

Una contraseña olvidada no es recuperable. Una pérdida de la clave local es distinta de una contraseña de backup: falta verificar recuperación en Android con una copia portable disponible. No se declara recuperación automática ante pérdida de Keystore.

Evidencia: [servicio](../lib/core/backup/backup_service.dart), [codec](../lib/core/backup/backup_codec.dart), [almacenamiento](../lib/core/database/encrypted_storage.dart) y [pruebas](../test/core/backup/backup_service_test.dart). Las pruebas de host no acreditan SAF, Keystore ni interrupciones reales en Android. Procedimiento pendiente en [DEVELOPMENT](DEVELOPMENT.md).

Formato y esquema siguen en v1. El snapshot conserva las fechas completas de cuotas y los calendarios históricos sin recalcularlos. Al comenzar el reemplazo transaccional, `AppDatabase.restoreGeneration` invalida formularios anteriores, también si falla el reemplazo; los datos sí revierten por transacción. Es un contador de sesión y no cambia el archivo portable. Regresión de calendario/round-trip en [monthly_installments_test](../test/features/installments/monthly_installments_test.dart).

Los documentos `pending_payment:v1:<id>` de `app_settings` forman parte del snapshot cifrado existente, sin cambiar formato ni esquema. El validador comprueba estructura, importes, categorías, enlaces a pagos reales y trazabilidad de deuda trasladada. Backups v1 previos sin obligaciones siguen admitidos. La agenda de alarmas no se exporta como datos financieros: se reconcilia con el libro restaurado. Las regresiones están en las [pruebas de backup](../test/core/backup/backup_service_test.dart) y en las [de pagos pendientes](../test/features/payments/pending_payment_edge_cases_test.dart); no acreditan SAF ni interrupciones en Android.

La validación rechaza deuda trasladada sin destino/historial y comprueba suma total, categorías acumuladas y destinos posteriores del mismo plan. Una representación v1 antigua con `carriedTo` concreto y válido se normaliza a historial; no se inventan destinos ausentes. Las pruebas incluyen ciclos reales de traslado con y sin categorías y el rechazo de obligaciones manipuladas con deuda huérfana.

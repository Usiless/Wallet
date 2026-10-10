# Modelo de datos v1

La definición ejecutable está en `lib/core/database/app_database.dart`; la huella contractual está en `drift_schemas/schema_v1.json`.

## Núcleo financiero

- `accounts`: banco, ahorro, efectivo o tarjeta; moneda, saldo inicial y reglas de inclusión.
- `account_aliases`: números enmascarados y alias normalizados por fuente.
- `credit_card_profiles`: límite, cierre, vencimiento, mínimo y último extracto.
- `transactions`: cabecera de ingreso, gasto, transferencia, reembolso o ajuste; origen, estado, moneda, fecha, cuentas y referencias externas.
- `account_postings`: efectos por cuenta y moneda de una transacción confirmada; se reconstruyen transaccionalmente al editar, no son un historial inmutable de todas las revisiones.
- `transaction_splits`: distribución exacta entre categorías.
- `categories`: jerarquía, clase ingreso/gasto/ambas y presentación.
- `merchants`, `merchant_aliases`, `categorization_rules`: normalización y aprendizaje local.

## Planificación, automatización y auditoría

- `budgets`: meta mensual total o por categoría y umbrales.
- `installment_plans`, `installment_entries`: total comprometido y reparto entero por fecha mensual. `firstPeriod` conserva la primera fecha completa; `period` de cada entrada usa mediodía UTC. El día ancla vuelve después de meses cortos. No cambia esquema v1 ni se reescriben calendarios antiguos.
- `recurring_templates`: plantillas y próxima fecha opcional.
- `notification_events`: sobre Android; texto crudo solo en diagnóstico y con vencimiento.
- `payment_candidates`: propuesta extraída, confianza, cuentas sugeridas, huella y estado.
- `dedup_decisions`: motivo auditable de creación, actualización o duplicado.
- `import_batches`, `import_rows`: lotes y resultados históricos CSV conservados; ya no hay importación/exportación de producto ni código de importación.
- `audit_logs`: cambios locales de entidades financieras.
- `app_settings`: preferencias y documentos versionados dentro de la base cifrada. Las plantillas manuales usan `manual_template:<id>`; las obligaciones de pago usan `pending_payment:v1:<id>`.

La programación de las plantillas de uso actual guarda sus campos y fecha ancla en el JSON `manual_template:<id>` de `app_settings`; `recurring_templates` es una tabla conservada del esquema. Los vencimientos nuevos generan obligaciones pendientes mediante una referencia estable `scheduled:<templateId>:<fecha>` y no partidas financieras. El motor también consulta las huellas históricas en `transactions.external_fingerprint`, incluso de registros eliminados, para no reinterpretar ni duplicar vencimientos ya procesados. Se preparan al abrir/volver hasta el fin del mes siguiente, con máximo de 120 vencimientos por plantilla en cada pasada.

Las obligaciones conservan plan, número/cantidad de cuota, importe, vencimiento, descripción, cuenta sugerida, categorías exactas, recordatorios, revisión y pagos enlazados a transacciones reales. La creación de un plan no descuenta saldo. Confirmar un pago crea un gasto real transaccionalmente; un pago parcial conserva el resto o lo traslada a la siguiente cuota existente. La generación de restauración invalida formularios anteriores. El backup valida también la estructura y referencias de estos documentos; no se cambian tablas ni versión v1.

La agenda de recordatorios Android es independiente del libro: almacenamiento cifrado con DeviceCrypto, alarmas inexactas y acciones para abrir la obligación. No escribe pagos ni necesita leer la base en segundo plano. Su entrega real se verifica en el teléfono; ver el [roadmap](ROADMAP.md).

## Reglas de saldo

| Movimiento | Cuenta origen | Cuenta destino | Gasto analítico |
| --- | ---: | ---: | --- |
| Gasto bancario/efectivo | disminuye activo | — | sí |
| Compra con tarjeta | aumenta deuda | — | sí |
| Ingreso | — | aumenta activo | no |
| Pago de tarjeta | disminuye banco | disminuye deuda | no |
| Transferencia a ahorro | disminuye origen | aumenta destino | no |
| Reembolso bancario | — | aumenta activo | revierte gasto |
| Reembolso de tarjeta | disminuye deuda | — | revierte gasto |

Para una tarjeta, “saldo natural” representa deuda positiva. Por eso tanto el débito bancario como la reducción de deuda se guardan como deltas negativos al pagarla. Un pendiente no genera postings. Las divisiones deben sumar exactamente el importe total. Al editar se conserva el ID de cada división cuya categoría sigue presente, para mantener estable el reparto entero mensual por orden de ID.

Las fechas financieras se interpretan en `America/Asuncion`; los instantes técnicos se conservan en UTC. Las fechas del calendario de cuotas usan una fecha canónica al mediodía UTC para evitar cambios de día por conversión.


`MovementRow` es una proyección de lectura: importe/fecha/número de cuota y referencia a la compra canónica. No se persiste como otro movimiento. `restoreGeneration` es un contador de sesión, no una columna; invalida formularios abiertos al reemplazar el libro.

Los traslados parciales guardan `carriedMinor`, `carriedSplits`, `carriedTo` y el historial acumulativo `carries`: cada destino existe en el mismo plan y es posterior; los importes y categorías deben coincidir exactamente. Editar no reduce por debajo de la deuda ya trasladada ni modifica cuotas con pagos. El reparto inicial por categorías usa restos enteros contra capacidades remanentes para conservar cada cuota y cada total por categoría sin valores negativos.

Una edición del calendario de plantilla reemplaza solamente ocurrencias futuras sin enlaces históricos de pago: quedan canceladas con `supersededBySchedule:true`. La deduplicación puede reemplazar esas ocurrencias, pero conserva cancelaciones manuales y pagos históricos. El avance interno del cursor del programador no se interpreta como una edición del usuario.

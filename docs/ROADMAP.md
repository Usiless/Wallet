# Roadmap

Estado al 2026-10-10. [PRODUCT_BASELINE](PRODUCT_BASELINE.md) conserva las decisiones; [DEVELOPMENT](DEVELOPMENT.md) contiene los recorridos de verificación en el teléfono; [ARCHITECTURE](ARCHITECTURE.md) explica cómo está organizado el código.

Todo lo aprobado está implementado en Flutter, con análisis limpio y 367 pruebas de host. Las pruebas de host no sustituyen la verificación en Android: la columna «Android» indica qué ha comprobado el usuario en el teléfono (datos descartables, dispositivo/API sin registrar).

## Cómo leer el estado

- **Aprobada**: asentada explícitamente en la base o en [AGENTS](../AGENTS.md). **Propuesta**: requiere revisión y aprobación. El código por sí solo no aprueba un alcance.
- **Verificada**: el usuario la recorrió en Android sin incidencias. **Parcial**: parte del recorrido verificada; el resto se detalla abajo. **Pendiente**: solo probada en host.
- Los IDs F, V y P no se reciclan al completar o descartar trabajo. Cambiar un estado exige archivo o resultado fechado.

## Capacidades

| ID · capacidad | Android | Código y pruebas |
| --- | --- | --- |
| F01 · Empezar sin banco precargado | Verificada | [onboarding](../lib/features/onboarding/presentation/onboarding_screen.dart), [prueba](../test/features/onboarding/onboarding_service_test.dart) |
| F02 · Registrar gasto rápido con comercio propio | Verificada | [formulario](../lib/features/transactions/presentation/transaction_form_screen.dart), [estado](../lib/features/transactions/presentation/transaction_form_state.dart), [guardado](../lib/features/transactions/data/transaction_form_service.dart), [pruebas](../test/features/transactions/transaction_form_save_test.dart) |
| F03 · Asignar un gasto a varias categorías | Verificada | [partidas](../lib/features/transactions/domain/posting_calculator.dart), [reparto](../lib/core/money/allocation.dart), [prueba](../test/features/transactions/posting_calculator_test.dart) |
| F04 · Ingresos y transferencias sin duplicar gasto | Verificada | [política de canal](../lib/features/transactions/domain/payment_channel_policy.dart), [prueba](../test/features/transactions/payment_channel_policy_test.dart) |
| F05 · Deuda completa y cuotas mensuales enlazadas | Verificada | [calculador](../lib/features/installments/domain/installment_calculator.dart), [servicio](../lib/features/installments/domain/installment_service.dart), [pruebas](../test/features/installments/monthly_installments_test.dart) |
| F06 · Pagar la tarjeta correcta sin otro gasto | Verificada | [detalle de cuenta](../lib/features/accounts/presentation/accounts_screen.dart), [prueba](../test/features/management/approved_accounts_test.dart) |
| F07 · Encontrar y corregir movimientos | Verificada | [historial](../lib/features/transactions/presentation/transactions_screen.dart), [repositorio](../lib/features/transactions/data/ledger_repository.dart), [paginación](../test/features/transactions/history_pagination_test.dart) |
| F08 · Eliminar y deshacer | Verificada | [acciones](../lib/features/transactions/presentation/ledger_actions.dart), [LedgerService](../lib/features/transactions/data/ledger_service.dart), [prueba](../test/features/transactions/ledger_service_test.dart) |
| F09 · Devolución parcial sin reescribir la compra | Verificada | [devolución](../test/features/transactions/ledger_actions_test.dart), [regresiones](../test/features/management/basic_features_test.dart) |
| F10 · Administrar cuentas, ahorro y alias | Verificada | [AccountsService](../lib/features/accounts/data/accounts_service.dart), [cuentas](../lib/features/accounts/presentation/accounts_screen.dart), [ahorro](../test/features/dashboard/savings_overview_test.dart) |
| F11 · Conciliar un saldo con un ajuste separado | Verificada | [conciliación](../test/features/transactions/ledger_actions_test.dart), [pruebas básicas](../test/features/management/basic_features_test.dart) |
| F12 · Reutilizar movimientos con plantillas | Parcial: uso y guardado desde el formulario verificados | [servicio](../lib/features/templates/manual_template_service.dart), [pantalla](../lib/features/templates/templates_screen.dart), [pruebas](../test/features/templates/templates_screen_test.dart) |
| F13 · Preparar gastos fijos pendientes sin asumir pago | Verificada | [motor](../lib/features/templates/scheduled_template_service.dart), [pruebas](../test/features/templates/scheduled_template_service_test.dart) |
| F14 · Elegir captura de Google Wallet y revocar acceso | Parcial | [ajustes](../lib/features/settings/presentation/wallet_settings_screen.dart), [puente](../lib/core/notifications/native_notification_bridge.dart), [prueba](../test/features/notifications/wallet_settings_test.dart) |
| F15 · Revisar compras nuevas o ambiguas antes de afectar saldo | Parcial | [revisión](../lib/features/pending_inbox/presentation/candidate_review_dialog.dart), [ingestión](../lib/core/notifications/notification_ingestion_service.dart), [prueba](../test/features/notifications/candidate_review_dialog_test.dart) |
| F16 · Registro automático de compras reconocidas (opcional) | Parcial | [automatización](../test/features/notifications/wallet_automation_test.dart), [listener](../android/app/src/main/kotlin/py/finanzaslocales/finanzas_locales/WalletNotificationListenerService.kt) |
| F17 · Presupuestos con consulta mensual y anillos | Verificada | [pantalla](../lib/features/budgets/presentation/budgets_screen.dart), [servicio](../lib/features/budgets/domain/budget_service.dart), [pruebas](../test/features/budgets/approved_analysis_test.dart) |
| F18 · Reportes por período con acceso al historial | Verificada | [ReportService](../lib/features/reports/data/report_service.dart), [pruebas](../test/features/reports/report_analysis_test.dart) |
| F19 · Catálogos y asociaciones | Verificada | [catálogo](../lib/features/catalog/catalog_screen.dart), [MerchantService](../lib/features/merchants/merchant_service.dart), [prueba](../test/features/catalog/catalog_screen_test.dart) |
| F20 · CSV/JSON retirados, historia importada conservada | Verificada | [prueba de backup con lotes importados](../test/core/backup/backup_service_test.dart) |
| F21 · Backup y restauración sin perder datos | Verificada | [BackupService](../lib/core/backup/backup_service.dart), [codec](../lib/core/backup/backup_codec.dart), [pruebas](../test/core/backup/backup_service_test.dart) |
| F22 · Bloqueo y cifrado local | Verificada | [bloqueo](../lib/shared/widgets/app_lock_gate.dart), [almacenamiento](../lib/core/database/encrypted_storage.dart), [pruebas](../test/core/security/app_lock_service_test.dart) |
| F23 · Diagnóstico solo en desarrollo | Parcial: barreras comprobadas en binarios, sin recorrido en teléfono | [bandera](../lib/core/config/feature_flags.dart), [Gradle](../android/app/build.gradle.kts), [prueba](../test/features/developer_tools/developer_tools_test.dart) |
| F24 · Cuotas no crédito y pagos parciales | Verificada | [servicio](../lib/features/payments/domain/pending_payment_service.dart), [pantallas](../lib/features/payments/presentation/payments_screen.dart), [pruebas](../test/features/payments/pending_payment_service_test.dart) |
| F25 · Recordatorios de vencimientos sin confirmar pagos | Verificada con la app abierta, cerrada y tras reinicio | [coordinador](../lib/core/notifications/payment_reminder_coordinator.dart), [receptor](../android/app/src/main/kotlin/py/finanzaslocales/finanzas_locales/PaymentReminderReceiver.kt), [pruebas](../test/core/notifications/payment_reminder_test.dart) |

Tras la reorganización del formulario de movimiento (ViewModel, servicio de guardado y pantalla en piezas), el usuario recorrió en el teléfono el 2026-10-10 las salidas con cambios, «Guardar y crear otro», editar y clonar un gasto dividido, plantillas, pago de tarjeta, cuotas con primera fecha, comercio con categoría recordada, creación de categoría y «Más detalles», sin incidencias.

## Verificación pendiente en Android

Recorridos y datos en [DEVELOPMENT](DEVELOPMENT.md#verificación-android-pendiente).

- **V03 · Wallet y barreras.** Verificados con Wallet real: comercio nuevo y compra repetida. Pendientes: alias ambiguo, notificación actualizada, coincidencia con un movimiento programado, y las barreras de herramientas de desarrollo en un profile/release instalado.
- **Sin constancia en el registro:** texto ampliado, TalkBack, tema oscuro y el símbolo ₲ en fuentes reales de Android; restricciones de fabricantes y cambio de zona horaria en los recordatorios.

## Alcance aprobado

P01–P06 están aprobadas e implementadas: cinco pestañas, consulta mensual de presupuestos con edición y repetición, retirada de CSV/JSON conservando la historia, información clara sobre Wallet y backups, cuotas mensuales enlazadas con primera fecha elegible y uso personal sin plan de publicación. Las reglas están en [PRODUCT_BASELINE](PRODUCT_BASELINE.md).

## Propuestas sin aprobación

Ninguna está aprobada ni se implementa sin un acuerdo explícito.

- **P07 · Plazos e intereses de ahorro.** Propuesta del usuario. Hoy el ahorro es una cuenta utilizable (F10). Antes de diseñar hay que definir tasa, período, capitalización, vencimiento y la diferencia entre interés real y proyectado. Una proyección no puede alterar el patrimonio real.
- **P08 · Backups periódicos.** Los recordatorios de cuotas y pendientes están aprobados e implementados (F25). Falta decidir frecuencia, destino, contraseña, errores y ejecución con la app cerrada. No hay Drive ni backup automático aprobado.
- **P09 · Monedas adicionales y otras fuentes.** Hoy PYG es la moneda soportada por la interfaz y SMS sigue experimental. Hay que recoger ejemplos sanitizados y decidir por separado qué moneda o identificador real hace falta. Excluye conversión implícita, tasas remotas y ampliar las fuentes normales.

## Proceso para trabajo nuevo

**Propuesta → aprobación explícita del alcance → implementación en Flutter con pruebas → verificación en Android.** Para funciones nativas, la captura, las claves, los archivos y el ciclo de vida solo se validan en el teléfono. Cerrar una iniciativa exige registrar el criterio cumplido, el entorno y el resultado, además de la aprobación que corresponda.

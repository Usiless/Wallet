# Roadmap principal de Cabal

Revisión documental: 2026-10-09. El usuario autorizó «actualiza la documentación relevante y luego mueve el prototipo a flutter». **Traslado implementado en Flutter y probado en host; Android real pendiente.** [PRODUCT_BASELINE](PRODUCT_BASELINE.md) conserva decisiones; [IMPLEMENTATION_PLAN](IMPLEMENTATION_PLAN.md#traslado-autorizado-a-flutter--2026-10-07) registra cambios y resultados por ID; [DEVELOPMENT](DEVELOPMENT.md) contiene el recorrido Android.

P01–P05: cinco pestañas, consulta mensual/anillos, tabla compacta de reportes, alta flotante, accesos sin duplicados, retirada CSV/JSON y cuotas mensuales enlazadas con primera fecha elegida. H01 corregido con reparto compartido exacto; CI-01 aplicado, sin ejecutar workflow ni compilar APK. En ese primer traslado no se modificaron Android nativo, identificadores de instalación, dependencias ni esquema v1; el traslado posterior agrega una agenda Android, manteniendo identificadores y esquema. V01–V03 siguen pendientes de aceptación integral en Android; ver más abajo la aprobación posterior parcial de P08.

## Revisión HTML posterior aceptada · 2026-10-07

El prototipo actual incorpora gasto unificado con cuotas, pendientes de pago y recordatorios simulados, simplificación de Inicio, FAB consistentes y anillos proporcionales sin leyenda/rayado. El usuario acepta esta revisión y pide documentarla. [Decisiones vigentes](PRODUCT_BASELINE.md#prototipo-revisado-y-aceptado--2026-10-07), [estado y diferencias nativas](PROTOTYPE_STATUS.md) y evidencias.

Última regresión HTML: **57 pruebas financieras + 9 de anillos**, sin fallos. Recorridos de navegador y revisiones independientes delimitados en los informes. Esta revisión no modificó Flutter ni generó APK; el traslado previo no acredita paridad con estos ajustes posteriores. La continuación nativa fue autorizada expresamente y se contrastó en el plan del traslado; su resultado y límites se registran en [el informe Flutter](evaluation/flutter-port-2026-10-07/REPORT.md).

P08 queda parcialmente aprobado para recordatorios de cuotas y gastos pendientes; backups periódicos siguen como propuesta. P07 y el resto de P09 siguen fuera; los ejemplos de SMS son una dirección futura, sin alcance de implementación aprobado.

## Traslado posterior a Flutter · 2026-10-08

Implementados el registro unificado, obligaciones no crédito con pagos reales, preparación pendiente de plantillas, agenda Android separada, distribución Inicio/Cuentas, anillos proporcionales y simplificación de raíces. Se conservan el calendario de crédito, datos anteriores, Wallet normal, herramientas experimentales restringidas, identificadores y esquema v1. Revisiones independientes y pruebas por tanda están en [el informe](evaluation/flutter-port-2026-10-07/REPORT.md); no se declara validación integral Android ni paridad exhaustiva solo por inspección.

## Unificación de pendientes · 2026-10-10

Aprobados los pasos 1–3 de [UNIFICATION_PROPOSAL](UNIFICATION_PROPOSAL.md) (decisión en [PRODUCT_BASELINE](PRODUCT_BASELINE.md#unificación-de-pendientes--aprobación-explícita-2026-10-10)). Implementados y probados en host (254 pruebas, análisis limpio); Android pendiente. Detalle en [IMPLEMENTATION_PLAN](IMPLEMENTATION_PLAN.md#unificación-de-pendientes--pasos-13--2026-10-10).

Aprobada y aplicada en Flutter (host; Android pendiente): [reorganización del formulario de movimiento](FORM_PROPOSAL.md).

## Alcance acordado · 2026-10-06

El usuario aprobó cinco pestañas en Flutter, consulta de presupuestos de otros meses, cuotas desde mes de compra sin cálculo de mínimo/extracto, Wallet opcional y retirada del build APK automático en CI. También decidió retirar CSV y JSON, manteniendo backup cifrado/restauración y los datos existentes. Uso personal, sin plan de publicación. Ver [decisiones aprobadas](PRODUCT_BASELINE.md#decisiones-de-continuación--2026-10-06) y [plan breve vigente](IMPLEMENTATION_PLAN.md).

P01/P02 quedan aprobadas en ese alcance limitado; P03 se sustituye por retirada, P04 se limita a Wallet/backup y P05 queda resuelta sin nuevas reglas bancarias. CI-01 quedó aplicado al trasladar Flutter. P06 no exige definir una versión pública. P07 y P09 siguen fuera; P08 tiene la aprobación parcial posterior indicada arriba. Las matrices y descripciones siguientes conservan la inspección y propuestas previas; cualquier alternativa incompatible queda superada por este acuerdo. La fase HTML fue seguida por el traslado explícitamente autorizado a Flutter el 2026-10-07; esa ejecución anterior dejó Android nativo intacto; la agenda posterior se registra en el informe del traslado actual. Ver [ejecución y evidencia](IMPLEMENTATION_PLAN.md#ejecución-autorizada--2026-10-06).

## Cierre Flutter solicitado · 2026-10-09

Traslado y correcciones dentro del alcance terminados:249 pruebas, análisis limpio y revisión independiente cerrada. Compilado APK profile expresamente solicitado; firma, identidad y flag comprobados. Entrega no equivale a validación Android real ni garantiza resolución del bloqueo al abrir reportado por el usuario. [Resultados definitivos](evaluation/flutter-port-2026-10-07/REPORT.md).

## Cómo leer y mantener el estado

Aprobación y ejecución son ejes independientes. **Aprobada** significa asentada explícitamente en la base/AGENTS; **propuesta** requiere revisión; **pendiente de aclaración** señala ambigüedad sin resolverla. El código por sí solo no aprueba un alcance. La aceptación HTML registrada en documentos anteriores corresponde al diseño, no a una orden de traslado a Flutter o publicación.

HTML: **No representado** = sin representación encontrada en los archivos revisados; **Parcial** = recorrido con variantes ausentes conocidas; **Simulado** = reproduce experiencia de sistema/archivos sin integración; **Flujo navegable** = recorrido y manejadores encontrados con libro ficticio; no acredita prueba DOM exhaustiva. **No aplica** = no aporta validación útil; **No verificado** = evidencia insuficiente. «No encontrado» delimita búsqueda, no prueba inexistencia absoluta.

Flutter: **No implementado** se reserva para ausencia expresamente documentada y coherente con búsqueda; **Parcial** = servicio, pantalla o variante incompleta identificada; **Implementado según inspección** = pantalla, servicio, persistencia y dependencias pertinentes encontrados, sin certificar Android; **Verificado en ejecución** requiere recorrido identificado en Android con entorno y resultado; **No verificado** = no se pudo concluir. Ninguna fila de esta auditoría recibe «Verificado en ejecución». Pasar tests de host no cambia eso.

Los ID F01–F23 conservan los del [plan HTML](PROTOTYPE_PLAN.md). V identifica validación de capacidades aprobadas; P conserva los IDs de propuestas, aun después de aprobarlas o retirarlas. No reciclar IDs al completar o descartar trabajo. Cambiar estado solo con archivo/símbolo o resultado fechado; conservar límites y decisiones abiertas.

## Capacidades actuales y brechas

Fuente de decisión de F01–F22: apartados «Decisiones ya asentadas» y «Funciones básicas completadas» de [base](PRODUCT_BASELINE.md), excepto nuevas presentaciones señaladas. F23: también [AGENTS](../AGENTS.md). Cada fila incluye necesidad, situación de decisión, evidencias y siguiente paso. Todas las verificaciones Android siguen pendientes; las pruebas enlazadas son de host.

Evidencia HTML común: [app.js](../prototype/cabal/app.js) enlaza formularios/acciones al [model.js](../prototype/cabal/model.js); las [57 pruebas financieras](../prototype/cabal/model.test.js) y [9 de anillos](../prototype/cabal/budget-ring.test.cjs) cubren parte del libro y su representación. Evidencia Flutter transversal: [router](../lib/app/router.dart), [providers](../lib/app/providers.dart), [base](../lib/core/database/app_database.dart). La tabla cita componentes específicos además de esa conexión común.

| ID · necesidad y decisión | HTML | Flutter/Android | Evidencia específica y brecha → siguiente paso |
| --- | --- | --- | --- |
| F01 · Empezar sin banco precargado. Aprobada. | Flujo navegable; bloqueo simulado. | Implementado según inspección. | `onboarding`, `accountForm` en app.js; [onboarding](../lib/features/onboarding/presentation/onboarding_screen.dart), [servicio/test](../test/features/onboarding/onboarding_service_test.dart). Alta opcional encontrada; verificar inicio vacío y vuelta en Android (V01). |
| F02 · Registrar gasto rápido con comercio propio. Aprobada. | Flujo navegable; alta sin cuentas reanuda formulario por `account-resume`. | Implementado según inspección. | `composer/readDraft/save` JS; [formulario](../lib/features/transactions/presentation/transaction_form_screen.dart), [LedgerService](../lib/features/transactions/data/ledger_service.dart), [test](../test/features/transactions/transaction_form_test.dart). Cancelación, validación y saldos requieren V01. |
| F03 · Asignar un gasto a varias categorías. Aprobada. | Flujo navegable; valida suma en modelo. | Implementado según inspección. | `validate/parts` JS; [splits/postings](../lib/features/transactions/domain/posting_calculator.dart), [test](../test/features/transactions/posting_calculator_test.dart). Conservar total entero y preferencia de comercio; comprobar legibilidad con teclado (V01). |
| F04 · Registrar ingresos y mover dinero sin duplicar gasto. Aprobada. | Flujo navegable. | Implementado según inspección. | `channels/balance/save` JS; [política de canal](../lib/features/transactions/domain/payment_channel_policy.dart), LedgerService y [tests](../test/features/transactions/payment_channel_policy_test.dart). Probar combinaciones de cuentas y canales (V01). |
| F05 · Deuda completa y cuotas mensuales enlazadas. Aprobada, actualizada 2026-10-07. | Flujo navegable. | Implementado y probado en host; Android pendiente. | Primera fecha editable por defecto compra, ancla mensual sin deriva, futuras previstas; [calculador](../lib/features/installments/domain/installment_calculator.dart), [servicio](../lib/features/installments/domain/installment_service.dart), [regresiones](../test/features/installments/monthly_installments_test.dart). No calcula cierre/mínimo/extracto. V01/V02 en Android. |
| F06 · Pagar la tarjeta correcta sin otro gasto. Aprobada. | Flujo navegable. | Implementado según inspección; edición de mínimo no encontrada. | `payment/account-actions/cardDates` JS; [detalle de tarjeta](../lib/features/accounts/presentation/accounts_screen.dart), formulario `toAccountId`, [test](../test/features/transactions/transaction_form_test.dart). Dos tarjetas y saldo a favor requieren V01; mínimo sin cálculo/edición nueva según P05. |
| F07 · Encontrar y corregir movimientos conservando origen. Aprobada; detalle contextual es diseño HTML. | Flujo navegable con revisión obsoleta en `save`; borrador anterior a restore rechazado en recorrido de dos pestañas. | Implementado según inspección. | [historial](../lib/features/transactions/presentation/transactions_screen.dart), [repositorio](../lib/features/transactions/data/ledger_repository.dart), [paginación](../test/features/transactions/history_pagination_test.dart), [edición](../test/features/management/basic_features_test.dart). HTML usa revision/localStorage; Flutter transacciones. Probar archivo/filtros/volver en Android (V01). |
| F08 · Reutilizar y corregir eliminaciones. Aprobada. | Flujo navegable; controles de conflicto en modelo. | Implementado según inspección. | `deleteTransaction/restoreTransaction` JS; [acciones](../lib/features/transactions/presentation/ledger_actions.dart), LedgerService y [test](../test/features/transactions/ledger_service_test.dart). Compra con devoluciones y deshacer concurrente requieren recorrido Android (V01). |
| F09 · Reflejar devolución parcial sin reescribir la compra. Aprobada. | Flujo navegable; reparto sucesivo probado en modelo. | Implementado según inspección. | `refund/refundable` JS; LedgerService y [regresiones](../test/features/management/basic_features_test.dart). Verificar categoría, límite, fecha y consumo neto en Android; cuotas futuras se conservan (V01). |
| F10 · Administrar cuentas, ahorro y alias sin perder historia. Aprobada; ficha/filtros de tipo son diseño HTML. | Flujo navegable; mínimo no editable. | Implementado según inspección; mínimo no editable en formularios revisados. | [AccountsService](../lib/features/accounts/data/accounts_service.dart), [cuentas](../lib/features/accounts/presentation/accounts_screen.dart), [ahorro](../test/features/dashboard/savings_overview_test.dart). Listado por tipo y ficha con alias/acciones/crédito trasladados; `approved_accounts_test` verifica 320/texto 2x y segunda tarjeta. Tipo/moneda/saldo inicial fijos; archivo excluye selección activa. Validar alias ambiguos/patrimonio (V01). |
| F11 · Corregir discrepancia de saldo con ajuste separado. Aprobada. | Flujo navegable; concurrencia ficticia. | Implementado según inspección. | Acción `reconcile` JS; AccountsService y [tests básicos](../test/features/management/basic_features_test.dart). Revalidación de saldo y deuda/saldo a favor requieren V01. |
| F12 · Reutilizar movimientos sin automatizar importes variables. Aprobada. | Flujo navegable; `saveWithTemplate` y formulario conjunto. | Implementado según inspección. | [servicio manual](../lib/features/templates/manual_template_service.dart), formulario y [tests](../test/features/templates/manual_template_service_test.dart). HTML ahora configura programación al guardar ambos; no prueba atomicidad SQLite. Verificar administración sin crear comercio/movimiento (V03). |
| F13 · Preparar gastos fijos pendientes sin asumir pago. Aprobada, opcional. | Flujo navegable simulado. | Implementado en servicio Flutter; Android pendiente. | [Motor](../lib/features/templates/scheduled_template_service.dart), [plantillas](../lib/features/templates/manual_template_service.dart) y pruebas dirigidas en [informe](evaluation/flutter-port-2026-10-07/REPORT.md). Al abrir/volver prepara hasta fin del mes siguiente, máximo 120 por plantilla; conserva huellas históricas y conflictos por revisar. No crea gasto real hasta confirmar. |
| F14 · Elegir captura Wallet y revocar acceso. Aprobada, normal. | Simulado. | Implementado según inspección. | [ajustes](../lib/features/settings/presentation/wallet_settings_screen.dart), [puente](../lib/core/notifications/native_notification_bridge.dart), [MainActivity](../android/app/src/main/kotlin/py/finanzaslocales/finanzas_locales/MainActivity.kt), [test](../test/features/notifications/wallet_settings_test.dart). Validar permiso real/denegación/regreso (V03). |
| F15 · Revisar compra nueva o ambigua antes de afectar saldo. Aprobada. | Flujo navegable sobre capturas ficticias. | Implementado según inspección. | [revisión](../lib/features/pending_inbox/presentation/candidate_review_dialog.dart), [ingestión](../lib/core/notifications/notification_ingestion_service.dart), [test](../test/features/notifications/candidate_review_dialog_test.dart). Cuenta obligatoria/alta, aprender alias y descartar sin borrar notificación requieren V03. |
| F16 · Ahorrar revisión de compras ya reconocidas. Aprobada, opt-in. | Simulado; `ingestWallet` valida unicidad, alias, categoría archivada, actualización y duplicados. | Implementado según inspección. | NotificationIngestionService, MerchantService, [tests de automatización](../test/features/notifications/wallet_automation_test.dart), [listener](../android/app/src/main/kotlin/py/finanzaslocales/finanzas_locales/WalletNotificationListenerService.kt). Tests JS no prueban paridad exhaustiva; payloads reales/segundo plano y coincidencia con programado requieren V03. |
| F17 · Presupuesto general/categoría y consulta mensual P02. Aprobada. | Flujo navegable con anillos. | Implementado y probado en host; Android pendiente. | [BudgetsScreen](../lib/features/budgets/presentation/budgets_screen.dart), [servicio](../lib/features/budgets/domain/budget_service.dart), [widgets](../test/features/budgets/approved_analysis_test.dart). Consulta conserva mes, alta solo mes actual, H01 corregido. Edición de nombre/objetivo y repetición opcional aprobadas e implementadas posteriormente; historial anterior conservado. Eliminación fuera de este bloque. |
| F18 · Comprender gastos por período y abrir su historial. Aprobada. | Flujo navegable, cinco vistas con libro ficticio. | Implementado según inspección. | [ReportService](../lib/features/reports/data/report_service.dart), [pantallas](../lib/features/reports/presentation/reports_screen.dart), [tests](../test/features/reports/report_analysis_test.dart). Filtros, ceros, bruto/devolución/neto y cuotas requieren contraste con cifras en teléfono (V01). |
| F19 · Mantener catálogos y resolver asociaciones. Aprobada. | Flujo navegable; reglas locales demostrativas. | Implementado según inspección. | [catálogo](../lib/features/catalog/catalog_screen.dart), [MerchantService](../lib/features/merchants/merchant_service.dart), [CategoryService](../lib/features/transactions/data/category_service.dart), [tests](../test/features/management/basic_screens_test.dart). Reasignaciones explícitas y archivados requieren V01/V03. |
| F20 · CSV/JSON retirados; preservar historia importada. Aprobada. | Retirados; backup conservado. | Retirada implementada; datos históricos conservados. | Eliminadas pantalla/ruta y exportadores; código de importación eliminado el 2026-10-10; [regresión de backup](../test/core/backup/backup_service_test.dart). Sin borrar tablas/huellas ni ampliar importación/reversión. |
| F21 · Recuperar todo sin perder datos ante error. Aprobada. | Simulado; copia de sesión y previa en memoria; sin cifrado/archivo. | Implementado según inspección. | [BackupService](../lib/core/backup/backup_service.dart), [codec](../lib/core/backup/backup_codec.dart), [tests](../test/core/backup/backup_service_test.dart). Esquema debe ser igual, validación de tablas/columnas/referencias, respaldo cifrado previo y rollback sin reinicio. Verificar SAF/recuperación en V02. |
| F22 · Proteger datos y entender su tratamiento. Bloqueo/cifrado aprobados; divulgación final pendiente. | Simulado; pantalla de privacidad de diseño; localStorage sin cifrar. | Implementado según inspección para bloqueo/cifrado; avisos Wallet/backup e información simplificada trasladados. | [AppLockGate](../lib/shared/widgets/app_lock_gate.dart), [almacenamiento](../lib/core/database/encrypted_storage.dart), [DeviceCrypto](../android/app/src/main/kotlin/py/finanzaslocales/finanzas_locales/DeviceCrypto.kt), [test](../test/core/security/app_lock_service_test.dart). Keystore/migración en V02 y información Wallet/backup en P04. |
| F23 · Diagnosticar detecciones con pruebas controladas. Aprobada solo desarrollo. | Simulado; escenario developer. | Implementado según inspección; SMS experimental. | [flags](../lib/core/config/feature_flags.dart), [Gradle](../android/app/build.gradle.kts), [herramientas](../lib/features/developer_tools), [test](../test/features/developer_tools/developer_tools_test.dart). Flutter/Android bloquean operaciones además del menú; probar binarios profile/release en V03. Escenario JS no prueba esa barrera. |
| F24 · Cuotas no crédito y pagos parciales. Aprobada en revisión posterior. | Flujo navegable ficticio. | Implementado; verificación host y revisión financiera en informe. | [Dominio](../lib/features/payments/domain/pending_payment_service.dart), [pantallas](../lib/features/payments/presentation/payments_screen.dart). Crear no descuenta; confirmar materializa pago real, carry conserva deuda y no inventa cuota siguiente. Validar instalación real/backup en Android. |
| F25 · Recordar vencimientos sin confirmar pagos. Aprobada; backups automáticos excluidos. | Ajustes y ejemplo simulados. | Puente y agenda Android implementados; entrega real sin verificar. | [Coordinador](../lib/core/notifications/payment_reminder_coordinator.dart), [receptor](../android/app/src/main/kotlin/py/finanzaslocales/finanzas_locales/PaymentReminderReceiver.kt). Tres días antes/09:00 y vencimiento editables; agenda cifrada, alarmas inexactas y tap solo abre obligación. Permisos, reinicio/OEM requieren Android. |

### Discrepancias resueltas y pendientes

- D01/P01: traslado solicitado explícitamente el 2026-10-07; experiencia implementada, revisión Android pendiente.
- D02/P05: primera fecha elegida y calendario mensual único sustituyen compras/cuotas; no se promete liquidación bancaria exacta.
- D03/P03: retirados CSV/JSON; historia y backup conservados.
- D04: referencias de seguridad anteriores siguen siendo históricas; claves/listener/SAF requieren Android.
- D05/H01: corregido truncamiento de presupuesto mediante `ReportService`; regresión activa sin omisiones confirma 51/50.
- CI-01: retirado solo build APK automático; workflow no ejecutado.

## Orden restante

V01 y V02 verificados el 2026-10-10; el bloqueo al abrir ya no se reproduce. Falta completar V03 (Wallet: ambiguo, actualizado, coincidencia con programado; barreras profile/release). Verificar V03 en Android con el APK preparado por el usuario y resolver únicamente incidencias reproducidas. No agregar publicación ni propuestas pendientes. La aprobación posterior de recordatorios en HTML no acredita su implementación Android. [Pasos mínimos](DEVELOPMENT.md#verificación-android-pendiente).

## Trabajo sobre capacidades ya aprobadas

La implementación autorizada no equivale a validación Android. Estos paquetes conservan sus criterios pendientes de comprobación real. Los recorridos detallados están en [DEVELOPMENT](DEVELOPMENT.md#verificación-android-pendiente).

| ID · fuente y prioridad propuesta | Problema, beneficio y alcance mínimo | Aceptación observable | Dependencias, riesgo, esfuerzo y HTML/Android |
| --- | --- | --- | --- |
| V01 · Libro y recorridos básicos. **Verificado en Android 2026-10-10 por el usuario (recorrido completo, sin incidencias; dispositivo/API sin registrar).** Base: funciones básicas autorizadas. | Contrastar F01–F11/F17–F19 con secuencia conocida; incluye archivo/alias, ediciones, cuotas, reportes y devoluciones. Excluye nuevas funciones y diseño. | Saldos/deuda/patrimonio y reportes coinciden con cálculo previo; pago/transferencia/ajuste no duplican gasto; edición y deshacer mantienen referencias y totales; incidencias quedan reproducibles. | Datos descartables y APK preparado por usuario. Riesgo de regresiones/concurrencia; esfuerzo medio. HTML sirve para comprender conceptos; no hace falta otro prototipo. Android debe verificar UI, persistencia y ciclo real. |
| V02 · Recuperación y seguridad. **Verificado en Android 2026-10-10 por el usuario (resultado «ok», sin incidencias; dispositivo/API sin registrar).** Base: cifrado/restauración aprobados. | F20–F22: backup portable, errores, restauración, actualización de base, bloqueo y pérdida de clave en instalación descartable. Excluye cloud, JSON restore y nuevas políticas de exportación. | Recuperación conserva datos/relaciones; contraseña/corrupción/esquema rechazados sin cambios; copia previa cifrada localizable; sin reinicio obligatorio; comportamiento ante clave perdida documentado sin prometer recuperación automática. | Backup probado antes de casos destructivos; SAF y Keystore dependen del dispositivo. Esfuerzo grande por matriz nativa. HTML simula mensajes y confirmación; no valida cifrado ni recuperación. |
| V03 · Wallet, programados y barreras de desarrollo. **Parcialmente verificado en Android 2026-10-10 por el usuario: recordatorios con app abierta, cerrada y tras reinicio; toque del aviso en arranque en frío (abre el detalle sin confirmar; destello de pantalla de error corregido el mismo día); Wallet real con comercio nuevo y compra repetida. Pendientes: caso ambiguo, notificación actualizada, coincidencia con programado y barreras profile/release.** Base/AGENTS: normales vs experimentales. Alta tras V01/V02: evitar duplicados. | F12–F16/F23, casos ambiguos, actualizados, fin de mes, atrasos y opt-in. Excluye otras fuentes normales, SMS de producción y tareas cerradas. | Reconocido único se registra una vez; ambiguo/actualizado/coincidente queda pendiente; vencimiento no se repite tras borrar; captura cerrada se procesa al volver; operaciones experimentales bloqueadas sin bandera y en profile/release. | Acceso consentido, payloads reales sanitizados, instalación de prueba. Riesgos OEM/formatos/duplicados; esfuerzo grande. HTML simula estados y comprensión; Android verifica listener, permisos, lifecycle y barreras nativas. |

## Iniciativas y decisiones vigentes

P01–P05 se aprobaron con los límites siguientes. La especificación y evidencia actual están en IMPLEMENTATION_PLAN para evitar duplicar matrices. El traslado fue solicitado explícitamente el 2026-10-07; falta la verificación Android.

### P01 · Trasladar el diseño aceptado

Cinco pestañas aprobadas, conservando Presupuestos y contexto. HTML trasladado a Flutter; cinco ramas conservan estado y contexto. No copiar motor JS. Prioridad media, esfuerzo grande para el traslado completo; dependencias V01–V03 y revisión de experiencia/accesibilidad.

### P02 · Consultar presupuestos de otros meses

Consulta anterior/siguiente, selección y retorno al actual; alta manual solo para mes actual. La revisión Android del 2026-10-07 autoriza edición y repetición opcional: cambiar ese mes y los siguientes de la misma serie, conservando anteriores. Flutter implementado; H01 corregido. Sin eliminación ni alta histórica nueva. Ver [ajustes y evidencia](IMPLEMENTATION_PLAN.md#ajustes-tras-revisión-android--2026-10-07). Validación Android de estos ajustes pendiente.

### P03 · Retirar CSV/JSON conservando historia

Sustituye la propuesta de mapeo/lotes/reversión. HTML y Flutter retirados; servicios internos históricos sin acceso de producto. Sin eliminación de tablas/metadatos ni migración destructiva. Backup cifrado/restauración conservados. Prioridad alta por simplificación aprobada, esfuerzo medio nativo; V01/V02 validan historia y recuperación.

### P04 · Información clara sobre Wallet y backups

Wallet opcional, acceso amplio Android explicado antes del permiso; automatización separada, revocación y carga manual claras. Contraseña portable/destino y límites de recuperación explicados. Advertencias CSV/JSON dejan de aplicar al retirarlos. HTML y Flutter actualizados; comprobaciones Android pendientes. Prioridad alta para consentimiento; esfuerzo medio, depende de V02/V03. Sin publicación ni certificación.

### P05 · Cuotas mensuales enlazadas, primera fecha elegible

Aprobación explícita del 2026-10-07 sustituye inicio obligatorio en mes de compra y selector de cálculo. HTML y Flutter implementados: primera fecha por defecto compra, día mensual con ajuste sin deriva, cuotas en movimientos/reportes/presupuestos y crédito completo desde compra. Calendarios históricos y mínimo manual conservados; sin extractos/intereses ni tareas cerrada. 40 pruebas JS correctas; detalle/evidencia en [plan](IMPLEMENTATION_PLAN.md#p05f05f18--cuotas-mensuales-enlazadas--2026-10-07). Implementación/compatibilidad probadas en host; Android pendiente. Prioridad alta por coherencia financiera; esfuerzo relativo medio para traslado, depende de V01/V02 y H01.

### P06 · Uso personal, sin versión pública requerida

No se prepara publicación ni se amplía producto para una primera versión. CI-01 aplicado: retirado build APK automático. La verificación Android sigue siendo necesaria para declarar integraciones verificadas.

## Propuestas sin aprobación

No ejecutadas en este encargo.

### P07 · Plazos e intereses de ahorro

- **Fuente/situación:** propuesta del usuario registrada en base, pendiente. Necesidad: separar ahorro disponible y proyección a plazo.
- **Estado:** HTML no representado para intereses/plazos; Flutter no encontrado en pantallas/servicio de cuentas revisados. Ahorro básico sí existe (F10).
- **Mínimo/exclusiones:** antes de diseñar definir tasa, período, capitalización, vencimiento y proyección vs interés real. Excluye productos bancarios, tasas descargadas y contabilización automática sin acuerdo.
- **Aceptación:** ejemplos aprobados distinguen saldo real/proyectado, vencimiento y crédito de interés; no se altera patrimonio real por una proyección.
- **Dependencias/riesgos:** definición de usuario, cuentas/reportes; riesgo de cifras engañosas. Prioridad baja hasta definir necesidad; esfuerzo grande si cambia modelo.
- **Validación:** HTML para comprensión de proyección; Android/pruebas financieras para cálculo, redondeo y persistencia.

### P08 · Recordatorios y backups periódicos

- **Situación:** aprobado el caso de cuotas y gastos pendientes generados por plantillas; backups periódicos siguen pendientes de definición/aprobación.
- **HTML:** ajustes editables y aviso de ejemplo; no entrega notificaciones reales. Estado nativo de esta ampliación no verificado en esta revisión, sin modificaciones Flutter/Android.
- **Regla aprobada:** por defecto tres días antes y el día de vencimiento a las 09:00, editable/desactivable. Abrir/descartar un aviso no paga; confirmación permite cuenta efectiva y pago parcial. Ver [base vigente](PRODUCT_BASELINE.md#prototipo-revisado-y-aceptado--2026-10-07).
- **Pendiente Android:** permisos concedidos/denegados/revocados, cierre/reinicio, reprogramación/cancelación al pagar o editar, duplicados, restricciones OEM y apertura del pago correcto. No acreditar entrega por una simulación HTML.
- **Backups:** frecuencia, destino, contraseña, errores, revocación y ejecución cerrada sin decidir. Sin Drive/cloud ni backup automático aprobado.

### P09 · Monedas adicionales y otras fuentes

- **Fuente/situación:** base puntos Monedas/Tarjetas virtuales; pendiente. Necesidad: interpretar compras de usuarios con otros formatos o monedas; falta confirmar casos concretos.
- **Estado:** HTML no representado salvo PYG/Wallet ficticio; Flutter parcial a nivel de tipos/campos, sin interfaz multimoneda completa ni conversiones encontradas. SMS permanece experimental.
- **Mínimo/exclusiones:** decidir por separado moneda necesaria e identificadores reales adicionales; primero recolectar ejemplos sanitizados. Excluye conversión implícita, tasas remotas, ampliar fuentes normales o convertir SMS en producción.
- **Aceptación:** casos aprobados tienen moneda/identificador inequívoco, no se suman monedas incompatibles y las ambigüedades exigen selección; fixtures más pruebas Android para cada fuente autorizada.
- **Dependencias/riesgos:** V01/V03/P04/P06, moneda contable y deduplicación; esfuerzo grande. Prioridad baja hasta evidencia de necesidad.
- **Validación:** HTML para selección y mensajes; Android para payloads reales, fuentes permitidas y reconocimiento. Sincronización no tiene necesidad/alcance aprobado: se mantiene fuera del roadmap ejecutable.

## Proceso para cualquier trabajo posterior

**Propuesta → aprobación de alcance → prototipo HTML cuando aporte valor → revisión y aprobación explícita del usuario → implementación Flutter → verificación Android.**

Para funciones nativas, puede revisarse una simulación de permisos/mensajes y omitir un nuevo HTML si no aporta valor; la revisión explícita de alcance/experiencia sigue siendo necesaria. Validar captura, claves, archivos y ciclo de vida requiere Android. Este proceso no invalida funciones Flutter existentes ni convierte código observado en decisión aprobada.

Cerrar una iniciativa exige registrar criterio cumplido, entorno y resultado, además de la aprobación que corresponda. Las prioridades y esta autoevaluación documental no equivalen a aceptación del usuario.

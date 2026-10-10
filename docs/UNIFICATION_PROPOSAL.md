# Propuesta: unificar cuotas, pendientes, recordatorios y plantillas

**Estado (2026-10-10): pasos 1–3 aprobados por el usuario («seguir con las propuestas del 1 al 3») e implementados y probados en host (Android pendiente); paso 4 sin cambios. Se omite un nuevo prototipo HTML por indicación expresa de continuar; sin APK ni migración de esquema.** Resultados y pruebas se registran en el [IMPLEMENTATION_PLAN](IMPLEMENTATION_PLAN.md).

## Contexto
Hoy hay tres mecanismos parecidos con puertas de entrada distintas:

| Mecanismo | Dónde vive | Efecto en saldo | Entrada en UI |
| --- | --- | --- | --- |
| Cuotas de tarjeta de crédito | `InstallmentPlans`/`InstallmentEntries` (`installment_service.dart:attachPlan`) | Deuda completa al comprar; cuotas son calendario «previsto» | Gasto + «Cuotas» con cuenta crédito |
| Pagos pendientes (no crédito) | JSON en `app_settings`, clave `pending_payment:v1:` (`pending_payment_service.dart:createPlan`) | Ninguno hasta pagar | Gasto + «Cuotas» con cuenta no crédito (mín. 2 en el formulario, `transaction_form_screen.dart:1053`) |
| Plantillas programadas | `RecurringTemplates` + `scheduled_template_service.dart:processDue` | Ninguno; crea un pendiente por vencimiento (`createPlan` con 1 cuota) | Diálogo «Guardar como plantilla» → «Preparar pagos pendientes» |

Hallazgos clave:
- `createPlan` ya acepta `installmentCount >= 1` (`pending_payment_service.dart:~210`) y las plantillas programadas ya crean pendientes de una sola cuota. Solo el formulario impide el pago pendiente único.
- Los recordatorios (`PaymentReminderFields`, `PaymentReminderSettings`, `payment_reminder_coordinator.dart`) ya son un componente aparte, reutilizable.
- Cuotas de crédito y pendientes **no** son lo mismo: en crédito el dinero ya se gastó (hay deuda); en pendiente aún no. Fusionar el almacenamiento arriesgaría saldos, reportes, backup y esquema v1.

## Recomendación
Unificar la **experiencia y los bloques compartidos**, no el almacenamiento. Cuatro pasos independientes, cada uno entregable y probable por separado.

1. **Pago pendiente único («pagar después»)**. En el formulario de gasto, separar dos ejes: *cuándo* (ahora / pendiente con fecha) y *cuotas* (1..120). Pendiente con 1 cuota usa `createPlan` tal cual, con `PaymentReminderFields`. Resuelve el ejemplo del internet «la semana que viene». Cambio mínimo: relajar la validación `_installmentCount < 2` solo en la rama pendiente y exponer fecha + recordatorio sin exigir cuotas.
2. **Una sola noción de calendario mensual**. `createPlan` y `InstallmentCalculator` calculan por separado el reparto del importe y el día ancla/clamp de fin de mes. Extraer un calculador común (reparto exacto entero + fecha ancla sin deriva) y que ambos lo usen; tests de regresión existentes (101→51/50, 33/33/35, día 31/febrero) deben pasar sin cambios.
3. **Plantilla programada = «Repetir» de un pendiente**. En vez de un flujo aparte, ofrecer «Repetir mensual/anual» al crear un pendiente; internamente sigue usando `RecurringTemplates` + `processDue`. La plantilla manual (reutilizar movimientos) queda separada y sin cambios.
4. **Cuotas de crédito**: mantener su modelo. Opcional futuro: recordatorio de fecha de pago de tarjeta, solo si lo pides (no está aprobado).

Fuera de alcance: migrar pendientes a tablas, tocar esquema Drift/backup, cambiar decisiones de `PRODUCT_BASELINE.md` sin aprobación explícita.

## Archivos críticos
- `lib/features/transactions/presentation/transaction_form_screen.dart` (switch de cuotas ~501, validación ~1053, `pendingPlan` ~1037, recordatorios ~599, plantilla ~741)
- `lib/features/payments/domain/pending_payment_service.dart` (`createPlan`)
- `lib/features/installments/domain/installment_calculator.dart` / `installment_service.dart`
- `lib/features/templates/scheduled_template_service.dart`, `manual_template_service.dart`
- `lib/features/payments/presentation/payment_reminder_fields.dart`

## Reglas del proyecto a respetar
- Sin subtítulos ni textos explicativos nuevos en la UI.
- No compilar APK; sí `flutter analyze` y `flutter test`.
- Documentar como **propuesta** en `docs/` hasta aprobación explícita; no tratarla como decisión asentada.

## Verificación
- `flutter analyze` limpio y `flutter test` (250 existentes) sin regresiones.
- Tests nuevos: pendiente único (crea 1 pendiente, no cambia saldo hasta pagar, recordatorio programado); calculador común con casos de redondeo y fin de mes; plantilla programada sigue sin duplicar vencimientos.
- Android (manual, usuario): crear «Internet» pendiente para la semana próxima con recordatorio; pagarlo; repetir mensual; comprobar que cuotas de tarjeta no cambian.

## Orden sugerido
Paso 1 primero (valor inmediato, riesgo bajo), luego 2 (refactor protegido por tests), luego 3 (cambio de UX) si el 1 resulta bien en el teléfono.

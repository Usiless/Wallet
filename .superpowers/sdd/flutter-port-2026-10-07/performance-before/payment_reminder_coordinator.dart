import '../../features/payments/domain/pending_payment_service.dart';
import 'payment_reminder_bridge.dart';
import 'payment_reminder_scheduler.dart';

/// The native agenda contains notifications only, never financial mutations.
Future<bool> synchronizePaymentReminders(
  PaymentReminderBridge bridge,
  List<PendingPayment> payments, {
  DateTime? now,
}) async {
  final inputs = <PaymentReminderInput>[];
  var invalidSettings = false;
  for (final payment in payments) {
    if (payment.cancelled || payment.remainingMinor <= 0) continue;
    try {
      final settings = payment.reminders;
      settings.validate();
      inputs.add(
        PaymentReminderInput(
          id: payment.id,
          revision: payment.revision,
          title: payment.description.isEmpty
              ? 'Pago pendiente'
              : payment.description,
          dueDate: payment.dueDate,
          enabled: settings.enabled,
          daysBefore: settings.daysBefore,
          hour: settings.hour,
          minute: settings.minute,
          onDueDate: settings.onDueDate,
        ),
      );
    } on FormatException {
      // Legacy unsupported settings cannot retain another obligation's stale alarm.
      invalidSettings = true;
    }
  }
  // Native storage needs historical identities to preserve displayed notices;
  // only future requests become alarms, and newly introduced past ones are skipped.
  final requests = const PaymentReminderScheduler().schedule(
    inputs,
    now: now ?? DateTime.now(),
    retainElapsed: true,
  );
  final permitted = await bridge.reconcile(requests);
  return permitted && !invalidSettings;
}

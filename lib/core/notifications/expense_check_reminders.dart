import 'payment_reminder_bridge.dart';

const expenseCheckObligationId = 'expense-check';

final class ExpenseCheckSettings {
  const ExpenseCheckSettings({
    this.enabled = false,
    this.hour = 21,
    this.minute = 0,
  });
  final bool enabled;
  final int hour, minute;

  ExpenseCheckSettings copyWith({bool? enabled, int? hour, int? minute}) =>
      ExpenseCheckSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );
}

/// Daily «did you log your expenses?» notices for the native agenda.
/// Today's notice is kept even after its time so a shown notice keeps its
/// identity; it is dropped once a manual movement was registered today.
List<PaymentReminderRequest> expenseCheckReminders(
  ExpenseCheckSettings settings, {
  required DateTime now,
  required bool registeredToday,
  int days = 60,
}) {
  if (!settings.enabled) return const [];
  final first = registeredToday ? 1 : 0;
  return [
    for (var offset = first; offset < days; offset++)
      _request(
        DateTime(
          now.year,
          now.month,
          now.day + offset,
          settings.hour,
          settings.minute,
        ),
      ),
  ];
}

PaymentReminderRequest _request(DateTime at) => PaymentReminderRequest(
  id: '$expenseCheckObligationId:${at.toIso8601String()}',
  obligationId: expenseCheckObligationId,
  title: '¿Ya cargaste tus gastos de hoy?',
  body: '',
  localDateTime: at,
  channel: 'expense',
);

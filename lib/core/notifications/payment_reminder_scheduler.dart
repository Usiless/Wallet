import 'payment_reminder_bridge.dart';

final class PaymentReminderInput {
  const PaymentReminderInput({
    required this.id,
    required this.title,
    required this.dueDate,
    this.revision,
    this.enabled = true,
    this.onDueDate = true,
    this.daysBefore = 3,
    this.hour = 9,
    this.minute = 0,
  });
  final String id, title;
  final DateTime dueDate;
  final int? revision;
  final bool enabled, onDueDate;
  final int daysBefore, hour, minute;
}

final class PaymentReminderScheduler {
  const PaymentReminderScheduler();
  List<PaymentReminderRequest> schedule(
    Iterable<PaymentReminderInput> inputs, {
    required DateTime now,
    bool retainElapsed = false,
  }) {
    final result = <PaymentReminderRequest>[];
    final seen = <String>{};
    for (final input in inputs) {
      if (input.daysBefore < 0 ||
          input.daysBefore > 60 ||
          input.hour < 0 ||
          input.hour > 23 ||
          input.minute < 0 ||
          input.minute > 59 ||
          input.id.isEmpty ||
          !seen.add(input.id)) {
        throw ArgumentError('Configuración de recordatorio inválida.');
      }
      if (!input.enabled) continue;
      for (final offset in {input.daysBefore, if (input.onDueDate) 0}) {
        final date = DateTime(
          input.dueDate.year,
          input.dueDate.month,
          input.dueDate.day - offset,
          input.hour,
          input.minute,
        );
        if (!retainElapsed && !date.isAfter(now)) continue;
        result.add(
          PaymentReminderRequest(
            id: '${input.id}:${date.toIso8601String()}',
            obligationId: input.id,
            title: input.title,
            body: 'Revisar pago',
            localDateTime: date,
            revision: input.revision,
          ),
        );
      }
    }
    result.sort((a, b) => a.localDateTime.compareTo(b.localDateTime));
    return result;
  }
}

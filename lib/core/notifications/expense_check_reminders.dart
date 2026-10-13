import 'payment_reminder_bridge.dart';

const expenseCheckObligationId = 'expense-check';

/// Repeat intervals offered besides the single daily notice (0).
const expenseCheckIntervals = [1, 2, 3, 4, 6, 8, 12];

/// Keeps short intervals from flooding the native agenda, which re-arms its
/// alarms on every sync; the horizon is renewed whenever the app opens.
const _maxRequests = 240;

final class ExpenseCheckSettings {
  const ExpenseCheckSettings({
    this.enabled = false,
    this.hour = 21,
    this.minute = 0,
    this.everyHours = 0,
    this.untilHour = 22,
    this.untilMinute = 0,
  });
  final bool enabled;

  /// First notice of the day; the only one when [everyHours] is 0.
  final int hour, minute;

  /// Repeats from [hour]:[minute] up to [untilHour]:[untilMinute].
  final int everyHours;
  final int untilHour, untilMinute;

  ExpenseCheckSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    int? everyHours,
    int? untilHour,
    int? untilMinute,
  }) => ExpenseCheckSettings(
    enabled: enabled ?? this.enabled,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    everyHours: everyHours ?? this.everyHours,
    untilHour: untilHour ?? this.untilHour,
    untilMinute: untilMinute ?? this.untilMinute,
  );
}

/// «Did you log your expenses?» notices for the native agenda.
/// Today's notices are kept even after their time so a shown notice keeps its
/// identity. A manual movement registered at [lastManualToday] silences the
/// rest of the day, or with a repeat interval, the notices inside it.
List<PaymentReminderRequest> expenseCheckReminders(
  ExpenseCheckSettings settings, {
  required DateTime now,
  DateTime? lastManualToday,
  int days = 60,
}) {
  if (!settings.enabled) return const [];
  final every = Duration(hours: settings.everyHours);
  bool silenced(DateTime at) {
    final last = lastManualToday;
    if (last == null || !_sameDay(at, last)) return false;
    return settings.everyHours == 0 || at.difference(last) < every;
  }

  return [
    for (var offset = 0; offset < days; offset++)
      for (final at in _daySlots(settings, now, offset))
        if (!silenced(at)) _request(at),
  ].take(_maxRequests).toList();
}

Iterable<DateTime> _daySlots(
  ExpenseCheckSettings settings,
  DateTime now,
  int offset,
) sync* {
  DateTime at(int hour, int minute) =>
      DateTime(now.year, now.month, now.day + offset, hour, minute);
  yield at(settings.hour, settings.minute);
  if (settings.everyHours == 0) return;
  final until = settings.untilHour * 60 + settings.untilMinute;
  // Wall-clock times, so a DST change does not shift the schedule.
  for (
    var hour = settings.hour + settings.everyHours;
    hour * 60 + settings.minute <= until;
    hour += settings.everyHours
  ) {
    yield at(hour, settings.minute);
  }
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

PaymentReminderRequest _request(DateTime at) => PaymentReminderRequest(
  id: '$expenseCheckObligationId:${at.toIso8601String()}',
  obligationId: expenseCheckObligationId,
  title: '¿Ya cargaste tus gastos de hoy?',
  body: '',
  localDateTime: at,
  channel: 'expense',
);

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../settings/settings_repository.dart';
import 'expense_check_reminders.dart';

const expenseCheckEnabledKey = 'expense_check_enabled';
const expenseCheckTimeKey = 'expense_check_time';
const expenseCheckEveryKey = 'expense_check_every';
const expenseCheckUntilKey = 'expense_check_until';

Future<ExpenseCheckSettings> readExpenseCheckSettings(
  SettingsRepository settings,
) async {
  const defaults = ExpenseCheckSettings();
  final time = _parseTime(await settings.read(expenseCheckTimeKey));
  final until = _parseTime(await settings.read(expenseCheckUntilKey));
  final every = int.tryParse(await settings.read(expenseCheckEveryKey) ?? '');
  return ExpenseCheckSettings(
    enabled: await settings.readBool(expenseCheckEnabledKey),
    hour: time?.$1 ?? defaults.hour,
    minute: time?.$2 ?? defaults.minute,
    everyHours: expenseCheckIntervals.contains(every)
        ? every!
        : defaults.everyHours,
    untilHour: until?.$1 ?? defaults.untilHour,
    untilMinute: until?.$2 ?? defaults.untilMinute,
  );
}

(int, int)? _parseTime(String? value) {
  final parts = value?.split(':');
  if (parts == null || parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
  return (hour, minute);
}

String _formatTime(int hour, int minute) =>
    '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

Stream<ExpenseCheckSettings> watchExpenseCheckSettings(
  SettingsRepository settings,
) {
  final database = settings.database;
  return (database.select(database.appSettings)..where(
        (t) => t.key.isIn([
          expenseCheckEnabledKey,
          expenseCheckTimeKey,
          expenseCheckEveryKey,
          expenseCheckUntilKey,
        ]),
      ))
      .watch()
      .asyncMap((_) => readExpenseCheckSettings(settings));
}

Future<void> writeExpenseCheckSettings(
  SettingsRepository settings,
  ExpenseCheckSettings value,
) async {
  await settings.write(
    expenseCheckTimeKey,
    _formatTime(value.hour, value.minute),
  );
  await settings.write(expenseCheckEveryKey, '${value.everyHours}');
  await settings.write(
    expenseCheckUntilKey,
    _formatTime(value.untilHour, value.untilMinute),
  );
  await settings.write(expenseCheckEnabledKey, '${value.enabled}');
}

/// When the user last registered a manual movement on [day]'s local date.
Future<DateTime?> lastManualTransactionCreatedOn(
  AppDatabase database,
  DateTime day,
) => _lastManualCreatedOn(database, day).get().then(_createdAt);

Stream<DateTime?> watchLastManualTransactionCreatedOn(
  AppDatabase database,
  DateTime day,
) => _lastManualCreatedOn(database, day).watch().map(_createdAt);

DateTime? _createdAt(List<TransactionRecord> rows) =>
    rows.isEmpty ? null : rows.single.createdAt.toLocal();

SimpleSelectStatement<$LedgerTransactionsTable, TransactionRecord>
_lastManualCreatedOn(AppDatabase database, DateTime day) {
  final start = DateTime(day.year, day.month, day.day).toUtc();
  final end = DateTime(day.year, day.month, day.day + 1).toUtc();
  return database.select(database.ledgerTransactions)
    ..where(
      (t) =>
          t.source.equals('manual') &
          t.createdAt.isBiggerOrEqualValue(start) &
          t.createdAt.isSmallerThanValue(end),
    )
    ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
    ..limit(1);
}

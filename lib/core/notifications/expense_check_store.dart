import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../settings/settings_repository.dart';
import 'expense_check_reminders.dart';

const expenseCheckEnabledKey = 'expense_check_enabled';
const expenseCheckTimeKey = 'expense_check_time';

Future<ExpenseCheckSettings> readExpenseCheckSettings(
  SettingsRepository settings,
) async {
  const defaults = ExpenseCheckSettings();
  final time = (await settings.read(expenseCheckTimeKey))?.split(':');
  final hour = time?.length == 2 ? int.tryParse(time![0]) : null;
  final minute = time?.length == 2 ? int.tryParse(time![1]) : null;
  final valid =
      hour != null &&
      minute != null &&
      hour >= 0 &&
      hour <= 23 &&
      minute >= 0 &&
      minute <= 59;
  return ExpenseCheckSettings(
    enabled: await settings.readBool(expenseCheckEnabledKey),
    hour: valid ? hour : defaults.hour,
    minute: valid ? minute : defaults.minute,
  );
}

Stream<ExpenseCheckSettings> watchExpenseCheckSettings(
  SettingsRepository settings,
) {
  final database = settings.database;
  return (database.select(database.appSettings)..where(
        (t) => t.key.isIn([expenseCheckEnabledKey, expenseCheckTimeKey]),
      ))
      .watch()
      .asyncMap((_) => readExpenseCheckSettings(settings));
}

Future<void> writeExpenseCheckSettings(
  SettingsRepository settings,
  ExpenseCheckSettings value,
) async {
  final hh = value.hour.toString().padLeft(2, '0');
  final mm = value.minute.toString().padLeft(2, '0');
  await settings.write(expenseCheckTimeKey, '$hh:$mm');
  await settings.write(expenseCheckEnabledKey, '${value.enabled}');
}

/// Whether the user registered a manual movement on [day]'s local date.
Future<bool> hasManualTransactionCreatedOn(
  AppDatabase database,
  DateTime day,
) => _manualCreatedOn(database, day).get().then((rows) => rows.isNotEmpty);

Stream<bool> watchManualTransactionCreatedOn(
  AppDatabase database,
  DateTime day,
) => _manualCreatedOn(database, day).watch().map((rows) => rows.isNotEmpty);

SimpleSelectStatement<$LedgerTransactionsTable, TransactionRecord>
_manualCreatedOn(AppDatabase database, DateTime day) {
  final start = DateTime(day.year, day.month, day.day).toUtc();
  final end = DateTime(day.year, day.month, day.day + 1).toUtc();
  return database.select(database.ledgerTransactions)
    ..where(
      (t) =>
          t.source.equals('manual') &
          t.createdAt.isBiggerOrEqualValue(start) &
          t.createdAt.isSmallerThanValue(end),
    )
    ..limit(1);
}

import 'package:drift/native.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/notifications/expense_check_reminders.dart';
import 'package:finanzas_locales/core/notifications/expense_check_store.dart';
import 'package:finanzas_locales/core/notifications/payment_reminder_coordinator.dart';
import 'package:finanzas_locales/core/notifications/payment_reminder_bridge.dart';
import 'package:finanzas_locales/core/settings/settings_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const on = ExpenseCheckSettings(enabled: true, hour: 21, minute: 30);

  group('expenseCheckReminders', () {
    test('desactivado no programa nada', () {
      expect(
        expenseCheckReminders(
          const ExpenseCheckSettings(),
          now: DateTime(2026, 10, 13, 10),
          registeredToday: false,
        ),
        isEmpty,
      );
    });

    test('60 días a la hora elegida, incluido hoy aunque ya haya pasado', () {
      final result = expenseCheckReminders(
        on,
        now: DateTime(2026, 10, 13, 23),
        registeredToday: false,
      );
      expect(result, hasLength(60));
      expect(result.first.localDateTime, DateTime(2026, 10, 13, 21, 30));
      expect(result.last.localDateTime, DateTime(2026, 12, 11, 21, 30));
      expect(result.map((r) => r.id).toSet(), hasLength(60));
      expect(
        result.every(
          (r) =>
              r.obligationId == expenseCheckObligationId &&
              r.channel == 'expense',
        ),
        isTrue,
      );
    });

    test('con un registro manual hoy arranca mañana', () {
      final result = expenseCheckReminders(
        on,
        now: DateTime(2026, 10, 31, 8),
        registeredToday: true,
      );
      expect(result.first.localDateTime, DateTime(2026, 11, 1, 21, 30));
      expect(result, hasLength(59));
    });

    test('cambiar la hora cambia la identidad de cada aviso', () {
      final now = DateTime(2026, 10, 13);
      final a = expenseCheckReminders(on, now: now, registeredToday: false);
      final b = expenseCheckReminders(
        on.copyWith(hour: 20),
        now: now,
        registeredToday: false,
      );
      expect(a.first.id, isNot(b.first.id));
    });
  });

  group('almacenamiento', () {
    late AppDatabase db;
    late SettingsRepository settings;
    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      settings = SettingsRepository(db);
    });
    tearDown(() => db.close());

    test('desactivado a las 21:00 por defecto y guarda la hora', () async {
      final initial = await readExpenseCheckSettings(settings);
      expect(initial.enabled, isFalse);
      expect((initial.hour, initial.minute), (21, 0));
      await writeExpenseCheckSettings(settings, on.copyWith(minute: 5));
      expect(await settings.read(expenseCheckTimeKey), '21:05');
      final saved = await readExpenseCheckSettings(settings);
      expect((saved.enabled, saved.hour, saved.minute), (true, 21, 5));
      await settings.write(expenseCheckTimeKey, '25:00');
      expect((await readExpenseCheckSettings(settings)).hour, 21);
    });

    Future<void> insert(String id, String source, DateTime createdAt) => db
        .into(db.ledgerTransactions)
        .insert(
          LedgerTransactionsCompanion.insert(
            id: id,
            type: 'expense',
            status: 'confirmed',
            source: source,
            occurredAt: createdAt.toUtc(),
            createdAt: createdAt.toUtc(),
            updatedAt: createdAt.toUtc(),
            currencyCode: 'PYG',
            amountMinor: 1000,
          ),
        );

    test('solo un movimiento manual creado hoy cuenta', () async {
      final today = DateTime(2026, 10, 13, 12);
      await insert('ayer', 'manual', DateTime(2026, 10, 12, 23, 59));
      await insert('programado', 'recurring', today);
      await insert('wallet', 'googleWalletNotification', today);
      expect(await hasManualTransactionCreatedOn(db, today), isFalse);
      await insert('manual', 'manual', DateTime(2026, 10, 13, 0, 1));
      expect(await hasManualTransactionCreatedOn(db, today), isTrue);
      expect(
        await hasManualTransactionCreatedOn(db, DateTime(2026, 10, 14)),
        isFalse,
      );
    });
  });

  test('el coordinador envía pagos y aviso diario juntos', () async {
    const channel = MethodChannel('test/expense_check');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    final sent = <List<Object?>>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      sent.add((call.arguments as Map)['requests'] as List<Object?>);
      return true;
    });
    const bridge = PaymentReminderBridge(channel: channel);
    final coordinator = PaymentReminderCoordinator();
    final now = DateTime(2026, 10, 13, 10);
    List<PaymentReminderRequest> daily(bool registered) =>
        expenseCheckReminders(on, now: now, registeredToday: registered);

    await coordinator.synchronize(bridge, [], now: now, extra: daily(false));
    expect(sent.single, hasLength(60));
    expect((sent.single.first as Map)['channel'], 'expense');
    await coordinator.synchronize(bridge, [], now: now, extra: daily(false));
    expect(sent, hasLength(1));
    await coordinator.synchronize(bridge, [], now: now, extra: daily(true));
    expect(sent, hasLength(2));
    expect(sent.last, hasLength(59));
  });
}

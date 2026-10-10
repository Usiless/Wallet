import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/notifications/notification_envelope.dart';
import 'package:finanzas_locales/core/notifications/notification_ingestion_service.dart';
import 'package:finanzas_locales/core/settings/settings_repository.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/merchants/merchant_service.dart';
import 'package:finanzas_locales/features/templates/manual_template_service.dart';
import 'package:finanzas_locales/features/templates/scheduled_template_service.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_locales/features/payments/domain/pending_payment_service.dart';

void main() {
  late AppDatabase db;
  late ManualTemplateService templates;
  late ScheduledTemplateService scheduler;
  late String account;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    templates = ManualTemplateService(db);
    scheduler = ScheduledTemplateService(db);
    account = await AccountsService(db).createAccount(
      const CreateAccountDraft(
        name: 'Banco',
        type: AccountType.bank,
        aliases: ['1234'],
      ),
    );
  });
  tearDown(() => db.close());
  Future<String> create({
    String date = '2026-10-04',
    String frequency = 'monthly',
    String? merchantId,
    String channel = 'onlineCard',
  }) => templates.save('Netflix', {
    'type': 'expense',
    'amountMinor': 10000,
    'from': account,
    'merchant': 'NETFLIX',
    'merchantId': merchantId,
    'channel': channel,
    'schedule': {
      'enabled': true,
      'frequency': frequency,
      'nextDate': date,
      'anchorDay': parseScheduledDate(date).day,
      'anchorMonth': parseScheduledDate(date).month,
    },
  });
  NotificationIngestionService notificationService() =>
      NotificationIngestionService(
        db,
        LedgerService(db),
        settings: SettingsRepository(db),
      );
  NotificationEnvelope notification(String key) => NotificationEnvelope(
    version: 1,
    packageName: 'com.google.android.apps.walletnfcrel',
    notificationKey: key,
    id: 1,
    postTime: DateTime(2026, 10, 4, 16),
    title: 'NETFLIX',
    text: 'PYG10000 · ••1234',
  );

  test('recupera meses vencidos, conserva día 31 y es idempotente concurrentemente', () async {
    final id = await create(date: '2026-01-31');
    await Future.wait([
      scheduler.processDue(now: DateTime(2026, 4, 1)),
      scheduler.processDue(now: DateTime(2026, 4, 1)),
    ]);
    final rows = await PendingPaymentService(db).list();
    expect(rows, hasLength(5));
    expect(
      rows.map((r) => r.sourceReference),
      containsAll([
        'scheduled:$id:2026-01-31',
        'scheduled:$id:2026-02-28',
        'scheduled:$id:2026-03-31',
      ]),
    );
    expect(
      ((await templates.read(id))!.fields['schedule'] as Map)['nextDate'],
      '2026-06-30',
    );
    expect(await db.select(db.ledgerTransactions).get(), isEmpty);
    await PendingPaymentService(db).cancel(rows.first.id, expectedRevision: 0);
    final template = (await templates.read(id))!;
    final fields = Map<String, dynamic>.from(template.fields);
    fields['schedule'] = {
      ...fields['schedule'] as Map,
      'nextDate': '2026-01-31',
    };
    await templates.save(template.name, fields, id: id);
    expect(
      (await scheduler.processDue(now: DateTime(2026, 4, 1))).registered,
      isEmpty,
    );
    expect(await PendingPaymentService(db).list(), hasLength(5));
  });
  test('anual conserva 29 de febrero y ajusta años no bisiestos', () async {
    final id = await create(date: '2024-02-29', frequency: 'yearly');
    await scheduler.processDue(now: DateTime(2026, 2, 28));
    final rows = await PendingPaymentService(db).list();
    expect(
      rows.map((r) => r.sourceReference),
      containsAll([
        'scheduled:$id:2024-02-29',
        'scheduled:$id:2025-02-28',
        'scheduled:$id:2026-02-28',
      ]),
    );
    expect(
      nextScheduledDate(DateTime(2027, 2, 28), {
        'frequency': 'yearly',
        'anchorDay': 29,
        'anchorMonth': 2,
      }),
      DateTime(2028, 2, 29),
    );
  });
  test('pausar no crea movimientos ni avanza próxima fecha', () async {
    final id = await create();
    await scheduler.pause(id);
    expect(
      (await scheduler.processDue(now: DateTime(2026, 10, 5))).registered,
      isEmpty,
    );
    expect(
      ((await templates.read(id))!.fields['schedule'] as Map)['nextDate'],
      '2026-10-04',
    );
  });
  test(
    'cuenta archivada queda pendiente y omitir avanza sin registrar',
    () async {
      final id = await create();
      await (db.update(db.accounts)..where((a) => a.id.equals(account))).write(
        const AccountsCompanion(isArchived: Value(true)),
      );
      final result = await scheduler.processDue(now: DateTime(2026, 10, 5));
      expect(result.pending, ['Netflix']);
      expect(await db.select(db.ledgerTransactions).get(), isEmpty);
      expect(await db.select(db.merchants).get(), isEmpty);
      await scheduler.skipPending(id);
      expect(
        ((await templates.read(id))!.fields['schedule'] as Map)['nextDate'],
        '2026-11-04',
      );
    },
  );
  test('fallo de canal revierte creación del comercio y deja la plantilla pendiente', () async {
    await create(channel: 'cash');
    expect((await scheduler.processDue(now: DateTime(2026, 10, 5))).pending, [
      'Netflix',
    ]);
    expect(await db.select(db.merchants).get(), isEmpty);
    expect(await db.select(db.accountPostings).get(), isEmpty);
    expect(await db.select(db.ledgerTransactions).get(), isEmpty);
  });
  test('Wallet después de registro programado exige revisión, aun con automatización', () async {
    final merchant = await MerchantService(db).findOrCreate('NETFLIX');
    await create(merchantId: merchant);
    await scheduler.processDue(now: DateTime(2026, 10, 4));
    await SettingsRepository(db).write('wallet_auto_register', 'true');
    await SettingsRepository(db).write('notification_listener_enabled', 'true');
    final candidate = (await notificationService().process(
      notification('later'),
    ))!;
    expect(candidate.status, 'pending');
    expect(candidate.suggestionReason, contains('registro programado'));
    expect(await db.select(db.ledgerTransactions).get(), isEmpty);
  });
  test('notificación pendiente previa impide registrar la plantilla', () async {
    await create();
    await notificationService().process(notification('pending'));
    expect((await scheduler.processDue(now: DateTime(2026, 10, 4))).pending, [
      'Netflix',
    ]);
    expect(await db.select(db.ledgerTransactions).get(), isEmpty);
  });
  test(
    'compra Wallet confirmada previa impide duplicación programada',
    () async {
      await MerchantService(db).findOrCreate('NETFLIX');
      await create();
      final service = notificationService();
      final candidate = (await service.process(notification('confirmed')))!;
      await service.confirm(candidate, fromAccountId: account);
      expect((await scheduler.processDue(now: DateTime(2026, 10, 4))).pending, [
        'Netflix',
      ]);
      expect(await db.select(db.ledgerTransactions).get(), hasLength(1));
    },
  );
  test('template reminder changes update only unpaid future obligations and invalidate revision', () async {
    final today = DateTime.now();
    final date = scheduledDate(DateTime(today.year, today.month, today.day));
    final id = await create(date: date);
    await scheduler.processDue(now: today);
    final service = PendingPaymentService(db);
    final initial = await service.list();
    final first = initial.first;
    await service.pay(
      id: first.id,
      expectedRevision: first.revision,
      amountMinor: 10000,
      paidAt: today,
      accountId: account,
    );
    final template = (await templates.read(id))!;
    await templates.save(template.name, {
      ...template.fields,
      'reminders': const PaymentReminderSettings(
        daysBefore: 7,
        hour: 8,
      ).toJson(),
    }, id: id);
    final after = await service.list();
    expect(after.first.reminders.daysBefore, 3);
    expect(after.last.reminders.daysBefore, 7);
    expect(after.last.revision, 1);
    await expectLater(
      templates.save(template.name, {
        ...template.fields,
        'from': 'missing',
        'amountMinor': 20000,
      }, id: id),
      throwsStateError,
    );
    expect((await service.read(after.last.id))!.accountId, account);
  });
}

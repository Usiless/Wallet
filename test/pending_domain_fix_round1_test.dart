import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:finanzas_locales/core/backup/backup_service.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/errors/app_exception.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/payments/domain/pending_payment_service.dart';
import 'package:finanzas_locales/features/templates/manual_template_service.dart';
import 'package:finanzas_locales/features/templates/scheduled_template_service.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late PendingPaymentService payments;
  late String bank;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    payments = PendingPaymentService(db);
    bank = await AccountsService(db).createAccount(
      const CreateAccountDraft(name: 'Banco', type: AccountType.bank),
    );
    final now = DateTime.now();
    for (final id in ['a', 'b', 'c', 'd']) {
      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              id: id,
              name: id,
              kind: 'expense',
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
  });
  tearDown(() => db.close());

  test(
    'following edit preserves partly paid later installments and their ledger',
    () async {
      final plan = await payments.createPlan(
        amountMinor: 300,
        installmentCount: 3,
        firstDueDate: DateTime(2026, 10, 1),
        accountId: bank,
      );
      final tx = await payments.pay(
        id: plan[1].id,
        expectedRevision: 0,
        amountMinor: 80,
        paidAt: DateTime(2026, 11, 1),
        accountId: bank,
      );
      final ledgerBefore = await (db.select(
        db.ledgerTransactions,
      )..where((t) => t.id.equals(tx))).getSingle();
      await payments.edit(
        id: plan.first.id,
        expectedRevision: 0,
        amountMinor: 50,
        dueDate: plan.first.dueDate,
        following: true,
      );
      final after = await payments.list();
      expect(after.map((p) => p.amountMinor), [50, 100, 50]);
      expect(after.map((p) => p.remainingMinor), [50, 20, 50]);
      expect(after[1].paidMinor, 80);
      expect(after[1].revision, 1);
      expect(
        await (db.select(
          db.ledgerTransactions,
        )..where((t) => t.id.equals(tx))).getSingle(),
        ledgerBefore,
      );
      expect(await db.select(db.ledgerTransactions).get(), hasLength(1));
    },
  );

  test('four category installments conserve every row and column without negative splits', () async {
    final plan = await payments.createPlan(
      amountMinor: 10,
      installmentCount: 2,
      firstDueDate: DateTime(2026, 10, 1),
      accountId: bank,
      splits: const [
        SplitDraft(categoryId: 'a', amountMinor: 3),
        SplitDraft(categoryId: 'b', amountMinor: 3),
        SplitDraft(categoryId: 'c', amountMinor: 3),
        SplitDraft(categoryId: 'd', amountMinor: 1),
      ],
    );
    for (final p in plan) {
      expect(p.splits.every((s) => s.amountMinor >= 0), isTrue);
      expect(p.splits.fold<int>(0, (n, s) => n + s.amountMinor), 5);
      await payments.pay(
        id: p.id,
        expectedRevision: 0,
        amountMinor: 5,
        paidAt: DateTime(2026, 10, 1),
        accountId: bank,
      );
    }
    final paid = <String, int>{};
    for (final s in await db.select(db.transactionSplits).get()) {
      paid[s.categoryId] = (paid[s.categoryId] ?? 0) + s.amountMinor;
    }
    expect(paid, {'a': 3, 'b': 3, 'c': 3, 'd': 1});
  });

  test('carried debt bounds edit and keeps exact transferred categories at equality', () async {
    final plan = await payments.createPlan(
      amountMinor: 200,
      installmentCount: 2,
      firstDueDate: DateTime(2026, 10, 1),
      accountId: bank,
      splits: const [
        SplitDraft(categoryId: 'a', amountMinor: 120),
        SplitDraft(categoryId: 'b', amountMinor: 80),
      ],
    );
    final p = plan.first;
    final tx = await payments.pay(
      id: p.id,
      expectedRevision: 0,
      amountMinor: 40,
      paidAt: DateTime(2026, 10, 1),
      accountId: bank,
      carryRemainder: true,
    );
    await LedgerService(db).softDelete(tx);
    final reopened = (await payments.read(p.id))!;
    await expectLater(
      payments.edit(
        id: p.id,
        expectedRevision: reopened.revision,
        amountMinor: 50,
        dueDate: p.dueDate,
      ),
      throwsFormatException,
    );
    expect((await payments.read(p.id))!.remainingMinor, 40);
    await payments.edit(
      id: p.id,
      expectedRevision: reopened.revision,
      amountMinor: 60,
      dueDate: p.dueDate,
    );
    final edited = (await payments.read(p.id))!;
    expect(edited.remainingMinor, 0);
    expect(
      {for (final s in edited.splits) s.categoryId: s.amountMinor},
      {'a': 36, 'b': 24},
    );
    expect(edited.remainingSplits, isEmpty);
    final dir = await Directory.systemTemp.createTemp('carry-edit-');
    addTearDown(() => dir.delete(recursive: true));
    final backup = BackupService(db, directory: dir);
    await backup.restore(await backup.createBytes('password'), 'password');
    expect((await payments.read(p.id))!.remainingMinor, 0);
  });

  for (final yearly in [false, true]) {
    test(
      'user calendar ${yearly ? 'yearly switch' : 'date change'} supersedes only unpaid future occurrences',
      () async {
        final today = DateTime.now();
        final due = DateTime(today.year, today.month, 10);
        final templates = ManualTemplateService(db);
        final scheduler = ScheduledTemplateService(db);
        final id = await templates.save('Servicio', {
          'type': 'expense',
          'amountMinor': 100,
          'from': bank,
          'channel': 'other',
          'schedule': {
            'enabled': true,
            'frequency': 'monthly',
            'nextDate': scheduledDate(due),
            'anchorDay': 10,
            'anchorMonth': due.month,
          },
        });
        await scheduler.processDue(now: DateTime(today.year, today.month, 1));
        final prepared = await payments.list();
        expect(prepared, hasLength(2));
        await payments.pay(
          id: prepared.first.id,
          expectedRevision: 0,
          amountMinor: 100,
          paidAt: due,
          accountId: bank,
        );
        final saved = (await templates.read(id))!;
        final newDue = DateTime(today.year, today.month + 1, 20);
        await templates.save(saved.name, {
          ...saved.fields,
          'schedule': {
            ...saved.fields['schedule'] as Map,
            'nextDate': scheduledDate(newDue),
            'frequency': yearly ? 'yearly' : 'monthly',
            'anchorDay': 20,
            'anchorMonth': newDue.month,
          },
        }, id: id);
        await scheduler.processDue(now: DateTime(today.year, today.month, 1));
        await scheduler.processDue(now: DateTime(today.year, today.month, 1));
        final after = await payments.list();
        expect(after.where((p) => p.remainingMinor > 0).map((p) => p.dueDate), [
          newDue,
        ]);
        expect((await payments.read(prepared.first.id))!.paidMinor, 100);
        expect(await db.select(db.ledgerTransactions).get(), hasLength(1));
        expect(after.where((p) => p.cancelled), hasLength(1));
      },
    );
  }

  test('backup rejects orphaned carry and accepts real categorized and unclassified transfers', () async {
    final dir = await Directory.systemTemp.createTemp('carry-backup-');
    addTearDown(() => dir.delete(recursive: true));
    final backup = BackupService(db, directory: dir);
    for (final classified in [true, false]) {
      final plan = await payments.createPlan(
        amountMinor: 200,
        installmentCount: 2,
        firstDueDate: DateTime(2026, 10, 1),
        accountId: bank,
        splits: classified
            ? const [SplitDraft(categoryId: 'a', amountMinor: 200)]
            : const [],
      );
      final p = plan.first;
      final key = '${PendingPaymentService.prefix}${p.id}';
      final corrupt = {
        ...p.data,
        'carriedMinor': 20,
        'carriedSplits': classified
            ? [
                {'categoryId': 'a', 'amountMinor': 20},
              ]
            : [],
      };
      await (db.update(db.appSettings)..where((s) => s.key.equals(key))).write(
        AppSettingsCompanion(value: Value(jsonEncode(corrupt))),
      );
      await expectLater(
        backup.restore(await backup.createBytes('password'), 'password'),
        throwsA(isA<BackupException>()),
      );
      await (db.update(db.appSettings)..where((s) => s.key.equals(key))).write(
        AppSettingsCompanion(value: Value(jsonEncode(p.data))),
      );
      await payments.pay(
        id: p.id,
        expectedRevision: 0,
        amountMinor: 40,
        paidAt: DateTime(2026, 10, 1),
        accountId: bank,
        carryRemainder: true,
      );
      await backup.restore(await backup.createBytes('password'), 'password');
      expect((await payments.read(plan.last.id))!.remainingMinor, 160);
    }
  });
}

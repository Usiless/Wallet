import 'package:drift/native.dart';
import 'package:finanzas_locales/core/money/money.dart';
import 'package:finanzas_locales/core/errors/app_exception.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:finanzas_locales/features/payments/domain/pending_payment_service.dart';

void main() {
  test(
    'plans conserve integer totals and only payment creates ledger',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final account = await AccountsService(db).createAccount(
        const CreateAccountDraft(name: 'Banco', type: AccountType.bank),
      );
      final service = PendingPaymentService(db);
      final dues = await service.createPlan(
        amountMinor: 100001,
        installmentCount: 3,
        firstDueDate: DateTime(2026, 1, 31),
        accountId: account,
      );
      expect(dues.map((e) => e.amountMinor), [33333, 33333, 33335]);
      expect(dues[1].dueDate, DateTime(2026, 2, 28));
      expect(dues[2].dueDate, DateTime(2026, 3, 31));
      expect(await db.select(db.ledgerTransactions).get(), isEmpty);
      await service.pay(
        id: dues.first.id,
        expectedRevision: 0,
        amountMinor: 10000,
        paidAt: DateTime(2026, 2, 1),
        accountId: account,
        carryRemainder: true,
      );
      final after = await service.list();
      expect(after.fold<int>(0, (n, p) => n + p.remainingMinor), 90001);
      expect(await db.select(db.ledgerTransactions).get(), hasLength(1));
      await expectLater(
        service.pay(
          id: dues.first.id,
          expectedRevision: 0,
          amountMinor: 10000,
          paidAt: DateTime.now(),
          accountId: account,
        ),
        throwsStateError,
      );
    },
  );
  test('deleted payment reopens obligation; stale restore cannot pay; last carry fails', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final account = await AccountsService(db).createAccount(
      const CreateAccountDraft(name: 'Banco', type: AccountType.bank),
    );
    final service = PendingPaymentService(db);
    final p = (await service.createPlan(
      amountMinor: 100,
      installmentCount: 1,
      firstDueDate: DateTime(2026, 1, 1),
      accountId: account,
    )).single;
    await expectLater(
      service.pay(
        id: p.id,
        expectedRevision: 0,
        amountMinor: 50,
        paidAt: DateTime.now(),
        accountId: account,
        carryRemainder: true,
      ),
      throwsStateError,
    );
    final tx = await service.pay(
      id: p.id,
      expectedRevision: 0,
      amountMinor: 100,
      paidAt: DateTime.now(),
      accountId: account,
    );
    expect((await service.read(p.id))!.remainingMinor, 0);
    await LedgerService(db).softDelete(tx);
    expect((await service.read(p.id))!.remainingMinor, 100);
    db.restoreGeneration++;
    await expectLater(
      service.pay(
        id: p.id,
        expectedRevision: 2,
        amountMinor: 100,
        paidAt: DateTime.now(),
        accountId: account,
        expectedBookGeneration: 0,
      ),
      throwsStateError,
    );
    await service.pay(
      id: p.id,
      expectedRevision: 2,
      amountMinor: 100,
      paidAt: DateTime.now(),
      accountId: account,
      expectedBookGeneration: 1,
    );
    expect((await service.read(p.id))!.remainingMinor, 0);
  });
  test('exact categories survive partial payments and carry; competing payment loses', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.now();
    for (final id in ['a', 'b']) {
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
    final account = await AccountsService(db).createAccount(
      const CreateAccountDraft(name: 'Banco', type: AccountType.bank),
    );
    final service = PendingPaymentService(db);
    final dues = await service.createPlan(
      amountMinor: 100001,
      installmentCount: 3,
      firstDueDate: DateTime(2026, 1, 1),
      accountId: account,
      splits: const [
        SplitDraft(categoryId: 'a', amountMinor: 60001),
        SplitDraft(categoryId: 'b', amountMinor: 40000),
      ],
    );
    expect(dues.fold<int>(0, (n, p) => n + p.splits.first.amountMinor), 60001);
    final outcomes = await Future.wait([
      for (var i = 0; i < 2; i++)
        service
            .pay(
              id: dues.first.id,
              expectedRevision: 0,
              amountMinor: 10000,
              paidAt: now,
              accountId: account,
              carryRemainder: true,
            )
            .then<Object>((v) => v, onError: (Object e) => e),
    ]);
    expect(outcomes.whereType<String>(), hasLength(1));
    expect(outcomes.whereType<StateError>(), hasLength(1));
    final pending = await service.list();
    expect(
      pending.fold<int>(
        0,
        (n, p) => n + p.remainingSplits.values.fold<int>(0, (a, b) => a + b),
      ),
      90001,
    );
    await service.edit(
      id: dues.last.id,
      expectedRevision: 0,
      amountMinor: 40000,
      dueDate: DateTime(2026, 4, 1),
      following: true,
    );
    expect((await service.read(dues.first.id))!.paidMinor, 10000);
  });
  test(
    'reminder bounds are enforced before creating or updating obligations',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final account = await AccountsService(db).createAccount(
        const CreateAccountDraft(name: 'Banco', type: AccountType.bank),
      );
      final service = PendingPaymentService(db);
      await expectLater(
        service.createPlan(
          amountMinor: 100,
          installmentCount: 1,
          firstDueDate: DateTime(2026),
          accountId: account,
          reminders: const PaymentReminderSettings(daysBefore: 61),
        ),
        throwsFormatException,
      );
      expect(await service.list(), isEmpty);
      final p = (await service.createPlan(
        amountMinor: 100,
        installmentCount: 1,
        firstDueDate: DateTime(2026),
        accountId: account,
      )).single;
      await expectLater(
        service.updateReminders(
          p.id,
          expectedRevision: 0,
          settings: const PaymentReminderSettings(daysBefore: 61),
        ),
        throwsFormatException,
      );
    },
  );
  test('edited linked payment categories and amount determine remaining category debt', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.now();
    for (final id in ['a', 'b']) {
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
    final account = await AccountsService(db).createAccount(
      const CreateAccountDraft(name: 'Banco', type: AccountType.bank),
    );
    final service = PendingPaymentService(db);
    final p = (await service.createPlan(
      amountMinor: 100,
      installmentCount: 1,
      firstDueDate: DateTime(2026),
      accountId: account,
      splits: const [
        SplitDraft(categoryId: 'a', amountMinor: 60),
        SplitDraft(categoryId: 'b', amountMinor: 40),
      ],
    )).single;
    final tx = await service.pay(
      id: p.id,
      expectedRevision: 0,
      amountMinor: 50,
      paidAt: now,
      accountId: account,
    );
    await LedgerService(db).update(
      tx,
      TransactionDraft(
        type: TransactionType.expense,
        amount: const Money(20, currencyCode: 'PYG'),
        occurredAt: now,
        fromAccountId: account,
        paymentChannel: PaymentChannel.other,
        splits: const [SplitDraft(categoryId: 'b', amountMinor: 20)],
      ),
    );
    final after = (await service.read(p.id))!;
    expect(after.remainingMinor, 80);
    expect(after.remainingSplits, {'a': 60, 'b': 20});
    await LedgerService(db).softDelete(tx);
    final deleted = (await service.read(p.id))!;
    expect(deleted.remainingSplits, {'a': 60, 'b': 40});
  });
  test('linked ledger changes invalidate payment revision and cannot overpay or restore twice', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.now();
    final account = await AccountsService(db).createAccount(
      const CreateAccountDraft(name: 'Banco', type: AccountType.bank),
    );
    final service = PendingPaymentService(db);
    final ledger = LedgerService(db);
    final p = (await service.createPlan(
      amountMinor: 100,
      installmentCount: 1,
      firstDueDate: DateTime(2026),
      accountId: account,
    )).single;
    final tx = await service.pay(
      id: p.id,
      expectedRevision: 0,
      amountMinor: 60,
      paidAt: now,
      accountId: account,
    );
    await expectLater(
      ledger.update(
        tx,
        TransactionDraft(
          type: TransactionType.expense,
          amount: const Money(101),
          occurredAt: now,
          fromAccountId: account,
        ),
      ),
      throwsA(isA<ValidationException>()),
    );
    await ledger.update(
      tx,
      TransactionDraft(
        type: TransactionType.expense,
        amount: const Money(50),
        occurredAt: now,
        fromAccountId: account,
      ),
    );
    await expectLater(
      service.pay(
        id: p.id,
        expectedRevision: 1,
        amountMinor: 50,
        paidAt: now,
        accountId: account,
      ),
      throwsStateError,
    );
    await ledger.softDelete(tx);
    final reopened = (await service.read(p.id))!;
    await service.pay(
      id: p.id,
      expectedRevision: reopened.revision,
      amountMinor: 100,
      paidAt: now,
      accountId: account,
    );
    await expectLater(ledger.restore(tx), throwsA(isA<ValidationException>()));
    expect((await service.read(p.id))!.remainingMinor, 0);
  });
  test('recategorized payment never produces negative category debt', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.now();
    for (final id in ['a', 'b']) {
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
    final account = await AccountsService(db).createAccount(
      const CreateAccountDraft(name: 'Banco', type: AccountType.bank),
    );
    final service = PendingPaymentService(db);
    final p = (await service.createPlan(
      amountMinor: 100,
      installmentCount: 1,
      firstDueDate: DateTime(2026),
      accountId: account,
      splits: const [
        SplitDraft(categoryId: 'a', amountMinor: 60),
        SplitDraft(categoryId: 'b', amountMinor: 40),
      ],
    )).single;
    final tx = await service.pay(
      id: p.id,
      expectedRevision: 0,
      amountMinor: 80,
      paidAt: now,
      accountId: account,
    );
    await LedgerService(db).update(
      tx,
      TransactionDraft(
        type: TransactionType.expense,
        amount: const Money(80),
        occurredAt: now,
        fromAccountId: account,
        splits: const [SplitDraft(categoryId: 'b', amountMinor: 80)],
      ),
    );
    expect((await service.read(p.id))!.remainingSplits, {'a': 20});
  });
  test(
    'reopened carried installment preserves cumulative category carry',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.now();
      for (final id in ['a', 'b']) {
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
      final account = await AccountsService(db).createAccount(
        const CreateAccountDraft(name: 'Banco', type: AccountType.bank),
      );
      final service = PendingPaymentService(db);
      final dues = await service.createPlan(
        amountMinor: 200,
        installmentCount: 2,
        firstDueDate: DateTime(2026),
        accountId: account,
        splits: const [
          SplitDraft(categoryId: 'a', amountMinor: 120),
          SplitDraft(categoryId: 'b', amountMinor: 80),
        ],
      );
      final first = dues.first;
      final tx = await service.pay(
        id: first.id,
        expectedRevision: 0,
        amountMinor: 50,
        paidAt: now,
        accountId: account,
        carryRemainder: true,
      );
      await LedgerService(db).softDelete(tx);
      final reopened = (await service.read(first.id))!;
      await service.pay(
        id: first.id,
        expectedRevision: reopened.revision,
        amountMinor: 25,
        paidAt: now,
        accountId: account,
        carryRemainder: true,
      );
      final after = await service.list();
      expect(after.map((p) => p.remainingMinor), [0, 175]);
      expect(after.first.data['carriedMinor'], 75);
      final carried = after.first.data['carriedSplits'] as List;
      expect(carried.fold<int>(0, (n, p) => n + (p['amountMinor'] as int)), 75);
      expect(after.last.remainingSplits, {'a': 105, 'b': 70});
    },
  );
  test('archived original merchant and categories remain payable historical references', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final now = DateTime.now();
    await db
        .into(db.categories)
        .insert(
          CategoriesCompanion.insert(
            id: 'a',
            name: 'a',
            kind: 'expense',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.merchants)
        .insert(
          MerchantsCompanion.insert(
            id: 'shop',
            name: 'Shop',
            normalizedName: 'shop',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final account = await AccountsService(db).createAccount(
      const CreateAccountDraft(name: 'Banco', type: AccountType.bank),
    );
    final service = PendingPaymentService(db);
    final p = (await service.createPlan(
      amountMinor: 100,
      installmentCount: 1,
      firstDueDate: DateTime(2026),
      accountId: account,
      merchantId: 'shop',
      splits: const [SplitDraft(categoryId: 'a', amountMinor: 100)],
    )).single;
    await db.customStatement(
      "UPDATE categories SET is_archived = 1 WHERE id = 'a'",
    );
    await db.customStatement(
      "UPDATE merchants SET is_archived = 1 WHERE id = 'shop'",
    );
    await service.pay(
      id: p.id,
      expectedRevision: 0,
      amountMinor: 100,
      paidAt: now,
      accountId: account,
    );
    expect((await service.read(p.id))!.remainingMinor, 0);
    expect(
      (await db.select(db.transactionSplits).get()).single.categoryId,
      'a',
    );
  });
}

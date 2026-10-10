import 'package:drift/native.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/payments/domain/pending_payment_service.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late PendingPaymentService service;
  late String bank;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
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
    bank = await AccountsService(db).createAccount(
      const CreateAccountDraft(name: 'Banco', type: AccountType.bank),
    );
    service = PendingPaymentService(db);
  });

  test('list agrupa pagos y repartos por pendiente, ignora eliminados y coincide con read', () async {
    final plan = await service.createPlan(
      amountMinor: 100,
      installmentCount: 3,
      firstDueDate: DateTime(2026, 1, 1),
      accountId: bank,
      splits: const [
        SplitDraft(categoryId: 'a', amountMinor: 60),
        SplitDraft(categoryId: 'b', amountMinor: 40),
      ],
    );
    final firstTx = await service.pay(
      id: plan[0].id,
      expectedRevision: 0,
      amountMinor: plan[0].amountMinor,
      paidAt: DateTime(2026, 1, 2),
      accountId: bank,
    );
    final secondTx = await service.pay(
      id: plan[1].id,
      expectedRevision: 0,
      amountMinor: plan[1].amountMinor,
      paidAt: DateTime(2026, 2, 2),
      accountId: bank,
    );
    await LedgerService(db).softDelete(secondTx);

    final listed = {for (final p in await service.list()) p.id: p};
    final first = listed[plan[0].id]!;
    final second = listed[plan[1].id]!;
    final third = listed[plan[2].id]!;

    expect(first.effectivePaidMinor, plan[0].amountMinor);
    expect(first.effectivePayments, hasLength(1));
    final firstSplits = (first.effectivePayments!.single['splits'] as List)
        .cast<Map<String, dynamic>>();
    final stored = await (db.select(
      db.transactionSplits,
    )..where((s) => s.transactionId.equals(firstTx))).get();
    expect(
      {for (final s in firstSplits) s['categoryId']: s['amountMinor']},
      {for (final s in stored) s.categoryId: s.amountMinor},
    );
    expect(
      firstSplits.fold<int>(0, (n, s) => n + (s['amountMinor'] as int)),
      plan[0].amountMinor,
    );

    expect(second.effectivePayments, isEmpty);
    expect(second.effectivePaidMinor, 0);
    expect(second.remainingMinor, plan[1].amountMinor);

    expect(third.effectivePayments, isEmpty);
    expect(third.effectivePaidMinor, 0);

    for (final p in listed.values) {
      final single = (await service.read(p.id))!;
      expect(single.effectivePaidMinor, p.effectivePaidMinor);
      expect(single.remainingMinor, p.remainingMinor);
      expect(single.remainingSplits, p.remainingSplits);
    }
  });

  test(
    'un pendiente sin repartos conserva pago y lista vacía de repartos',
    () async {
      final plan = await service.createPlan(
        amountMinor: 50,
        installmentCount: 1,
        firstDueDate: DateTime(2026, 1, 1),
        accountId: bank,
      );
      await service.pay(
        id: plan.single.id,
        expectedRevision: 0,
        amountMinor: 50,
        paidAt: DateTime(2026, 1, 2),
        accountId: bank,
      );
      final p = (await service.list()).single;
      expect(p.effectivePaidMinor, 50);
      expect(p.effectivePayments!.single['splits'], isEmpty);
    },
  );

  test('sin pendientes no consulta ni falla', () async {
    expect(await service.list(), isEmpty);
  });
}

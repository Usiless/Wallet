import 'package:drift/native.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/money/money.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/budgets/domain/budget_service.dart';
import 'package:finanzas_locales/features/installments/domain/installment_service.dart';
import 'package:finanzas_locales/features/merchants/merchant_service.dart';
import 'package:finanzas_locales/features/reports/data/report_service.dart';
import 'package:finanzas_locales/features/transactions/data/category_service.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_repository.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late AccountsService accounts;
  late LedgerService ledger;
  late String bank, card, category, merchant;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    accounts = AccountsService(db);
    ledger = LedgerService(db);
    bank = await accounts.createAccount(
      const CreateAccountDraft(
        name: 'Banco',
        type: AccountType.bank,
        initialBalanceMinor: 1000000,
      ),
    );
    card = await accounts.createAccount(
      const CreateAccountDraft(
        name: 'Tarjeta',
        type: AccountType.creditCard,
        creditLimitMinor: 1000000,
      ),
    );
    category = await CategoryService(db).create('Comida', kind: 'expense');
    merchant = await MerchantService(db).findOrCreate('Ecop');
  });
  tearDown(() => db.close());
  TransactionDraft expense(int amount, {String? account, DateTime? date}) =>
      TransactionDraft(
        type: TransactionType.expense,
        amount: Money(amount),
        occurredAt: date ?? DateTime(2026, 10, 4),
        fromAccountId: account ?? bank,
        merchantId: merchant,
        description: 'Ecop',
        splits: [SplitDraft(categoryId: category, amountMinor: amount)],
      );
  test('editar conserva identidad y fuente; reemplaza saldos y cuotas en lugar de duplicarlos', () async {
    final id = await ledger.create(expense(90000, account: card));
    await InstallmentService(db).attachPlan(
      transactionId: id,
      count: 3,
      firstPeriod: DateTime(2026, 10, 4),
    );
    final original = await (db.select(
      db.ledgerTransactions,
    )..where((t) => t.id.equals(id))).getSingle();
    await ledger.update(
      id,
      expense(120000, account: card, date: DateTime(2026, 11, 2)),
      expectedUpdatedAt: original.updatedAt,
      installmentCount: 4,
    );
    final row = await db.select(db.ledgerTransactions).getSingle();
    expect(row.id, id);
    expect(row.source, original.source);
    expect(await ledger.balance(card), 120000);
    final plan = await db.select(db.installmentPlans).getSingle();
    expect(plan.installmentCount, 4);
    final entries = await db.select(db.installmentEntries).get();
    expect(entries, hasLength(4));
    expect(entries.fold<int>(0, (s, e) => s + e.amountMinor), 120000);
    expect(entries.first.periodStart.toUtc().month, 11);
    await expectLater(
      ledger.update(id, expense(100), expectedUpdatedAt: original.updatedAt),
      throwsException,
    );
    expect(await ledger.balance(card), 120000);
  });
  test(
    'fallo al reconstruir cuotas revierte edición, partidas y plan',
    () async {
      final id = await ledger.create(expense(90000, account: card));
      await InstallmentService(db).attachPlan(
        transactionId: id,
        count: 3,
        firstPeriod: DateTime(2026, 10, 4),
      );
      await db.customStatement(
        "CREATE TRIGGER fail_edit BEFORE INSERT ON installment_plans BEGIN SELECT RAISE(ABORT,'fallo'); END",
      );
      await expectLater(
        ledger.update(id, expense(120000, account: card), installmentCount: 4),
        throwsException,
      );
      expect(
        (await db.select(db.ledgerTransactions).getSingle()).amountMinor,
        90000,
      );
      expect(await ledger.balance(card), 90000);
      expect(
        (await db.select(db.installmentPlans).getSingle()).installmentCount,
        3,
      );
    },
  );
  test('devoluciones vinculadas reducen saldo y presupuesto; límite concurrente y deshacer', () async {
    final id = await ledger.create(expense(100000));
    final budgetId = await BudgetService(db).create(
      name: 'Comida',
      month: DateTime(2026, 10),
      targetMinor: 200000,
      categoryId: category,
    );
    final results = await Future.wait([
      for (var i = 0; i < 2; i++)
        ledger
            .refund(
              purchaseId: id,
              amountMinor: 70000,
              occurredAt: DateTime(2026, 10, 5),
            )
            .then((id) => id)
            .catchError((Object e) => 'failed'),
    ]);
    expect(results.where((id) => id != 'failed'), hasLength(1));
    expect(await ledger.balance(bank), 970000);
    final budget = await (db.select(
      db.budgets,
    )..where((t) => t.id.equals(budgetId))).getSingle();
    expect(
      (await BudgetService(db).progress(budget)).progress.consumedMinor,
      30000,
    );
    await expectLater(ledger.softDelete(id), throwsException);
    final refundId = results.firstWhere((id) => id != 'failed');
    await ledger.softDelete(refundId);
    expect(await ledger.balance(bank), 900000);
    await ledger.refund(
      purchaseId: id,
      amountMinor: 100000,
      occurredAt: DateTime(2026, 10, 6),
    );
    await expectLater(ledger.restore(refundId), throwsException);
    await expectLater(ledger.update(id, expense(50000)), throwsException);
  });
  test(
    'devoluciones parciales agotan categorías sin perder unidades por redondeo',
    () async {
      final second = await CategoryService(db).create('Otra', kind: 'expense');
      final id = await ledger.create(
        TransactionDraft(
          type: TransactionType.expense,
          amount: const Money(10),
          occurredAt: DateTime(2026, 10, 1),
          fromAccountId: bank,
          splits: [
            SplitDraft(categoryId: category, amountMinor: 3),
            SplitDraft(categoryId: second, amountMinor: 7),
          ],
        ),
      );
      final ids = <String>[];
      for (var i = 0; i < 10; i++) {
        ids.add(
          await ledger.refund(
            purchaseId: id,
            amountMinor: 1,
            occurredAt: DateTime(2026, 10, 2),
          ),
        );
      }
      final splits = await (db.select(
        db.transactionSplits,
      )..where((t) => t.transactionId.isIn(ids))).get();
      expect(
        splits
            .where((s) => s.categoryId == category)
            .fold<int>(0, (sum, s) => sum + s.amountMinor),
        3,
      );
      expect(
        splits
            .where((s) => s.categoryId == second)
            .fold<int>(0, (sum, s) => sum + s.amountMinor),
        7,
      );
      expect(await ledger.balance(bank), 1000000);
    },
  );
  test(
    'presupuesto abierto se actualiza al editar y devolver una compra',
    () async {
      final id = await ledger.create(expense(100000));
      final budgetId = await BudgetService(
        db,
      ).create(name: 'Total', month: DateTime(2026, 10), targetMinor: 200000);
      final budget = await (db.select(
        db.budgets,
      )..where((t) => t.id.equals(budgetId))).getSingle();
      final values = <int>[];
      final subscription = BudgetService(db)
          .watchProgress(budget)
          .listen((b) => values.add(b.progress.consumedMinor));
      Future<void> waitFor(int value) async {
        for (
          var i = 0;
          i < 100 && (values.isEmpty || values.last != value);
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(values.last, value);
      }

      try {
        await waitFor(100000);
        await ledger.update(id, expense(120000));
        await waitFor(120000);
        await ledger.refund(
          purchaseId: id,
          amountMinor: 20000,
          occurredAt: DateTime(2026, 10, 5),
        );
        await waitFor(100000);
      } finally {
        await subscription.cancel();
      }
    },
  );
  test(
    'conciliación usa saldo natural incluso para deuda y no altera reporte',
    () async {
      await ledger.reconcile(
        accountId: bank,
        targetMinor: 800000,
        expectedBalance: 1000000,
        note: 'Conteo',
      );
      await ledger.reconcile(
        accountId: card,
        targetMinor: 150000,
        expectedBalance: 0,
        note: 'Estado de cuenta',
      );
      expect(await ledger.balance(bank), 800000);
      expect(await ledger.balance(card), 150000);
      await ledger.reconcile(
        accountId: card,
        targetMinor: -10000,
        expectedBalance: 150000,
        note: 'Saldo a favor',
      );
      expect(await ledger.balance(card), -10000);
      await expectLater(
        ledger.reconcile(
          accountId: bank,
          targetMinor: 1,
          expectedBalance: 1000000,
          note: '',
        ),
        throwsException,
      );
      final now = DateTime.now();
      final report = await ReportService(db).watch((
        start: DateTime(now.year, now.month),
        end: DateTime(now.year, now.month + 1),
        category: null,
        monthlyInstallments: false,
      )).first;
      expect(report.income, 0);
      expect(report.expenses, 0);
    },
  );
  test('cuotas por período y compras completas no duplican compras; devoluciones netas pueden ser negativas', () async {
    final id = await ledger.create(
      expense(90000, account: card, date: DateTime(2026, 9, 20)),
    );
    await InstallmentService(db).attachPlan(
      transactionId: id,
      count: 3,
      firstPeriod: DateTime(2026, 9, 20),
    );
    await ledger.refund(
      purchaseId: id,
      amountMinor: 50000,
      occurredAt: DateTime(2026, 10, 2),
    );
    final request = (
      start: DateTime(2026, 10),
      end: DateTime(2026, 11),
      category: category,
      monthlyInstallments: true,
    );
    final report = await ReportService(db).watch(request).first;
    expect(report.expenses, 30000);
    expect(report.refunds, 50000);
    expect(report.netExpenses, -20000);
    final full = await ReportService(db).watch((
      start: DateTime(2026, 9),
      end: DateTime(2026, 12),
      category: null,
      monthlyInstallments: false,
    )).first;
    expect(full.expenses, 90000);
    expect(full.refunds, 50000);
  });
  test(
    'filtros combinados y búsqueda literal recorren todo el historial',
    () async {
      final id = await ledger.create(expense(1000));
      await ledger.create(
        TransactionDraft(
          type: TransactionType.income,
          amount: const Money(100),
          occurredAt: DateTime(2026, 10, 4),
          toAccountId: bank,
        ),
      );
      final repo = LedgerRepository(db);
      final rows = await repo
          .watchFiltered(
            filter: (
              search: 'ecop',
              account: bank,
              merchant: merchant,
              category: category,
              type: 'expense',
              start: DateTime(2026, 10),
              end: DateTime(2026, 11),
            ),
          )
          .first;
      expect(rows.map((r) => r.id), [id]);
      expect(
        await repo
            .watchFiltered(
              filter: (
                search: '%',
                account: null,
                merchant: null,
                category: null,
                type: null,
                start: null,
                end: null,
              ),
            )
            .first,
        isEmpty,
      );
    },
  );
  test('archivo y edición preservan historia; conflictos de alias se resuelven explícitamente', () async {
    await ledger.create(expense(1000));
    await accounts.assignAlias('••5962', card);
    await accounts.assignAlias('5962', bank, replaceExisting: true);
    expect((await accounts.findByNameOrAlias('5962'))?.id, bank);
    await accounts.edit(
      bank,
      const CreateAccountDraft(
        name: 'Banco renombrado',
        type: AccountType.bank,
        initialBalanceMinor: 1000000,
        aliases: ['5962'],
      ),
    );
    expect(await ledger.balance(bank), 999000);
    await expectLater(
      accounts.edit(
        bank,
        const CreateAccountDraft(
          name: 'Otro',
          type: AccountType.cash,
          initialBalanceMinor: 1000000,
        ),
      ),
      throwsException,
    );
    await accounts.setArchived(bank, true);
    expect(await accounts.findByNameOrAlias('5962'), isNull);
    expect(await db.select(db.ledgerTransactions).get(), hasLength(1));
    await accounts.setArchived(bank, false);
    expect(await ledger.balance(bank), 999000);
    await MerchantService(db).rename(merchant, 'Ecop Obligado');
    expect((await MerchantService(db).matches('Ecop')).single.id, merchant);
    await CategoryService(db).rename(category, 'Alimentos');
    await CategoryService(db).setArchived(category, true);
    expect(
      (await db.select(db.transactionSplits).getSingle()).categoryId,
      category,
    );
  });
}

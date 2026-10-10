import 'package:drift/native.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/money/money.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/installments/domain/installment_service.dart';
import 'package:finanzas_locales/features/merchants/merchant_service.dart';
import 'package:finanzas_locales/features/reports/data/report_service.dart';
import 'package:finanzas_locales/features/transactions/data/category_service.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_repository.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_locales/features/payments/domain/pending_payment_service.dart';

void main() {
  late AppDatabase db;
  late LedgerService ledger;
  late String bank, card, food, fuel, shop;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ledger = LedgerService(db);
    final accounts = AccountsService(db);
    bank = await accounts.createAccount(
      const CreateAccountDraft(name: 'Banco', type: AccountType.bank),
    );
    card = await accounts.createAccount(
      const CreateAccountDraft(
        name: 'Tarjeta',
        type: AccountType.creditCard,
        creditLimitMinor: 1000000,
      ),
    );
    food = await CategoryService(db).create('Comida', kind: 'expense');
    fuel = await CategoryService(db).create('Combustible', kind: 'expense');
    shop = await MerchantService(db).findOrCreate('Ecop');
  });
  tearDown(() => db.close());
  Future<String> buy(
    int amount,
    DateTime date, {
    bool classified = true,
    String? account,
    List<SplitDraft>? splits,
  }) => ledger.create(
    TransactionDraft(
      type: TransactionType.expense,
      amount: Money(amount),
      occurredAt: date,
      fromAccountId: account ?? bank,
      merchantId: shop,
      splits:
          splits ??
          (classified
              ? [SplitDraft(categoryId: fuel, amountMinor: amount)]
              : []),
    ),
  );
  Future<ReportAnalysis> report({
    DateTime? start,
    DateTime? end,
    String? category,
    String? account,
    bool quotas = false,
  }) => ReportService(db).watchAnalysis((
    period: (
      start: start ?? DateTime(2026, 10),
      end: end ?? DateTime(2026, 11),
      category: category,
      monthlyInstallments: quotas,
    ),
    account: account,
  )).first;

  test('pending category totals follow residual while actual expense is counted once', () async {
    final payments = PendingPaymentService(db);
    final p = (await payments.createPlan(
      amountMinor: 100,
      installmentCount: 1,
      firstDueDate: DateTime(2026, 10, 10),
      accountId: bank,
      splits: [
        SplitDraft(categoryId: food, amountMinor: 60),
        SplitDraft(categoryId: fuel, amountMinor: 40),
      ],
    )).single;
    await payments.pay(
      id: p.id,
      expectedRevision: 0,
      amountMinor: 50,
      paidAt: DateTime(2026, 10, 10),
      accountId: bank,
    );
    final all = await report();
    expect(all.totals.expenses, 50);
    expect(all.totals.pendingExpenses, 50);
    final filtered = await report(category: food);
    expect(filtered.totals.expenses, 30);
    expect(filtered.totals.pendingExpenses, 30);
    expect((await report(account: card)).totals.pendingExpenses, 0);
  });
  test(
    'desgloses coinciden con los totales y conservan referencias archivadas',
    () async {
      final purchase = await buy(
        100,
        DateTime(2026, 10, 2),
        splits: [
          SplitDraft(categoryId: food, amountMinor: 30),
          SplitDraft(categoryId: fuel, amountMinor: 70),
        ],
      );
      await buy(50, DateTime(2026, 10, 4), classified: false, account: card);
      await ledger.refund(
        purchaseId: purchase,
        amountMinor: 20,
        occurredAt: DateTime(2026, 10, 5),
      );
      await ledger.create(
        TransactionDraft(
          type: TransactionType.income,
          amount: const Money(200),
          occurredAt: DateTime(2026, 10, 1),
          toAccountId: bank,
        ),
      );
      await CategoryService(db).setArchived(food, true);
      await AccountsService(db).setArchived(bank, true);
      final a = await report();
      expect(
        [
          a.totals.income,
          a.totals.expenses,
          a.totals.refunds,
          a.totals.balance,
        ],
        [200, 150, 20, 70],
      );
      expect(a.expenseCount, 2);
      expect([a.unclassifiedCount, a.unclassifiedAmount], [1, 50]);
      for (final groups in [a.categories, a.merchants, a.accounts]) {
        expect(groups.fold<int>(0, (s, g) => s + g.totals.expenses), 150);
        expect(groups.fold<int>(0, (s, g) => s + g.totals.refunds), 20);
      }
      expect(a.categories.first.name, 'Combustible');
      expect(a.categories.any((c) => c.name == 'Comida'), isTrue);
      expect((await report(account: bank)).totals.expenses, 100);
      expect((await report(category: food)).totals.expenses, 30);
    },
  );
  test(
    'mes anterior y evolución incluyen ceros sin recurrir al último mes activo',
    () async {
      await buy(400, DateTime(2026, 8, 5));
      await buy(200, DateTime(2026, 10, 5));
      final a = await report();
      expect(a.previousStart, DateTime(2026, 9));
      expect(a.previous.netExpenses, 0);
      expect(a.changePercent, isNull);
      expect(a.months.length, 6);
      expect(a.months.map((m) => m.totals.expenses), [0, 0, 0, 400, 0, 200]);
    },
  );
  test('períodos personalizados comparan igual cantidad de días y extremos parciales', () async {
    await buy(20, DateTime(2026, 10, 1));
    await buy(30, DateTime(2026, 10, 9));
    await buy(40, DateTime(2026, 10, 10));
    await buy(50, DateTime(2026, 10, 12));
    await buy(60, DateTime(2026, 10, 13));
    final a = await report(
      start: DateTime(2026, 10, 10),
      end: DateTime(2026, 10, 13),
    );
    expect(a.previousStart, DateTime(2026, 10, 7));
    expect(a.previous.expenses, 30);
    expect(a.totals.expenses, 90);
    expect(a.months.single.totals.expenses, 90);
    expect(a.changePercent, 200);
  });
  test(
    'cuotas conservan cada unidad de las categorías durante el plan completo',
    () async {
      final id = await buy(
        10,
        DateTime(2026, 8, 2),
        account: card,
        splits: [
          SplitDraft(categoryId: food, amountMinor: 3),
          SplitDraft(categoryId: fuel, amountMinor: 7),
        ],
      );
      await InstallmentService(
        db,
      ).attachPlan(transactionId: id, count: 3, firstPeriod: DateTime(2026, 9));
      final entire = await report(
        start: DateTime(2026, 9),
        end: DateTime(2026, 12),
        quotas: true,
      );
      expect(entire.totals.expenses, 10);
      expect(
        entire.categories.firstWhere((c) => c.id == food).totals.expenses,
        3,
      );
      expect(
        entire.categories.firstWhere((c) => c.id == fuel).totals.expenses,
        7,
      );
      final entries = await db.select(db.installmentEntries).get();
      for (var month = 9; month <= 11; month++) {
        final a = await report(
          start: DateTime(2026, month),
          end: DateTime(2026, month + 1),
          quotas: true,
        );
        final entry = entries.singleWhere(
          (e) => e.periodStart.toUtc().month == month,
        );
        expect(a.totals.expenses, entry.amountMinor);
        expect(
          a.categories.fold<int>(0, (s, c) => s + c.totals.expenses),
          entry.amountMinor,
        );
      }
      expect((await report()).totals.expenses, 0);
    },
  );
  test(
    'devoluciones usan su fecha, pueden dar neto negativo y no alteran cuotas',
    () async {
      final id = await buy(900, DateTime(2026, 9, 1), account: card);
      await InstallmentService(
        db,
      ).attachPlan(transactionId: id, count: 3, firstPeriod: DateTime(2026, 9));
      await ledger.refund(
        purchaseId: id,
        amountMinor: 500,
        occurredAt: DateTime(2026, 10, 4),
      );
      final a = await report(quotas: true);
      expect(
        [a.totals.expenses, a.totals.refunds, a.totals.netExpenses],
        [300, 500, -200],
      );
      expect(a.merchants.single.totals.netExpenses, -200);
      expect((await report()).totals.netExpenses, -500);
      expect(
        (await report(
          start: DateTime(2026, 11),
          end: DateTime(2026, 12),
          quotas: true,
        )).totals.expenses,
        300,
      );
    },
  );
  test(
    'sin tope de historial; pendientes, borrados y transferencias no cuentan',
    () async {
      for (var i = 0; i < 105; i++) {
        await buy(10, DateTime(2026, 10, 2));
      }
      final deleted = await buy(900, DateTime(2026, 10, 2));
      await ledger.softDelete(deleted);
      await ledger.create(
        TransactionDraft(
          type: TransactionType.expense,
          status: TransactionStatus.pending,
          amount: const Money(800),
          occurredAt: DateTime(2026, 10, 2),
          fromAccountId: bank,
        ),
      );
      await ledger.create(
        TransactionDraft(
          type: TransactionType.transfer,
          amount: const Money(700),
          occurredAt: DateTime(2026, 10, 2),
          fromAccountId: bank,
          toAccountId: card,
        ),
      );
      final a = await report();
      expect(a.expenseCount, 105);
      expect(a.totals.expenses, 1050);
    },
  );
  test('detalle de cuotas recupera compras anteriores y respeta categorías y cuentas', () async {
    final id = await buy(900, DateTime(2026, 8, 1), account: card);
    await InstallmentService(
      db,
    ).attachPlan(transactionId: id, count: 3, firstPeriod: DateTime(2026, 9));
    await buy(50, DateTime(2026, 10, 2), classified: false);
    final filter = (
      search: '',
      account: card,
      merchant: shop,
      category: fuel,
      type: 'purchases',
      start: DateTime(2026, 10),
      end: DateTime(2026, 11),
    );
    final repo = LedgerRepository(db);
    expect(
      (await repo.watchMovements(filter: filter, reportOnly: true).first).map(
        (m) => (m.transaction.id, m.number, m.quotaMinor),
      ),
      [(id, 2, 300)],
    );
    final unclassified = await repo
        .watchMovements(
          filter: (
            search: '',
            account: null,
            merchant: null,
            category: null,
            type: 'expense',
            start: DateTime(2026, 10),
            end: DateTime(2026, 11),
          ),
          unclassifiedOnly: true,
          reportOnly: true,
        )
        .first;
    expect(unclassified.single.amountMinor, 50);
  });
}

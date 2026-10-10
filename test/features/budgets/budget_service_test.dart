import 'package:drift/native.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/money/money.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/budgets/domain/budget_service.dart';
import 'package:finanzas_locales/features/installments/domain/installment_service.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => database.close());

  test('presupuesto incluye la madrugada del primer día y excluye el siguiente mes', () async {
    final account = await AccountsService(database).createAccount(
      const CreateAccountDraft(name: 'Banco', type: AccountType.bank),
    );
    final ledger = LedgerService(database);
    for (final date in [
      DateTime(2026, 9, 30, 23, 59),
      DateTime(2026, 10, 1, 0, 1),
      DateTime(2026, 10, 31, 23, 59),
      DateTime(2026, 11, 1, 0, 1),
    ]) {
      await ledger.create(
        TransactionDraft(
          type: TransactionType.expense,
          amount: const Money(1000),
          occurredAt: date,
          fromAccountId: account,
        ),
      );
    }
    final service = BudgetService(database);
    await service.create(
      name: 'Octubre',
      month: DateTime(2026, 10),
      targetMinor: 10000,
    );
    final budget =
        (await service.watchBudgets(DateTime(2026, 10)).first).single;
    expect((await service.progress(budget)).progress.consumedMinor, 2000);
  });

  test(
    'presupuesto mensual usa cuota del período y excluye transferencias',
    () async {
      final accounts = AccountsService(database);
      final bank = await accounts.createAccount(
        const CreateAccountDraft(name: 'Banco', type: AccountType.bank),
      );
      final card = await accounts.createAccount(
        const CreateAccountDraft(
          name: 'Tarjeta',
          type: AccountType.creditCard,
          creditLimitMinor: 1000000,
        ),
      );
      final now = DateTime.now().toUtc();
      await database
          .into(database.categories)
          .insert(
            CategoriesCompanion.insert(
              id: 'food',
              name: 'Alimentación',
              kind: 'expense',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final ledger = LedgerService(database);
      final purchase = await ledger.create(
        TransactionDraft(
          type: TransactionType.expense,
          amount: const Money(100000),
          occurredAt: DateTime.utc(2026, 6, 10),
          fromAccountId: card,
          splits: const [SplitDraft(categoryId: 'food', amountMinor: 100000)],
        ),
      );
      await InstallmentService(database).attachPlan(
        transactionId: purchase,
        count: 3,
        firstPeriod: DateTime.utc(2026, 6, 10),
      );
      await ledger.create(
        TransactionDraft(
          type: TransactionType.transfer,
          amount: const Money(500000),
          occurredAt: DateTime.utc(2026, 7, 5),
          fromAccountId: bank,
          toAccountId: card,
        ),
      );
      final budgets = BudgetService(database);
      final id = await budgets.create(
        name: 'Julio',
        month: DateTime.utc(2026, 7),
        targetMinor: 200000,
        categoryId: 'food',
      );
      final budget = await (database.select(
        database.budgets,
      )..where((table) => table.id.equals(id))).getSingle();
      final progress = await budgets.progress(budget);
      expect(progress.progress.consumedMinor, 33333);
    },
  );
}

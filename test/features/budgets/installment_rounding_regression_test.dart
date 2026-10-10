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
  test(
    'presupuestos por categoría conservan 51/50 en cuotas 33/33/35',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final card = await AccountsService(database).createAccount(
        const CreateAccountDraft(
          name: 'Tarjeta ficticia H01',
          type: AccountType.creditCard,
          creditLimitMinor: 1000,
        ),
      );
      final now = DateTime.utc(2026, 10, 6);
      for (final id in ['a', 'b']) {
        await database
            .into(database.categories)
            .insert(
              CategoriesCompanion.insert(
                id: id,
                name: 'Categoría ficticia $id',
                kind: 'expense',
                createdAt: now,
                updatedAt: now,
              ),
            );
      }
      final purchase = await LedgerService(database).create(
        TransactionDraft(
          type: TransactionType.expense,
          amount: const Money(101),
          occurredAt: now,
          fromAccountId: card,
          splits: const [
            SplitDraft(categoryId: 'a', amountMinor: 51),
            SplitDraft(categoryId: 'b', amountMinor: 50),
          ],
        ),
      );
      // ReportService assigns integer residues in persisted split-ID order.
      // Fix fixture IDs so the independent monthly oracle is reproducible.
      await database.customStatement(
        "UPDATE transaction_splits SET id = 'h01-' || category_id WHERE transaction_id = ?",
        [purchase],
      );
      await InstallmentService(database)
          .attachPlan(transactionId: purchase, count: 3, firstPeriod: now);
      final service = BudgetService(database);
      final actual = <String, List<int>>{};
      for (final category in ['a', 'b']) {
        actual[category] = [];
        for (var month = 10; month <= 12; month++) {
          final id = await service.create(
            name: 'Presupuesto ficticio $category/$month',
            month: DateTime.utc(2026, month),
            targetMinor: 200,
            categoryId: category,
          );
          final budget = await (database.select(
            database.budgets,
          )..where((row) => row.id.equals(id))).getSingle();
          actual[category]!.add(
            (await service.progress(budget)).progress.consumedMinor,
          );
        }
      }
      expect(actual, {
        'a': [16, 16, 19],
        'b': [17, 17, 16],
      }, reason: 'Oráculo entero: cada mes suma 33/33/35; el plan suma 51/50.');
      final splitIds = {
        for (final part
            in await database.select(database.transactionSplits).get())
          part.categoryId: part.id,
      };
      await LedgerService(database).update(
        purchase,
        TransactionDraft(
          type: TransactionType.expense,
          amount: const Money(101),
          occurredAt: now,
          fromAccountId: card,
          note: 'Nota corregida',
          splits: const [
            SplitDraft(categoryId: 'a', amountMinor: 51),
            SplitDraft(categoryId: 'b', amountMinor: 50),
          ],
        ),
      );
      expect({
        for (final part
            in await database.select(database.transactionSplits).get())
          part.categoryId: part.id,
      }, splitIds);
      final afterEdit = <String, List<int>>{'a': [], 'b': []};
      final budgets = await database.select(database.budgets).get();
      budgets.sort((a, b) => a.periodStart.compareTo(b.periodStart));
      for (final budget in budgets) {
        afterEdit[budget.categoryId]!.add(
          (await service.progress(budget)).progress.consumedMinor,
        );
      }
      expect(
        afterEdit,
        actual,
        reason: 'Editar la nota conserva reparto mensual y referencias.',
      );
    },
  );
}

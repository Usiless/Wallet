import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/money/money.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/catalog/catalog_screen.dart';
import 'package:finanzas_locales/features/reports/presentation/reports_screen.dart';
import 'package:finanzas_locales/features/transactions/data/category_service.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:finanzas_locales/features/transactions/presentation/transaction_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  Future<void> settleDb(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'editar movimiento con cuenta y categoría archivadas conserva sus referencias',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      late String id, bank, category;
      await tester.runAsync(() async {
        bank = await AccountsService(db).createAccount(
          const CreateAccountDraft(
            name: 'Banco',
            type: AccountType.bank,
            initialBalanceMinor: 100000,
          ),
        );
        category = await CategoryService(db)
            .create('Transporte', kind: 'expense');
        id = await LedgerService(db).create(
          TransactionDraft(
            type: TransactionType.expense,
            amount: const Money(10000),
            occurredAt: DateTime(2026, 9, 1),
            fromAccountId: bank,
            splits: [SplitDraft(categoryId: category, amountMinor: 10000)],
          ),
        );
        await AccountsService(db).setArchived(bank, true);
        await CategoryService(db).setArchived(category, true);
      });
      late GoRouter router;
      router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, _) => Scaffold(
              body: TextButton(
                onPressed: () => router.push('/edit'),
                child: const Text('Abrir'),
              ),
            ),
          ),
          GoRoute(
            path: '/edit',
            builder: (_, _) => TransactionFormScreen(editId: id),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await settleDb(tester);
      expect(find.text('Editar movimiento'), findsOneWidget);
      expect(find.text('Banco'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).first, '20000');
      await tester.scrollUntilVisible(
        find.text('Guardar cambios'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Guardar cambios'));
      await settleDb(tester);
      expect(find.text('Abrir'), findsOneWidget);
      await tester.runAsync(() async {
        final row = await db.select(db.ledgerTransactions).getSingle();
        expect(row.id, id);
        expect(row.amountMinor, 20000);
        expect(row.fromAccountId, bank);
        expect(row.occurredAt.toLocal().month, 9);
        final split = await db.select(db.transactionSplits).getSingle();
        expect(split.categoryId, category);
        expect(split.amountMinor, 20000);
        expect(await LedgerService(db).balance(bank), 80000);
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(db.close);
    },
  );
  testWidgets('catálogo y reporte vacío no desbordan una pantalla angosta', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    await tester.runAsync(() async {
      await CategoryService(db).create('Categoría de prueba', kind: 'expense');
    });
    for (final screen in [const CatalogScreen(), const ReportsScreen()]) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(home: screen),
        ),
      );
      await settleDb(tester);
      expect(
        tester.takeException(),
        isNull,
        reason: screen.runtimeType.toString(),
      );
    }
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    await tester.runAsync(db.close);
  });
}

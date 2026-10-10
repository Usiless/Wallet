import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/app/theme/app_theme.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/money/money.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/merchants/merchant_service.dart';
import 'package:finanzas_locales/features/reports/presentation/reports_screen.dart';
import 'package:finanzas_locales/features/transactions/data/category_service.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'cinco reportes con datos, tema real y texto grande; abre su detalle filtrado',
    (tester) async {
      tester.view.physicalSize = const Size(360, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      late String bank, category, merchant;
      await tester.runAsync(() async {
        bank = await AccountsService(db).createAccount(
          const CreateAccountDraft(
            name: 'Banco de prueba',
            type: AccountType.bank,
          ),
        );
        category = await CategoryService(db)
            .create('Combustible', kind: 'expense');
        merchant = await MerchantService(db).findOrCreate('Ecop');
        await LedgerService(db).create(
          TransactionDraft(
            type: TransactionType.expense,
            amount: const Money(79500),
            occurredAt: DateTime.now(),
            fromAccountId: bank,
            merchantId: merchant,
            splits: [SplitDraft(categoryId: category, amountMinor: 79500)],
          ),
        );
      });
      Uri? opened;
      final router = GoRouter(
        initialLocation: '/reports',
        routes: [
          GoRoute(path: '/reports', builder: (_, _) => const ReportsScreen()),
          GoRoute(
            path: '/transactions',
            builder: (_, state) {
              opened = state.uri;
              return Scaffold(body: Text(state.uri.toString()));
            },
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp.router(
            theme: AppTheme.dark(),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.2)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final name in ['Evolución', 'Categorías', 'Comercios', 'Cuentas']) {
        final selector = find.byType(DropdownButtonFormField<int>);
        await tester.ensureVisible(selector);
        await tester.tap(selector);
        await tester.pumpAndSettle();
        await tester.tap(find.text(name).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: name);
      }
      await tester.scrollUntilVisible(
        find.text('Banco de prueba'),
        150,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Banco de prueba'));
      await tester.pumpAndSettle();
      final uri = opened!;
      expect(uri.path, '/transactions');
      expect(uri.queryParameters['account'], bank);
      expect(uri.queryParameters['report'], 'true');
      expect(uri.queryParameters['start'], isNotNull);
      expect(uri.queryParameters['end'], isNotNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      router.dispose();
      await tester.runAsync(db.close);
    },
  );
}

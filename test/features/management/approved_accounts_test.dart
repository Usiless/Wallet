import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/app/router.dart';
import 'package:finanzas_locales/app/theme/app_theme.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:finanzas_locales/features/transactions/presentation/transaction_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('filtrar cuentas y pagar la segunda desde su ficha', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    late String target;
    await tester.runAsync(() async {
      final service = AccountsService(db);
      await service.createAccount(
        const CreateAccountDraft(
          name: 'Banco',
          type: AccountType.bank,
          initialBalanceMinor: 5000000,
        ),
      );
      await service.createAccount(
        const CreateAccountDraft(
          name: 'Primera',
          type: AccountType.creditCard,
          creditLimitMinor: 1000000,
        ),
      );
      target = await service.createAccount(
        const CreateAccountDraft(
          name: 'Segunda',
          type: AccountType.creditCard,
          creditLimitMinor: 2000000,
        ),
      );
    });
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        onboardingCompleteProvider.overrideWith((ref) => Stream.value(true)),
      ],
    );
    final router = container.read(routerProvider)..go('/accounts');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
        ),
      ),
    );
    Future<void> settle() async {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pumpAndSettle();
    }

    await settle();
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Crédito'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Crédito'));
    await settle();
    expect(find.text('Banco'), findsNothing);
    expect(find.text('Primera'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Segunda'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Segunda'));
    await settle();
    expect(find.text('Deuda registrada'), findsOneWidget);
    expect(find.text('Crédito disponible'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Pagar esta tarjeta'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Pagar esta tarjeta'));
    await settle();
    await tester.tap(find.text('Pagar esta tarjeta'));
    await settle();
    expect(
      tester
          .widget<TransactionFormScreen>(find.byType(TransactionFormScreen))
          .toAccountId,
      target,
    );
    expect(find.text('Nuevo movimiento'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    container.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });
}

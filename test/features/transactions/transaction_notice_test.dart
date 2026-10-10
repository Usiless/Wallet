import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/app/theme/app_theme.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/money/money.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:finanzas_locales/features/transactions/presentation/transactions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'aviso de eliminación tiene márgenes y expira aunque tenga acción',
    (tester) async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(database)],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });
      final account = await container
          .read(accountsServiceProvider)
          .createAccount(
            const CreateAccountDraft(name: 'Efectivo', type: AccountType.cash),
          );
      await container
          .read(ledgerServiceProvider)
          .create(
            TransactionDraft(
              type: TransactionType.income,
              amount: const Money(10000),
              occurredAt: DateTime.now(),
              toAccountId: account,
            ),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: const TransactionsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('Movimiento eliminado.'), findsOneWidget);
      expect(find.text('Deshacer'), findsOneWidget);
      final notice = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(notice.persist, isFalse);
      final textRect = tester.getRect(find.text('Movimiento eliminado.'));
      expect(textRect.left, greaterThan(20));
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      expect(find.text('Movimiento eliminado.'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

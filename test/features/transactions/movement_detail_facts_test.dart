import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
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
    'detalle conserva cuenta canal y nota como hechos del movimiento',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final account = await container
          .read(accountsServiceProvider)
          .createAccount(
            const CreateAccountDraft(name: 'Caja', type: AccountType.cash),
          );
      await container
          .read(ledgerServiceProvider)
          .create(
            TransactionDraft(
              type: TransactionType.income,
              amount: const Money(10000),
              occurredAt: DateTime.now(),
              toAccountId: account,
              description: 'Cobro',
              note: 'Referencia 42',
              paymentChannel: PaymentChannel.cash,
            ),
          );
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: TransactionsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cobro'));
      await tester.pumpAndSettle();
      expect(find.text('Cuenta'), findsOneWidget);
      expect(find.text('Canal'), findsOneWidget);
      expect(find.text('Nota'), findsOneWidget);
      expect(find.text('Referencia 42'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}

import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/accounts/presentation/accounts_screen.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'tarjeta archivada sin fila de saldo muestra límite y fechas; solo el crédito disponible queda «—»',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final service = AccountsService(db);
      final card = await tester.runAsync(() async {
        final id = await service.createAccount(
          const CreateAccountDraft(
            name: 'Visa vieja',
            type: AccountType.creditCard,
            creditLimitMinor: 1000000,
            closingDay: 10,
            dueDay: 25,
          ),
        );
        await service.setArchived(id, true);
        return id;
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            accountBalancesProvider.overrideWith(
              (ref) => Stream.value(const <AccountBalance>[]),
            ),
          ],
          child: MaterialApp(home: AccountsScreen(accountId: card)),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)),
        );
        await tester.pump();
      }

      expect(find.text('Límite'), findsOneWidget);
      expect(find.textContaining('Próximo cierre:'), findsOneWidget);
      expect(find.textContaining('Vencimiento estimado:'), findsOneWidget);
      expect(find.text('Crédito disponible'), findsOneWidget);
      expect(
        find.descendant(
          of: find.widgetWithText(ListTile, 'Crédito disponible'),
          matching: find.text('—'),
        ),
        findsOneWidget,
      );
      expect(find.text('—'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
    },
  );

  testWidgets('con saldos fallidos el error de saldo aparece una sola vez', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final card = await tester.runAsync(
      () => AccountsService(db).createAccount(
        const CreateAccountDraft(
          name: 'Visa',
          type: AccountType.creditCard,
          creditLimitMinor: 1000000,
          closingDay: 10,
          dueDay: 25,
        ),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          accountBalancesProvider.overrideWith(
            (ref) => Stream.error(Exception('falla')),
          ),
        ],
        child: MaterialApp(home: AccountsScreen(accountId: card)),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
    }

    expect(find.text('No se pudo cargar el saldo.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_repository.dart';
import 'package:finanzas_locales/features/transactions/presentation/transactions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'chip de cuenta muestra el nombre y al quitarlo limpia el filtro',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime(2026, 10, 4);
      final accounts = [
        AccountRecord(
          id: 'acc1',
          name: 'Banco Central',
          type: 'bank',
          currencyCode: 'PYG',
          initialBalanceMinor: 0,
          color: 0xFF175C4C,
          icon: 'account_balance',
          isArchived: false,
          includeInNetWorth: true,
          includeInAvailableMoney: true,
          sortOrder: 0,
          createdAt: now,
          updatedAt: now,
        ),
      ];
      final accountFilters = <String?>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allAccountsProvider.overrideWith((ref) => Stream.value(accounts)),
            movementHistoryProvider.overrideWith((ref, request) {
              accountFilters.add(request.filter.account);
              return Stream.value(const <MovementRow>[]);
            }),
          ],
          child: const MaterialApp(home: TransactionsScreen(account: 'acc1')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Banco Central'), findsOneWidget);
      expect(accountFilters.last, 'acc1');

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(InputChip, 'Banco Central'),
          matching: find.byType(Icon),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Banco Central'), findsNothing);
      expect(accountFilters.last, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}

import 'dart:async';

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

  testWidgets('chip «Del reporte» se quita de a uno', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final reportFlags = <bool>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          movementHistoryProvider.overrideWith((ref, request) {
            reportFlags.add(request.reportOnly);
            return Stream.value(const <MovementRow>[]);
          }),
        ],
        child: const MaterialApp(home: TransactionsScreen(reportOnly: true)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InputChip, 'Del reporte'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(InputChip, 'Del reporte'),
        matching: find.byType(Icon),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(InputChip, 'Del reporte'), findsNothing);
    expect(reportFlags.last, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('período con solo inicio muestra «Desde» y se quita', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final starts = <DateTime?>[];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          movementHistoryProvider.overrideWith((ref, request) {
            starts.add(request.filter.start);
            return Stream.value(const <MovementRow>[]);
          }),
        ],
        child: MaterialApp(
          home: TransactionsScreen(start: DateTime(2026, 10, 1)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Desde'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(
          InputChip,
          'Desde ${MaterialLocalizations.of(tester.element(find.byType(TransactionsScreen))).formatShortDate(DateTime(2026, 10, 1))}',
        ),
        matching: find.byType(Icon),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Desde'), findsNothing);
    expect(starts.last, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mientras llega un filtro nuevo, las filas anteriores no admiten toques',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime(2026, 10, 4);
      final row = MovementRow(
        TransactionRecord(
          id: 'a',
          type: 'expense',
          status: 'confirmed',
          source: 'manual',
          occurredAt: now,
          occurredTimeZone: 'America/Asuncion',
          createdAt: now,
          updatedAt: now,
          currencyCode: 'PYG',
          amountMinor: 1000,
          description: 'Movimiento previo',
          note: '',
          paymentChannel: 'cash',
        ),
      );
      final pending = StreamController<List<MovementRow>>();
      addTearDown(pending.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            movementHistoryProvider.overrideWith((ref, request) {
              if (request.filter.search.isEmpty) {
                return Stream.value([row]);
              }
              return pending.stream;
            }),
          ],
          child: const MaterialApp(home: TransactionsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Movimiento previo'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Buscar comercio o nota'),
        'x',
      );
      await tester.pump();

      expect(find.text('Movimiento previo'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is IgnorePointer && w.ignoring),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/app/router.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_repository.dart';
import 'package:finanzas_locales/features/transactions/presentation/history_link.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'el atajo abre la pestaña Movimientos con el filtro y repetirlo lo vuelve a aplicar',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime(2026, 10, 4);
      final account = AccountRecord(
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
      );
      final accountFilters = <String?>[];
      final router = GoRouter(
        initialLocation: '/accounts',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (context, state, shell) => Scaffold(
              body: shell,
              bottomNavigationBar: Text('rama ${shell.currentIndex}'),
            ),
            branches: [
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/transactions',
                    builder: transactionsRouteBuilder,
                  ),
                ],
              ),
              StatefulShellBranch(
                routes: [
                  GoRoute(
                    path: '/accounts',
                    builder: (context, state) => Center(
                      child: TextButton(
                        onPressed: () =>
                            openHistory(context, {'account': 'acc1'}),
                        child: const Text('Ver movimientos'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            allAccountsProvider.overrideWith((ref) => Stream.value([account])),
            movementHistoryProvider.overrideWith((ref, request) {
              accountFilters.add(request.filter.account);
              return Stream.value(const <MovementRow>[]);
            }),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Ver movimientos'));
      await tester.pumpAndSettle();
      expect(find.text('rama 0'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'Banco Central'), findsOneWidget);
      expect(accountFilters.last, 'acc1');

      await tester.tap(
        find.descendant(
          of: find.widgetWithText(InputChip, 'Banco Central'),
          matching: find.byType(Icon),
        ),
      );
      await tester.pumpAndSettle();
      expect(accountFilters.last, isNull);

      router.go('/accounts');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ver movimientos'));
      await tester.pumpAndSettle();
      expect(find.text('rama 0'), findsOneWidget);
      expect(find.widgetWithText(InputChip, 'Banco Central'), findsOneWidget);
      expect(accountFilters.last, 'acc1');
      expect(tester.takeException(), isNull);
    },
  );
}

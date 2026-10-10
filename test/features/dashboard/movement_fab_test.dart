import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/app/theme/app_theme.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/dashboard/presentation/dashboard_screen.dart';
import 'package:finanzas_locales/features/transactions/presentation/transactions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  for (final history in [false, true]) {
    testWidgets(
      'P01/F01/F07: tres altas flotantes, cancelar y volver, historial=$history',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => history
                  ? const TransactionsScreen()
                  : const DashboardScreen(),
            ),
            GoRoute(
              path: '/transactions/new',
              builder: (_, state) => Scaffold(
                appBar: AppBar(title: const Text('Formulario ficticio')),
                body: Text(state.uri.queryParameters['type']!),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.dark(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byTooltip('Nuevo movimiento'), findsOneWidget);
        await tester.tap(find.byTooltip('Nuevo movimiento'));
        await tester.pumpAndSettle();
        expect(
          find.widgetWithText(FloatingActionButton, 'Gasto'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(FloatingActionButton, 'Ingreso'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(FloatingActionButton, 'Transferir'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        // Android back closes the menu before leaving the screen.
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byTooltip('Nuevo movimiento'), findsOneWidget);
        for (final pair in [
          ('Gasto', 'expense'),
          ('Ingreso', 'income'),
          ('Transferir', 'transfer'),
        ]) {
          await tester.tap(find.byTooltip('Nuevo movimiento'));
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FloatingActionButton, pair.$1));
          await tester.pumpAndSettle();
          expect(find.text(pair.$2), findsOneWidget);
          router.pop();
          await tester.pumpAndSettle();
          expect(find.byTooltip('Nuevo movimiento'), findsOneWidget);
        }
        await tester.tap(find.byTooltip('Nuevo movimiento'));
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Nuevo movimiento'), findsOneWidget);
        await tester.tap(find.byTooltip('Nuevo movimiento'));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(20, 100));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Nuevo movimiento'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(await db.select(db.ledgerTransactions).get(), isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}

import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/dashboard/presentation/dashboard_screen.dart';
import 'package:finanzas_locales/features/payments/domain/pending_payment_models.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:finanzas_locales/shared/widgets/money_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final hasSavings in [false, true]) {
    testWidgets(
      'patrimonio incluye ahorros y descuenta deuda sin selector: ahorros=$hasSavings',
      (tester) async {
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            accountBalancesProvider.overrideWith(
              (ref) => Stream.value([
                const AccountBalance(
                  id: 'bank',
                  name: 'Banco',
                  type: AccountType.bank,
                  currencyCode: 'PYG',
                  balanceMinor: 100000,
                  includeInAvailableMoney: true,
                  includeInNetWorth: true,
                ),
                const AccountBalance(
                  id: 'credit',
                  name: 'Tarjeta',
                  type: AccountType.creditCard,
                  currencyCode: 'PYG',
                  balanceMinor: 20000,
                  includeInAvailableMoney: false,
                  includeInNetWorth: true,
                ),
                if (hasSavings)
                  const AccountBalance(
                    id: 'save',
                    name: 'Reserva',
                    type: AccountType.savings,
                    currencyCode: 'PYG',
                    balanceMinor: 50000,
                    includeInAvailableMoney: false,
                    includeInNetWorth: true,
                  ),
              ]),
            ),
            pendingCandidatesProvider.overrideWith((ref) => Stream.value([])),
          ],
        );
        await tester.runAsync(() async {
          await container
              .read(settingsProvider)
              .read('overview_include_savings');
        });
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: DashboardScreen()),
          ),
        );
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pumpAndSettle();
        final netTile = find.byKey(const ValueKey('overview-net-worth'));
        int netAmount() => tester
            .widget<MoneyText>(
              find.descendant(of: netTile, matching: find.byType(MoneyText)),
            )
            .minorUnits;
        expect(netAmount(), hasSavings ? 130000 : 80000);
        expect(find.text('Patrimonio total'), findsOneWidget);
        expect(find.text('Ver resumen'), findsNothing);
        expect(find.text('Incluir ahorros'), findsNothing);
        expect(find.text('Deuda de tarjetas'), findsNothing);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        await tester.runAsync(() async {
          container.dispose();
          await db.close();
        });
      },
    );
  }
  testWidgets('Inicio prioriza disponible y no duplica cuentas ni historial', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Disponible'), findsOneWidget);
    expect(find.text('Pendiente del mes'), findsOneWidget);
    expect(find.text('Próximos pagos'), findsOneWidget);
    expect(find.text('Cuentas'), findsNothing);
    expect(find.text('Últimos movimientos'), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byTooltip('Movimientos pendientes'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'Inicio muestra solo próximos dos y resta toda deuda al patrimonio',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final now = DateTime.now();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            accountBalancesProvider.overrideWith(
              (ref) => Stream.value([
                const AccountBalance(
                  id: 'bank',
                  name: 'Banco',
                  type: AccountType.bank,
                  currencyCode: 'PYG',
                  balanceMinor: 100000,
                  includeInAvailableMoney: true,
                  includeInNetWorth: true,
                ),
              ]),
            ),
            pendingPaymentsProvider.overrideWith(
              (ref) => Stream.value([
                for (final number in [3, 1, 2])
                  PendingPayment({
                    'id': '$number',
                    'amountMinor': 10000,
                    'payments': [],
                    'dueDate': DateTime(
                      now.year,
                      now.month,
                      number,
                    ).toIso8601String(),
                    'cancelled': false,
                    'description': 'Pago $number',
                  }),
              ]),
            ),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pago 1'), findsOneWidget);
      expect(find.text('Pago 2'), findsOneWidget);
      expect(find.text('Pago 3'), findsNothing);
      final net = find.descendant(
        of: find.byKey(const ValueKey('overview-net-worth')),
        matching: find.byType(MoneyText),
      );
      expect(tester.widget<MoneyText>(net).minorUnits, 70000);
      final available = find.descendant(
        of: find.byKey(const ValueKey('overview-available')),
        matching: find.byType(MoneyText),
      );
      expect(tester.widget<MoneyText>(available).minorUnits, 100000);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}

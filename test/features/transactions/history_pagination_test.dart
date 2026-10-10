import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/transactions/presentation/transactions_screen.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'cargar más permite recorrer más de cien movimientos sin duplicarlos',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requested = <int>[];
      final now = DateTime(2026, 10, 4);
      final rows = List.generate(
        125,
        (index) => TransactionRecord(
          id: '$index',
          type: 'expense',
          status: 'confirmed',
          source: 'manual',
          occurredAt: now,
          occurredTimeZone: 'America/Asuncion',
          createdAt: now,
          updatedAt: now,
          currencyCode: 'PYG',
          amountMinor: 1000,
          description: 'Movimiento $index',
          note: '',
          paymentChannel: 'cash',
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            movementHistoryProvider.overrideWith((ref, request) {
              final limit = request.limit;
              requested.add(limit);
              return Stream.value(
                rows.take(limit).map((r) => MovementRow(r)).toList(),
              );
            }),
          ],
          child: const MaterialApp(home: TransactionsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final more = find.text('Cargar 50 movimientos más');
      await tester.scrollUntilVisible(
        more,
        700,
        scrollable: find.byType(Scrollable).last,
      );
      await Scrollable.ensureVisible(tester.element(more), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        more,
        700,
        scrollable: find.byType(Scrollable).last,
      );
      await Scrollable.ensureVisible(tester.element(more), alignment: 0.5);
      await tester.pumpAndSettle();
      await tester.tap(more);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Movimiento 124'),
        700,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Movimiento 124'), findsOneWidget);
      expect(more, findsNothing);
      expect(requested, [51, 101, 151]);
      expect(tester.takeException(), isNull);
    },
  );
}

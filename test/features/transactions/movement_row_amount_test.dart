import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_repository.dart';
import 'package:finanzas_locales/features/transactions/presentation/transactions_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'fila de Movimientos muestra un importe grande completo a escala 2.0 sin desbordes',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime(2026, 10, 4);
      final row = TransactionRecord(
        id: 'big',
        type: 'expense',
        status: 'confirmed',
        source: 'manual',
        occurredAt: now,
        occurredTimeZone: 'America/Asuncion',
        createdAt: now,
        updatedAt: now,
        currencyCode: 'PYG',
        amountMinor: 1000000000,
        description: 'Compra grande',
        note: '',
        paymentChannel: 'cash',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            movementHistoryProvider.overrideWith(
              (ref, request) => Stream.value([MovementRow(row)]),
            ),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const TransactionsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final amount = find.textContaining('1.000.000.000');
      expect(amount, findsOneWidget);
      final fitted = find.ancestor(
        of: amount,
        matching: find.byType(FittedBox),
      );
      expect(fitted, findsOneWidget);
      // Escalado: el texto natural es más ancho que el área asignada.
      expect(
        tester.getSize(amount).width,
        greaterThan(tester.getSize(fitted).width),
      );
      expect(tester.getSize(fitted).width, lessThanOrEqualTo(360 * 0.4));
      expect(
        tester.widget<Text>(amount).overflow,
        isNot(TextOverflow.ellipsis),
      );
    },
  );
}

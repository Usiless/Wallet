import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/core/money/money.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/reports/data/report_service.dart';
import 'package:finanzas_locales/features/reports/presentation/reports_screen.dart';
import 'package:finanzas_locales/shared/widgets/money_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reporte separa pendiente del gasto real y del neto', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final data = ReportAnalysis(
      totals: const ReportTotals(
        income: 100000,
        expenses: 20000,
        refunds: 1000,
        pendingExpenses: 30000,
      ),
      previous: const ReportTotals(income: 0, expenses: 0, refunds: 0),
      previousStart: DateTime(2026, 9),
      previousEnd: DateTime(2026, 10),
      months: [],
      categories: [],
      merchants: [],
      accounts: [],
      expenseCount: 1,
      unclassifiedAmount: 0,
      unclassifiedCount: 0,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          reportAnalysisProvider.overrideWith(
            (ref, request) => Stream.value(data),
          ),
        ],
        child: const MaterialApp(home: ReportsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.text(const Money(30000).format()), findsOneWidget);
    final values = tester
        .widgetList<MoneyText>(find.byType(MoneyText))
        .map((v) => v.minorUnits);
    expect(values, containsAll([19000, 81000]));
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}

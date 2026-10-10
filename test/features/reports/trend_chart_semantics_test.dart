import 'package:finanzas_locales/core/money/money.dart';
import 'package:finanzas_locales/features/reports/data/report_service.dart';
import 'package:finanzas_locales/features/reports/presentation/trend_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('la etiqueta del gráfico nombra cada serie y su valor por mes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrendChart(
            months: [
              ReportMonth(
                DateTime(2026, 9),
                const ReportTotals(
                  income: 500000,
                  expenses: 300000,
                  refunds: 0,
                ),
              ),
              ReportMonth(
                DateTime(2026, 10),
                const ReportTotals(
                  income: 400000,
                  expenses: 250000,
                  refunds: 0,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final expense = RegExp.escape(Money(300000).format());
    final income = RegExp.escape(Money(500000).format());
    expect(
      find.bySemanticsLabel(RegExp(r'Gastos netos:.*Ingresos:')),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(RegExp('Gastos netos:.*$expense')),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('Ingresos:.*$income')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../data/report_service.dart';

const _expenseSeries = 'Gastos netos';
const _incomeSeries = 'Ingresos';

/// Texto accesible con el valor de cada serie por mes.
String _trendSummary(MaterialLocalizations loc, List<ReportMonth> months) {
  String line(String name, int Function(ReportMonth) pick) =>
      '$name: ${[for (final m in months) '${loc.formatMonthYear(m.month)} ${Money(pick(m)).format()}'].join(', ')}.';
  return '${line(_expenseSeries, (m) => m.totals.netExpenses)} '
      '${line(_incomeSeries, (m) => m.totals.income)}';
}

class TrendChart extends StatelessWidget {
  const TrendChart({required this.months, super.key});
  final List<ReportMonth> months;
  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) return const SizedBox();
    final values = [
      0,
      for (final month in months) ...[
        month.totals.income,
        month.totals.netExpenses,
      ],
    ];
    final low = values.reduce((a, b) => a < b ? a : b).toDouble(),
        high = values.reduce((a, b) => a > b ? a : b).toDouble();
    final padding = (high - low) == 0 ? 1.0 : (high - low) * .15;
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 20,
              children: [
                _legend(_expenseSeries, colors.error),
                _legend(_incomeSeries, colors.primary),
              ],
            ),
            const SizedBox(height: 20),
            Semantics(
              label: _trendSummary(MaterialLocalizations.of(context), months),
              excludeSemantics: true,
              child: SizedBox(
                height: 210,
                child: LineChart(
                  LineChartData(
                    minX: 0,
                    maxX: months.length == 1
                        ? 1
                        : (months.length - 1).toDouble(),
                    minY: low - padding,
                    maxY: high + padding,
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(
                      show: true,
                      drawVerticalLine: false,
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final index = value.round();
                            if (value != index.toDouble() ||
                                index < 0 ||
                                index >= months.length ||
                                months.length > 6 &&
                                    index != 0 &&
                                    index != months.length - 1 &&
                                    index % ((months.length / 5).ceil()) != 0) {
                              return const SizedBox();
                            }
                            final date = months[index].month;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${date.month}/${date.year % 100}',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    lineTouchData: LineTouchData(
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (spots) => spots
                            .map(
                              (spot) => LineTooltipItem(
                                '${spot.barIndex == 0 ? _expenseSeries : _incomeSeries}\n${Money(spot.y.round()).format()}',
                                TextStyle(
                                  color: spot.bar.color,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    lineBarsData: [
                      for (var series = 0; series < 2; series++)
                        LineChartBarData(
                          color: series == 0 ? colors.error : colors.primary,
                          barWidth: 3,
                          isCurved: false,
                          spots: [
                            for (var i = 0; i < months.length; i++)
                              FlSpot(
                                i.toDouble(),
                                (series == 0
                                        ? months[i].totals.netExpenses
                                        : months[i].totals.income)
                                    .toDouble(),
                              ),
                          ],
                          dotData: FlDotData(show: months.length <= 12),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(String label, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label),
    ],
  );
}

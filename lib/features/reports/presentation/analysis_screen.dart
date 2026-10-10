import 'package:flutter/material.dart';

import '../../budgets/presentation/budgets_screen.dart';
import 'reports_screen.dart';

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({this.reports = false, super.key});
  final bool reports;
  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  late bool _reports = widget.reports;
  @override
  void didUpdateWidget(covariant AnalysisScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reports != widget.reports) {
      _reports = widget.reports;
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final labelStyle = Theme.of(context).textTheme.labelLarge!;
      final textScaler = MediaQuery.textScalerOf(context);
      final labelWidth = ((constraints.maxWidth - 32) / 2 - 32).clamp(
        1.0,
        double.infinity,
      );
      var segmentHeight = 48.0;
      for (final label in ['Presupuestos', 'Reportes']) {
        final painter = TextPainter(
          text: TextSpan(text: label, style: labelStyle),
          textDirection: Directionality.of(context),
          textScaler: textScaler,
        )..layout(maxWidth: labelWidth);
        if (painter.height + 24 > segmentHeight) {
          segmentHeight = painter.height + 24;
        }
        painter.dispose();
      }
      final tabs = PreferredSize(
        preferredSize: Size.fromHeight(segmentHeight + 12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              style: SegmentedButton.styleFrom(
                textStyle: labelStyle,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                fixedSize: Size.fromHeight(segmentHeight),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.standard,
              ),
              segments: const [
                ButtonSegment(value: false, label: Text('Presupuestos')),
                ButtonSegment(value: true, label: Text('Reportes')),
              ],
              selected: {_reports},
              onSelectionChanged: (v) => setState(() => _reports = v.first),
              showSelectedIcon: false,
            ),
          ),
        ),
      );
      return IndexedStack(
        index: _reports ? 1 : 0,
        children: [
          BudgetsScreen(navigation: tabs),
          ReportsScreen(navigation: tabs),
        ],
      );
    },
  );
}

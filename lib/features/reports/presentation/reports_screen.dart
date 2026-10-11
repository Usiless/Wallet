import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../shared/widgets/money_text.dart';
import '../data/report_service.dart';
import 'trend_chart.dart';
import '../../transactions/presentation/history_link.dart';

final reportAnalysisProvider = StreamProvider.autoDispose
    .family<ReportAnalysis, AnalysisRequest>(
      (ref, request) =>
          ReportService(ref.watch(databaseProvider)).watchAnalysis(request),
    );

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({this.navigation, super.key});
  final PreferredSizeWidget? navigation;
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime _start = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _end = DateTime(DateTime.now().year, DateTime.now().month + 1);
  static const _quotas = true;
  String? _category, _account;
  int _view = 0;
  final _scroll = ScrollController();
  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _month(int step) => setState(() {
    _start = DateTime(_start.year, _start.month + step);
    _end = DateTime(_start.year, _start.month + 1);
  });
  ReportRequest get _request => (
    start: _start,
    end: _end,
    category: _category,
    monthlyInstallments: _quotas,
  );
  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(allCategoriesProvider),
        accountsAsync = ref.watch(allAccountsProvider);
    final categories = categoriesAsync.value ?? [],
        accounts = accountsAsync.value ?? [];
    if (!categoriesAsync.isLoading &&
        _category != null &&
        !categories.any((c) => c.id == _category)) {
      _category = null;
    }
    if (!accountsAsync.isLoading &&
        _account != null &&
        !accounts.any((a) => a.id == _account)) {
      _account = null;
    }
    final analysis = ref.watch(
      reportAnalysisProvider((period: _request, account: _account)),
    );
    final month =
        _start.day == 1 && _end == DateTime(_start.year, _start.month + 1);
    final loc = MaterialLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        bottom: widget.navigation,
        actions: [
          IconButton(
            tooltip: 'Ver movimientos del reporte',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => _details('all', null),
          ),
        ],
      ),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Mes anterior',
                onPressed: () => _month(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: TextButton(
                  onPressed: _period,
                  child: Text(
                    month
                        ? loc.formatMonthYear(_start)
                        : '${loc.formatShortDate(_start)} – ${loc.formatShortDate(_end.subtract(const Duration(days: 1)))}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Mes siguiente',
                onPressed: () => _month(1),
                icon: const Icon(Icons.chevron_right),
              ),
              IconButton(
                tooltip: _account != null || _category != null
                    ? 'Filtros aplicados'
                    : 'Filtros del reporte',
                onPressed: _filters,
                icon: const Icon(Icons.filter_list),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            isExpanded: true,
            itemHeight: null,
            initialValue: _view,
            decoration: const InputDecoration(labelText: 'Vista del reporte'),
            items: [
              for (final e in [
                'Resumen',
                'Evolución',
                'Categorías',
                'Comercios',
                'Cuentas',
              ].indexed)
                DropdownMenuItem(value: e.$1, child: Text(e.$2)),
            ],
            onChanged: (v) => setState(() => _view = v ?? 0),
          ),
          const SizedBox(height: 16),
          ...analysis.when(
            loading: () => [const LinearProgressIndicator()],
            error: (_, _) => [const Text('No se pudo calcular el reporte.')],
            data: (a) => switch (_view) {
              1 => _evolution(a),
              2 => _ranking(
                a.categories,
                a.totals.expenses,
                'Gastos por categoría',
                'category',
              ),
              3 => _ranking(
                a.merchants,
                a.totals.expenses,
                'Gastos por comercio',
                'merchant',
              ),
              4 => _ranking(
                a.accounts,
                a.totals.expenses,
                'Movimientos por cuenta',
                'account',
              ),
              _ => _summary(a),
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _summary(ReportAnalysis a) => [
    Table(
      columnWidths: const {0: FlexColumnWidth(), 1: FlexColumnWidth(2)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Concepto'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Importe · vs. ${MaterialLocalizations.of(context).formatMonthYear(a.previousStart)}',
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        _summaryRow('Ingresos', a.totals.income, a.previous.income),
        _summaryRow(
          'Gastos netos',
          a.totals.netExpenses,
          a.previous.netExpenses,
        ),
        TableRow(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Neto',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Align(
                alignment: Alignment.centerRight,
                child: Semantics(
                  label:
                      'Ingresos menos gastos; no representa saldo de cuentas',
                  child: MoneyText(
                    a.totals.balance,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
    _amountRow('Pendiente', a.pendingMinor),
    ExpansionTile(
      title: const Text('Detalle del gasto'),
      tilePadding: EdgeInsets.zero,
      children: [
        _amountRow('Gasto bruto', a.totals.expenses),
        _amountRow('Devoluciones', a.totals.refunds),
      ],
    ),
    if (a.totals.income == 0 &&
        a.totals.expenses == 0 &&
        a.totals.refunds == 0 &&
        a.pendingMinor == 0)
      const Padding(
        padding: EdgeInsets.all(24),
        child: Text('Sin movimientos en este período.'),
      ),
    if (a.unclassifiedAmount > 0)
      TextButton(
        onPressed: () => _details('unclassified', null),
        child: Text('${_purchases(a.unclassifiedCount)} sin categoría'),
      ),
  ];
  TableRow _summaryRow(String label, int amount, int previous) {
    final delta = amount - previous;
    final ratio = previous == 0 ? null : delta.abs() * 100 / previous.abs();
    final change = delta == 0
        ? '— 0%'
        : previous == 0
        ? 'Nuevo'
        : '${delta > 0 ? '↑' : '↓'} ${ratio! < 1 ? '<1' : ratio.round()}%';
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(label),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            children: [
              MoneyText(amount),
              Semantics(
                label: delta == 0
                    ? 'Sin cambios respecto al período anterior'
                    : '${delta > 0 ? 'Subió' : 'Bajó'} ${Money(delta.abs()).format()} respecto al período anterior',
                child: Text(
                  change,
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _filters() async {
    String? account = _account, category = _category;
    final accounts = ref.read(allAccountsProvider).value ?? [],
        categories = ref.read(allCategoriesProvider).value ?? [];
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('Filtros del reporte'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: account,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Cuenta'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Todas las cuentas'),
                  ),
                  for (final a in accounts)
                    DropdownMenuItem(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => account = v,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Todas las categorías'),
                  ),
                  for (final c in categories)
                    DropdownMenuItem(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => category = v,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      setState(() {
        _account = account;
        _category = category;
      });
    }
  }

  List<Widget> _evolution(ReportAnalysis a) => [
    _heading('Evolución mensual'),
    const SizedBox(height: 16),
    TrendChart(months: a.months),
    const SizedBox(height: 16),
    for (final m in a.months)
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                MaterialLocalizations.of(context).formatMonthYear(m.month),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              _amountRow('Gastos netos', m.totals.netExpenses),
              const SizedBox(height: 8),
              _amountRow('Ingresos', m.totals.income),
            ],
          ),
        ),
      ),
  ];
  List<Widget> _ranking(
    List<ReportGroup> rows,
    int total,
    String title,
    String kind,
  ) => [
    _heading(title),
    if (rows.isEmpty)
      const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'No hay datos para este reporte.',
          textAlign: TextAlign.center,
        ),
      ),
    for (final row in rows)
      Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _details(kind, row.id),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    MoneyText(row.totals.expenses),
                    if (total > 0)
                      Text(
                        '${_percent(row.totals.expenses * 100 / total)} del gasto',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: total <= 0
                      ? 0
                      : (row.totals.expenses / total).clamp(0.0, 1.0),
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 8),
                Text(_purchases(row.expenseCount)),
                if (row.totals.refunds > 0) ...[
                  const SizedBox(height: 12),
                  _amountRow('Devoluciones', row.totals.refunds),
                  const SizedBox(height: 8),
                  _amountRow('Gastos netos', row.totals.netExpenses),
                ],
                if (kind == 'account' && row.totals.income > 0) ...[
                  const SizedBox(height: 12),
                  _amountRow('Ingresos', row.totals.income),
                ],
              ],
            ),
          ),
        ),
      ),
  ];
  static String _purchases(int count) =>
      count == 1 ? '1 compra' : '$count compras';
  static String _percent(double value) =>
      '${NumberFormat.decimalPatternDigits(locale: 'es_PY', decimalDigits: 1).format(value)} %';
  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(text, style: Theme.of(context).textTheme.titleLarge),
  );
  Widget _amountRow(String label, int value) => LayoutBuilder(
    builder: (context, constraints) {
      final amount = Money(value).format();
      final style = Theme.of(context).textTheme.bodyMedium;
      final painter = TextPainter(
        text: TextSpan(text: amount, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final amountWidth = painter.width;
      painter.dispose();
      if (constraints.maxWidth - amountWidth < 112) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(amount, textAlign: TextAlign.right),
            ),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 16),
          Text(amount, textAlign: TextAlign.right),
        ],
      );
    },
  );
  void _details(String kind, String? id) {
    final parameters = <String, String>{
      'report': 'true',
      'start': _start.toIso8601String(),
      'end': _end.toIso8601String(),
      if (_quotas) 'quotaPeriod': 'true',
      'category': ?_category,
      'account': ?_account,
    };
    if (id != null) parameters[kind] = id;
    if (kind == 'merchant' || kind == 'category') {
      parameters['type'] = 'purchases';
    }
    if (kind == 'merchant') {
      if (id == null) parameters['withoutMerchant'] = 'true';
    }
    if (kind == 'unclassified') parameters['type'] = 'expense';
    if (kind == 'unclassified' || kind == 'category' && id == null) {
      parameters.remove('category');
      parameters['unclassified'] = 'true';
    }
    openHistory(context, parameters);
  }

  Future<void> _period() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: _start,
        end: _end.subtract(const Duration(days: 1)),
      ),
    );
    if (range != null && mounted) {
      setState(() {
        _start = range.start;
        _end = DateTime(range.end.year, range.end.month, range.end.day + 1);
      });
    }
  }
}

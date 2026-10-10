import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/errors/user_message.dart';
import '../../../core/money/money.dart';
import '../../../core/money/pyg_input_formatter.dart';
import '../../../shared/widgets/money_text.dart';
import '../domain/budget_service.dart';
import '../../../shared/widgets/app_fab.dart';
import 'budget_ring.dart';
import '../../../shared/widgets/app_snack.dart';

final class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({this.navigation, super.key});
  final PreferredSizeWidget? navigation;
  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  String? _prepareError;
  @override
  void initState() {
    super.initState();
    _prepareCurrent();
  }

  Future<void> _prepareCurrent() async {
    try {
      await ref.read(budgetServiceProvider).ensureCurrentMonth();
      if (mounted) setState(() => _prepareError = null);
    } catch (_) {
      if (mounted) {
        setState(
          () => _prepareError =
              'No se pudieron preparar los presupuestos mensuales.',
        );
      }
    }
  }

  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  void _move(int step) =>
      setState(() => _month = DateTime(_month.year, _month.month + step));
  @override
  Widget build(BuildContext context) {
    final service = ref.watch(budgetServiceProvider),
        loc = MaterialLocalizations.of(context);
    return Scaffold(
      floatingActionButton: AppFab(
        tooltip: 'Crear presupuesto',
        onPressed: _create,
        child: const Icon(Icons.add),
      ),
      appBar: widget.navigation == null
          ? null
          : AppBar(toolbarHeight: 0, bottom: widget.navigation),
      body: Column(
        children: [
          if (_prepareError != null)
            ListTile(
              title: Text(_prepareError!),
              trailing: TextButton(
                onPressed: _prepareCurrent,
                child: const Text('Reintentar'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Mes de presupuesto anterior',
                  onPressed: () => _move(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _month,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (d != null && mounted) {
                        setState(() => _month = DateTime(d.year, d.month));
                      }
                    },
                    child: Text(loc.formatMonthYear(_month)),
                  ),
                ),
                IconButton(
                  tooltip: 'Mes de presupuesto siguiente',
                  onPressed: () => _move(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => setState(
                    () => _month = DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                    ),
                  ),
                  child: const Text('Mes actual'),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<BudgetRecord>>(
              stream: service.watchBudgets(_month),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: const Text(
                      'No se pudieron cargar los presupuestos.',
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('Sin presupuestos este mes.'),
                  );
                }
                return LayoutBuilder(
                  builder: (context, c) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (final b in snapshot.data!)
                          SizedBox(
                            width:
                                c.maxWidth < 360 ||
                                    MediaQuery.textScalerOf(context).scale(16) >
                                        22
                                ? c.maxWidth - 32
                                : (c.maxWidth - 44) / 2,
                            child: StreamBuilder<BudgetWithProgress>(
                              stream: service.watchProgress(b),
                              builder: (context, p) {
                                if (p.hasError) {
                                  return const Text('No se pudo calcular.');
                                }
                                if (!p.hasData) {
                                  return const LinearProgressIndicator();
                                }
                                final consumed = p.data!.progress.consumedMinor;
                                final rounded = (consumed * 100 / b.targetMinor)
                                    .round();
                                final percent =
                                    consumed > b.targetMinor && rounded == 100
                                    ? 101
                                    : consumed < b.targetMinor && rounded == 100
                                    ? 99
                                    : rounded;
                                return Semantics(
                                  button: true,
                                  onTap: () => _detail(p.data!),
                                  label:
                                      '${b.name}: $percent% consumido. Pagado ${Money(p.data!.progress.paidMinor).format()}. Pendiente ${Money(p.data!.progress.pendingMinor).format()}. Ver detalle',
                                  excludeSemantics: true,
                                  child: Card(
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(16),
                                      onTap: () => _detail(p.data!),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          children: [
                                            Text(
                                              b.name,
                                              textAlign: TextAlign.center,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleSmall,
                                            ),
                                            const SizedBox(height: 16),
                                            SizedBox(
                                              width: 96,
                                              height: 96,
                                              child: CustomPaint(
                                                painter: BudgetRingPainter(
                                                  consumed / b.targetMinor,
                                                  Theme.of(context).colorScheme,
                                                  paidRatio:
                                                      p
                                                          .data!
                                                          .progress
                                                          .paidMinor /
                                                      b.targetMinor,
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    '$percent%',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleLarge,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _detail(BudgetWithProgress item) async {
    final budget = item.budget, month = budget.periodStart.toUtc();
    final category = ref
        .read(allCategoriesProvider)
        .value
        ?.where((c) => c.id == budget.categoryId)
        .firstOrNull
        ?.name;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(budget.name, style: Theme.of(sheet).textTheme.titleLarge),
              Text(category ?? 'Todas las categorías'),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Consumido'),
                trailing: MoneyText(item.progress.consumedMinor),
              ),
              ListTile(
                title: const Text('Pagado'),
                trailing: MoneyText(item.progress.paidMinor),
              ),
              ListTile(
                title: const Text('Pendiente'),
                trailing: MoneyText(item.progress.pendingMinor),
              ),
              ListTile(
                title: const Text('Objetivo'),
                trailing: MoneyText(budget.targetMinor),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(sheet);
                  context.push(
                    Uri(
                      path: '/transactions',
                      queryParameters: {
                        'start': DateTime(
                          month.year,
                          month.month,
                        ).toIso8601String(),
                        'end': DateTime(
                          month.year,
                          month.month + 1,
                        ).toIso8601String(),
                        'type': 'purchases',
                        if (budget.categoryId != null)
                          'category': budget.categoryId!,
                      },
                    ).toString(),
                  );
                },
                child: const Text('Ver movimientos'),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(sheet);
                  _edit(budget: budget);
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar presupuesto'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create() => _edit();
  Future<void> _edit({BudgetRecord? budget}) async {
    final generation = ref.read(databaseProvider).restoreGeneration;
    final service = ref.read(budgetServiceProvider);
    bool repeatMonthly = false;
    if (budget != null) {
      try {
        repeatMonthly = await service.repeatsMonthly(budget);
      } catch (_) {
        if (mounted) {
          showMessage(
            context,
            'No se pudo abrir la plantilla del presupuesto.',
          );
        }
        return;
      }
    }
    if (!mounted) return;
    final form = GlobalKey<FormState>(),
        name = TextEditingController(
          text: budget?.name ?? 'Presupuesto mensual',
        ),
        amount = TextEditingController(
          text: budget == null
              ? ''
              : Money(budget.targetMinor).format(withCode: false).trim(),
        );
    String? category = budget?.categoryId, error;
    bool busy = false;
    final categories = [
      ...ref.read(categoriesProvider).value ?? const <CategoryRecord>[],
    ];
    if (category != null && !categories.any((c) => c.id == category)) {
      final old = await ref.read(categoryServiceProvider).find(category);
      if (old != null) categories.add(old);
    }
    if (!mounted) return;
    final current = _month;
    await showDialog<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(
            budget == null
                ? 'Crear para ${MaterialLocalizations.of(context).formatMonthYear(current)}'
                : 'Editar presupuesto',
          ),
          content: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amount,
                    keyboardType: TextInputType.number,
                    inputFormatters: [PygInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Objetivo PYG',
                    ),
                    validator: (v) {
                      try {
                        if (Money.parse(v ?? '').minorUnits > 0) return null;
                      } catch (_) {}
                      return 'Ingresá un importe mayor que cero.';
                    },
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
                      for (final c in categories.where(
                        (c) => c.kind != 'income',
                      ))
                        DropdownMenuItem(value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) => category = v,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Repetir cada mes'),
                    value: repeatMonthly,
                    onChanged: busy
                        ? null
                        : (v) => update(() => repeatMonthly = v),
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(dialog),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      update(() => busy = true);
                      try {
                        if (budget == null) {
                          await service.create(
                            name: name.text,
                            month: current,
                            targetMinor: Money.parse(amount.text).minorUnits,
                            categoryId: category,
                            repeatMonthly: repeatMonthly,
                            expectedBookGeneration: generation,
                          );
                        } else {
                          await service.edit(
                            budget,
                            name: name.text,
                            targetMinor: Money.parse(amount.text).minorUnits,
                            categoryId: category,
                            repeatMonthly: repeatMonthly,
                            expectedBookGeneration: generation,
                          );
                        }
                        if (dialog.mounted) Navigator.pop(dialog);
                      } catch (e) {
                        if (dialog.mounted) {
                          update(() {
                            busy = false;
                            error = userMessage(e);
                          });
                        }
                      }
                    },
              child: Text(budget == null ? 'Crear' : 'Guardar'),
            ),
          ],
        ),
      ),
    );
    // Dialog route may still animate while its controllers are referenced.
  }
}

/// Ordered arcs share one radius and expand their scale above the target.

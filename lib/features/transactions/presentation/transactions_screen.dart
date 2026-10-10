import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../data/ledger_repository.dart';
import 'ledger_actions.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/movement_fab.dart';
import 'movement_detail.dart';

final class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({
    this.account,
    this.merchant,
    this.category,
    this.start,
    this.end,
    this.quotaPeriod = false,
    this.unclassified = false,
    this.reportOnly = false,
    this.withoutMerchant = false,
    this.type,
    super.key,
  });
  final String? account;
  final String? merchant;
  final String? category;
  final DateTime? start, end;
  final bool quotaPeriod, unclassified, reportOnly, withoutMerchant;
  final String? type;

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  var _limit = 50;
  HistoryFilter _filter = emptyHistoryFilter;
  final _search = TextEditingController();
  bool _quotaPeriod = false,
      _unclassified = false,
      _reportOnly = false,
      _withoutMerchant = false;
  @override
  void initState() {
    super.initState();
    _quotaPeriod = widget.quotaPeriod;
    _unclassified = widget.unclassified;
    _reportOnly = widget.reportOnly;
    _withoutMerchant = widget.withoutMerchant;
    _filter = (
      search: '',
      account: widget.account,
      merchant: widget.merchant,
      category: widget.category,
      type: widget.type,
      start: widget.start,
      end: widget.end,
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _setFilter(HistoryFilter filter) {
    setState(() {
      _filter = filter;
      _limit = 50;
      _previousRows = [];
    });
  }

  List<MovementRow> _previousRows = [];

  @override
  Widget build(BuildContext context) {
    final transactions = ref.watch(
      movementHistoryProvider((
        filter: _filter,
        limit: _limit + 1,
        unclassified: _unclassified,
        reportOnly: _reportOnly,
        withoutMerchant: _withoutMerchant,
      )),
    );
    if (transactions.hasValue) _previousRows = transactions.value!;
    final display = transactions.isLoading && _previousRows.isNotEmpty
        ? AsyncData(_previousRows)
        : transactions;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: 'Filtrar movimientos',
            onPressed: _filters,
            icon: const Icon(Icons.filter_list),
          ),
          IconButton(
            tooltip: 'Plantillas',
            onPressed: () => context.push('/templates'),
            icon: const Icon(Icons.bookmark_outline),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                labelText: 'Buscar comercio o nota',
                prefixIcon: const Icon(Icons.search),
                suffixIcon:
                    _filter != emptyHistoryFilter ||
                        _quotaPeriod ||
                        _unclassified ||
                        _reportOnly ||
                        _withoutMerchant
                    ? IconButton(
                        tooltip: 'Limpiar filtros',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          _quotaPeriod = false;
                          _unclassified = false;
                          _reportOnly = false;
                          _withoutMerchant = false;
                          _setFilter(emptyHistoryFilter);
                        },
                      )
                    : null,
              ),
              onChanged: (value) => _setFilter((
                search: value,
                account: _filter.account,
                merchant: _filter.merchant,
                category: _filter.category,
                type: _filter.type,
                start: _filter.start,
                end: _filter.end,
              )),
            ),
          ),
          if (_unclassified || _withoutMerchant)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(
                [
                  if (_unclassified) 'Sin categoría.',
                  if (_withoutMerchant) 'Sin comercio asociado.',
                ].join(' '),
              ),
            ),
          Expanded(
            child: AsyncValueView(
              value: display,
              data: (rows) {
                if (rows.isEmpty) {
                  return const Center(
                    child: Text('No hay movimientos para mostrar.'),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: rows.length > _limit ? _limit + 1 : rows.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    if (index == _limit) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: transactions.isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : OutlinedButton(
                                onPressed: () => setState(() => _limit += 50),
                                child: const Text('Cargar 50 movimientos más'),
                              ),
                      );
                    }
                    return _MovementTile(
                      row: rows[index].transaction,
                      movement: rows[index],
                      onDetail: () =>
                          showMovementDetail(context, ref, rows[index]),
                      onRefund: () => showRefundDialog(
                        context,
                        ref,
                        rows[index].transaction,
                      ),
                      onEdit: () => context.push(
                        '/transactions/new?edit=${rows[index].transaction.id}',
                      ),
                      onDelete: () =>
                          _delete(context, ref, rows[index].transaction),
                      onClone: () => context.push(
                        '/transactions/new?clone=${rows[index].transaction.id}',
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: const MovementFab(),
    );
  }

  Future<void> _filters() async {
    final accounts = await ref
        .read(accountsServiceProvider)
        .getAccounts(includeArchived: true);
    final merchants = await ref
        .read(merchantServiceProvider)
        .listMerchants(includeArchived: true);
    final categories = await ref
        .read(categoryServiceProvider)
        .list(includeArchived: true);
    if (!mounted) return;
    String? account = _filter.account,
        merchant = _filter.merchant,
        category = _filter.category,
        type = _filter.type;
    DateTime? start = _filter.start, end = _filter.end;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Filtrar movimientos'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _filterField('Cuenta', account, {
                  for (final a in accounts) a.id: a.name,
                }, (v) => account = v),
                const SizedBox(height: 12),
                _filterField('Comercio', merchant, {
                  for (final m in merchants) m.id: m.name,
                }, (v) => merchant = v),
                const SizedBox(height: 12),
                _filterField('Categoría', category, {
                  for (final c in categories) c.id: c.name,
                }, (v) => category = v),
                const SizedBox(height: 12),
                _filterField('Tipo', type, {
                  'purchases': 'Compras y devoluciones',
                  'expense': 'Gasto',
                  'income': 'Ingreso',
                  'transfer': 'Transferencia',
                  'refund': 'Devolución',
                  'adjustment': 'Ajuste',
                }, (v) => type = v),
                ListTile(
                  title: const Text('Período'),
                  subtitle: Text(
                    start == null
                        ? 'Todo el historial'
                        : '${MaterialLocalizations.of(context).formatShortDate(start!)} – ${MaterialLocalizations.of(context).formatShortDate(end!.subtract(const Duration(days: 1)))}',
                  ),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                      initialDateRange: start == null
                          ? null
                          : DateTimeRange(
                              start: start!,
                              end: end!.subtract(const Duration(days: 1)),
                            ),
                    );
                    if (range != null && context.mounted) {
                      update(() {
                        start = range.start;
                        end = DateTime(
                          range.end.year,
                          range.end.month,
                          range.end.day + 1,
                        );
                      });
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && mounted) {
      _setFilter((
        search: _search.text,
        account: account,
        merchant: merchant,
        category: category,
        type: type,
        start: start,
        end: end,
      ));
    }
  }

  Widget _filterField(
    String label,
    String? value,
    Map<String, String> choices,
    ValueChanged<String?> onChanged,
  ) => DropdownButtonFormField<String>(
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      const DropdownMenuItem<String>(value: null, child: Text('Todos')),
      for (final e in choices.entries)
        DropdownMenuItem(value: e.key, child: Text(e.value)),
    ],
    onChanged: onChanged,
  );

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TransactionRecord row,
  ) async {
    final ledger = ref.read(ledgerServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ledger.softDelete(row.id);
    } catch (error) {
      if (messenger.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('$error')));
      }
      return;
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Movimiento eliminado.'),
        duration: const Duration(seconds: 8),
        persist: false,
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () async {
            try {
              await ledger.restore(row.id);
            } catch (error) {
              if (messenger.mounted) {
                messenger.showSnackBar(SnackBar(content: Text('$error')));
              }
            }
          },
        ),
      ),
    );
  }
}

final class _MovementTile extends StatelessWidget {
  const _MovementTile({
    required this.row,
    required this.onDelete,
    required this.onClone,
    required this.onEdit,
    required this.onRefund,
    required this.movement,
    required this.onDetail,
  });

  final TransactionRecord row;
  final MovementRow movement;
  final VoidCallback onDetail;
  final VoidCallback onDelete;
  final VoidCallback onClone;
  final VoidCallback onEdit;
  final VoidCallback onRefund;

  @override
  Widget build(BuildContext context) {
    final signed = row.type == 'expense'
        ? -movement.amountMinor
        : row.type == 'income' || row.type == 'refund'
        ? movement.amountMinor
        : 0;
    return ListTile(
      onTap: onDetail,
      leading: CircleAvatar(child: Icon(_icon(row.type))),
      title: Text(row.description.isEmpty ? _label(row.type) : row.description),
      subtitle: Text(
        '${row.note == 'Registrado automáticamente' ? 'Automático · ' : ''}${movement.isQuota ? 'Cuota ${movement.number}/${movement.count}' : _label(row.type)} · ${movement.occurredAt.day}/${movement.occurredAt.month}/${movement.occurredAt.year}${movement.planned ? ' · Prevista' : ''}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MoneyText(
            signed == 0 ? movement.amountMinor : signed,
            currencyCode: row.currencyCode,
            signed: signed != 0,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'refund') {
                onRefund();
              } else if (value == 'edit') {
                onEdit();
              } else if (value == 'clone') {
                onClone();
              } else {
                onDelete();
              }
            },
            itemBuilder: (context) => [
              if (['income', 'expense', 'transfer'].contains(row.type))
                PopupMenuItem(
                  value: 'edit',
                  child: Text(movement.isQuota ? 'Editar compra' : 'Editar'),
                ),
              if (row.type == 'expense' && !movement.isQuota)
                const PopupMenuItem(
                  value: 'refund',
                  child: Text('Registrar devolución'),
                ),
              if (['income', 'expense', 'transfer'].contains(row.type))
                const PopupMenuItem(value: 'clone', child: Text('Clonar')),
              if (!movement.isQuota)
                const PopupMenuItem(value: 'delete', child: Text('Eliminar')),
            ],
          ),
        ],
      ),
    );
  }

  IconData _icon(String type) => switch (type) {
    'expense' => Icons.south_west,
    'income' => Icons.north_east,
    'transfer' => Icons.swap_horiz,
    'refund' => Icons.replay,
    _ => Icons.tune,
  };

  String _label(String type) => switch (type) {
    'expense' => 'Gasto',
    'income' => 'Ingreso',
    'transfer' => 'Transferencia',
    'refund' => 'Reembolso',
    _ => 'Ajuste',
  };
}

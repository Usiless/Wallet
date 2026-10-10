import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../data/ledger_repository.dart';

const filterTypeLabels = {
  'purchases': 'Compras y devoluciones',
  'expense': 'Gasto',
  'income': 'Ingreso',
  'transfer': 'Transferencia',
  'refund': 'Devolución',
  'adjustment': 'Ajuste',
};

/// Filtros que se muestran como chip y se quitan de a uno.
enum FilterKind {
  account,
  merchant,
  category,
  type,
  period,
  unclassified,
  withoutMerchant,
}

/// Chips de los filtros activos con el nombre legible de cada uno.
final class ActiveFilterChips extends ConsumerWidget {
  const ActiveFilterChips({
    required this.filter,
    required this.unclassified,
    required this.withoutMerchant,
    required this.onRemove,
    super.key,
  });

  final HistoryFilter filter;
  final bool unclassified, withoutMerchant;
  final ValueChanged<FilterKind> onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts =
        ref.watch(allAccountsProvider).value ?? const <AccountRecord>[];
    final categories =
        ref.watch(allCategoriesProvider).value ?? const <CategoryRecord>[];
    final merchants =
        ref.watch(merchantsProvider).value ?? const <MerchantRecord>[];
    final start = filter.start, end = filter.end;
    final localizations = MaterialLocalizations.of(context);
    final chips = [
      if (filter.account case final id?)
        (
          FilterKind.account,
          accounts.where((a) => a.id == id).firstOrNull?.name ?? 'Cuenta',
        ),
      if (filter.merchant case final id?)
        (
          FilterKind.merchant,
          merchants.where((m) => m.id == id).firstOrNull?.name ?? 'Comercio',
        ),
      if (filter.category case final id?)
        (
          FilterKind.category,
          categories.where((c) => c.id == id).firstOrNull?.name ?? 'Categoría',
        ),
      if (filter.type case final type?)
        (FilterKind.type, filterTypeLabels[type] ?? 'Tipo'),
      if (start != null && end != null)
        (
          FilterKind.period,
          '${localizations.formatShortDate(start)} – '
              '${localizations.formatShortDate(end.subtract(const Duration(days: 1)))}',
        ),
      if (unclassified) (FilterKind.unclassified, 'Sin categoría'),
      if (withoutMerchant) (FilterKind.withoutMerchant, 'Sin comercio'),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final (kind, label) in chips)
            InputChip(label: Text(label), onDeleted: () => onRemove(kind)),
        ],
      ),
    );
  }
}

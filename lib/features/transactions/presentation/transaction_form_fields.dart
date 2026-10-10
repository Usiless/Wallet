import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/money/pyg_input_formatter.dart';
import '../domain/ledger_models.dart';
import 'transaction_form_state.dart';

final class AccountField extends StatelessWidget {
  const AccountField({
    required this.label,
    required this.value,
    required this.accounts,
    required this.onChanged,
    this.excludedId,
    super.key,
  });

  final String label;
  final String? value;
  final List<AccountRecord> accounts;
  final ValueChanged<String?> onChanged;
  final String? excludedId;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    key: ValueKey((
      label,
      value,
      excludedId,
      accounts.map((row) => row.id).join(','),
    )),
    initialValue: accounts.any((row) => row.id == value && row.id != excludedId)
        ? value
        : null,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final account in accounts.where(
        (account) => account.id != excludedId,
      ))
        DropdownMenuItem(value: account.id, child: Text(account.name)),
    ],
    onChanged: onChanged,
  );
}

final class CategoryDropdown extends StatelessWidget {
  const CategoryDropdown({
    required this.identity,
    required this.categories,
    required this.value,
    required this.onChanged,
    this.onCreate,
    this.expanded = false,
    super.key,
  });

  /// Cambia cuando debe reconstruirse el campo con otro valor inicial.
  final Object identity;
  final List<CategoryRecord> categories;
  final String? value;
  final ValueChanged<String?> onChanged;
  final VoidCallback? onCreate;
  final bool expanded;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    key: ValueKey((identity, categories.map((row) => row.id).join(','))),
    isExpanded: expanded,
    initialValue: categories.any((row) => row.id == value) ? value : null,
    decoration: InputDecoration(
      labelText: 'Categoría',
      suffixIcon: onCreate == null
          ? null
          : IconButton(
              tooltip: 'Crear categoría',
              onPressed: onCreate,
              icon: const Icon(Icons.add),
            ),
    ),
    items: [
      for (final category in categories)
        DropdownMenuItem(
          value: category.id,
          child: Text(category.name, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: onChanged,
  );
}

/// Una fila de la división: categoría e importe. El importe vive en su propio
/// campo y se copia al estado al escribir.
class SplitRow extends StatefulWidget {
  const SplitRow({
    required this.split,
    required this.type,
    required this.categories,
    required this.canRemove,
    required this.onCategory,
    required this.onAmount,
    required this.onRemove,
    super.key,
  });

  final SplitEntry split;
  final TransactionType type;
  final List<CategoryRecord> categories;
  final bool canRemove;
  final ValueChanged<String?> onCategory;
  final ValueChanged<String> onAmount;
  final VoidCallback onRemove;

  @override
  State<SplitRow> createState() => SplitRowState();
}

class SplitRowState extends State<SplitRow> {
  late final _amount = TextEditingController(text: widget.split.amountText);

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: CategoryDropdown(
            identity: (widget.split.id, widget.type, widget.split.categoryId),
            categories: widget.categories,
            value: widget.split.categoryId,
            expanded: true,
            onChanged: widget.onCategory,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: _amount,
            inputFormatters: [PygInputFormatter()],
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Importe'),
            onChanged: widget.onAmount,
          ),
        ),
        IconButton(
          tooltip: 'Quitar división',
          onPressed: widget.canRemove ? widget.onRemove : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
      ],
    ),
  );
}

/// Lo que falta asignar a las divisiones, o el excedente en rojo.
final class SplitRemaining extends StatelessWidget {
  const SplitRemaining({required this.remainingMinor, super.key});

  final int remainingMinor;

  @override
  Widget build(BuildContext context) {
    final excess = remainingMinor < 0;
    final color = excess
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        excess
            ? 'Excedente ${Money(-remainingMinor).format()}'
            : 'Restante ${Money(remainingMinor).format()}',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
      ),
    );
  }
}

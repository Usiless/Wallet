import 'package:flutter/material.dart';

import '../domain/ledger_models.dart';

/// Tipo del movimiento: desplegable en pantallas angostas con texto grande,
/// botones segmentados en el resto. Sin [onChanged] queda bloqueado.
final class TransactionTypeSelector extends StatelessWidget {
  const TransactionTypeSelector({
    required this.type,
    required this.onChanged,
    super.key,
  });

  final TransactionType type;
  final ValueChanged<TransactionType>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChange = onChanged;
    if (MediaQuery.sizeOf(context).width < 420 &&
        MediaQuery.textScalerOf(context).scale(14) > 20) {
      return DropdownButtonFormField<TransactionType>(
        initialValue: type,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Tipo'),
        items: const [
          DropdownMenuItem(
            value: TransactionType.expense,
            child: Text('Gasto'),
          ),
          DropdownMenuItem(
            value: TransactionType.income,
            child: Text('Ingreso'),
          ),
          DropdownMenuItem(
            value: TransactionType.transfer,
            child: Text('Transferir'),
          ),
        ],
        onChanged: onChange == null ? null : (value) => onChange(value ?? type),
      );
    }
    return SegmentedButton<TransactionType>(
      segments: const [
        ButtonSegment(
          value: TransactionType.expense,
          label: Text('Gasto'),
          icon: Icon(Icons.south_west),
        ),
        ButtonSegment(
          value: TransactionType.income,
          label: Text('Ingreso'),
          icon: Icon(Icons.north_east),
        ),
        ButtonSegment(
          value: TransactionType.transfer,
          label: Text('Transferir'),
          icon: Icon(Icons.swap_horiz),
        ),
      ],
      selected: {type},
      onSelectionChanged: onChange == null
          ? null
          : (value) => onChange(value.first),
    );
  }
}

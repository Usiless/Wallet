import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/widgets/money_text.dart';
import '../data/ledger_repository.dart';

final class MovementTile extends StatelessWidget {
  const MovementTile({
    required this.row,
    required this.onDelete,
    required this.onClone,
    required this.onEdit,
    required this.onRefund,
    required this.movement,
    required this.onDetail,
    super.key,
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
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.sizeOf(context).width * 0.4,
            ),
            child: MoneyText(
              signed == 0 ? movement.amountMinor : signed,
              currencyCode: row.currencyCode,
              signed: signed != 0,
              fitWidth: true,
            ),
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

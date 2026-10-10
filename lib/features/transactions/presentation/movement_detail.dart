import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../data/ledger_repository.dart';
import 'ledger_actions.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/app_snack.dart';

Future<void> showMovementDetail(
  BuildContext context,
  WidgetRef ref,
  MovementRow movement,
) async {
  final row = movement.transaction;
  final ledger = ref.read(ledgerRepositoryProvider);
  final installments = await ledger.installmentsOf(row.id);
  final entries = installments?.entries ?? const <InstallmentEntryRecord>[];
  final accountRowsFuture = ref
      .read(accountsServiceProvider)
      .getAccounts(includeArchived: true);
  final categoriesFuture = ref
      .read(categoryServiceProvider)
      .list(includeArchived: true);
  final splitsFuture = ledger.splitsOf(row.id);
  final accountRows = await accountRowsFuture;
  final categories = await categoriesFuture;
  final splits = await splitsFuture;
  String accountName(String? id) =>
      accountRows.where((a) => a.id == id).firstOrNull?.name ?? '—';
  final categoryNames = splits
      .map(
        (split) =>
            categories
                .where((category) => category.id == split.categoryId)
                .firstOrNull
                ?.name ??
            'Categoría archivada',
      )
      .join(' / ');
  final channel = switch (row.paymentChannel) {
    'cash' => 'Efectivo',
    'physicalCard' => 'Tarjeta física',
    'debitCard' => 'Tarjeta de débito',
    'physicalCreditCard' => 'Tarjeta de crédito',
    'googleWalletContactless' => 'Google Wallet',
    'onlineCard' => 'Tarjeta online',
    'bankTransfer' => 'Transferencia bancaria',
    _ => 'Otro',
  };
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: FractionallySizedBox(
        heightFactor: .8,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              movement.isQuota
                  ? 'Cuota ${movement.number}/${movement.count}'
                  : (entries.isEmpty ? 'Movimiento' : 'Compra original'),
              style: Theme.of(sheet).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(row.description),
            MoneyText(
              movement.amountMinor,
              style: Theme.of(sheet).textTheme.headlineMedium,
            ),
            Text(
              '${MaterialLocalizations.of(sheet).formatShortDate(movement.occurredAt)}${movement.planned ? ' · Prevista' : ''}',
            ),
            const SizedBox(height: 24),
            _MovementFact(
              'Cuenta',
              accountName(row.fromAccountId ?? row.toAccountId),
            ),
            if (row.fromAccountId != null && row.toAccountId != null)
              _MovementFact('Destino', accountName(row.toAccountId)),
            if (splits.isNotEmpty) _MovementFact('Categoría', categoryNames),
            _MovementFact('Canal', channel),
            if (row.note.isNotEmpty) _MovementFact('Nota', row.note),
            if (entries.isNotEmpty) ...[
              const Divider(height: 32),
              ListTile(
                title: const Text('Compra original'),
                subtitle: Text(
                  MaterialLocalizations.of(sheet)
                      .formatShortDate(row.occurredAt.toLocal()),
                ),
                trailing: MoneyText(row.amountMinor),
              ),
              for (final entry in entries)
                ListTile(
                  title: Text(
                    'Cuota ${entry.installmentNumber}/${installments!.plan.installmentCount}',
                  ),
                  subtitle: Text(
                    MaterialLocalizations.of(sheet)
                        .formatShortDate(entry.periodStart.toUtc()),
                  ),
                  trailing: MoneyText(entry.amountMinor),
                ),
            ],
            if (['expense', 'income', 'transfer'].contains(row.type))
              FilledButton(
                onPressed: () {
                  Navigator.pop(sheet);
                  context.push('/transactions/new?edit=${row.id}');
                },
                child: Text(entries.isEmpty ? 'Editar' : 'Editar compra'),
              ),
            if (row.type == 'expense')
              OutlinedButton(
                onPressed: () {
                  Navigator.pop(sheet);
                  showRefundDialog(context, ref, row);
                },
                child: const Text('Registrar devolución'),
              ),
            if (['expense', 'income', 'transfer'].contains(row.type))
              TextButton(
                onPressed: () {
                  Navigator.pop(sheet);
                  context.push('/transactions/new?clone=${row.id}');
                },
                child: const Text('Clonar'),
              ),
            TextButton(
              onPressed: () async {
                final yes = await showDialog<bool>(
                  context: sheet,
                  builder: (dialog) => AlertDialog(
                    title: Text(
                      entries.isEmpty
                          ? 'Eliminar movimiento'
                          : 'Eliminar compra y sus cuotas',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialog, false),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialog, true),
                        child: const Text('Eliminar'),
                      ),
                    ],
                  ),
                );
                if (yes != true || !context.mounted) return;
                try {
                  final ledger = ref.read(ledgerServiceProvider);
                  await ledger.softDelete(row.id);
                  if (!sheet.mounted || !context.mounted) return;
                  Navigator.pop(sheet);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Movimiento eliminado.'),
                      action: SnackBarAction(
                        label: 'Deshacer',
                        onPressed: () async {
                          try {
                            await ledger.restore(row.id);
                          } catch (e) {
                            if (context.mounted) showError(context, e);
                          }
                        },
                      ),
                    ),
                  );
                } catch (e) {
                  if (sheet.mounted) {
                    ScaffoldMessenger.of(sheet)
                        .showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _MovementFact extends StatelessWidget {
  const _MovementFact(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 3,
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}

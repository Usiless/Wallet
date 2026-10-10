import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/money/pyg_input_formatter.dart';

Future<void> showRefundDialog(
  BuildContext context,
  WidgetRef ref,
  TransactionRecord purchase,
) async {
  final ledger = ref.read(ledgerServiceProvider);
  final amount = TextEditingController();
  final note = TextEditingController();
  DateTime date = DateTime.now();
  try {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Registrar devolución'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  purchase.description.isEmpty
                      ? 'Compra original'
                      : purchase.description,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [PygInputFormatter()],
                  decoration: const InputDecoration(labelText: 'Importe PYG'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(labelText: 'Nota'),
                ),
                ListTile(
                  title: const Text('Fecha de devolución'),
                  subtitle: Text(
                    MaterialLocalizations.of(context).formatShortDate(date),
                  ),
                  onTap: () async {
                    final chosen = await showDatePicker(
                      context: context,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (chosen != null && context.mounted) {
                      update(() => date = chosen);
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
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    await ledger.refund(
      purchaseId: purchase.id,
      amountMinor: Money.parse(amount.text).minorUnits,
      occurredAt: date,
      note: note.text,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Devolución registrada.')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  } finally {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    amount.dispose();
    note.dispose();
  }
}

Future<void> showReconcileDialog(
  BuildContext context,
  WidgetRef ref,
  AccountRecord account,
) async {
  final ledger = ref.read(ledgerServiceProvider);
  final target = TextEditingController();
  final note = TextEditingController();
  bool negative = false;
  try {
    final current = await ledger.balance(account.id);
    if (!context.mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text('Conciliar · ${account.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Saldo registrado: ${Money(current).format()}'),
                const SizedBox(height: 16),
                TextField(
                  controller: target,
                  keyboardType: TextInputType.number,
                  inputFormatters: [PygInputFormatter()],
                  decoration: InputDecoration(
                    labelText: account.type == 'creditCard'
                        ? 'Deuda real PYG'
                        : 'Saldo real PYG',
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: negative,
                  onChanged: (v) => update(() => negative = v ?? false),
                  title: Text(
                    account.type == 'creditCard'
                        ? 'Saldo a favor'
                        : 'Saldo negativo',
                  ),
                ),
                TextField(
                  controller: note,
                  decoration: const InputDecoration(
                    labelText: 'Motivo del ajuste',
                  ),
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
              child: const Text('Guardar ajuste'),
            ),
          ],
        ),
      ),
    );
    if (accepted != true) return;
    final raw = Money.parse(target.text).minorUnits;
    await ledger.reconcile(
      accountId: account.id,
      targetMinor: negative ? -raw : raw,
      expectedBalance: current,
      note: note.text,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saldo conciliado.')));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  } finally {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    target.dispose();
    note.dispose();
  }
}

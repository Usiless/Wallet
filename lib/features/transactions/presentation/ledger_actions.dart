import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/errors/user_message.dart';
import '../../../core/money/money.dart';
import '../../../core/money/pyg_input_formatter.dart';
import '../../../shared/widgets/app_snack.dart';
import '../data/ledger_service.dart';
import '../../../core/money/amount_validator.dart';

Future<void> showRefundDialog(
  BuildContext context,
  WidgetRef ref,
  TransactionRecord purchase,
) async {
  final refunded = await showDialog<bool>(
    context: context,
    builder: (_) => _RefundDialog(
      purchase: purchase,
      ledger: ref.read(ledgerServiceProvider),
    ),
  );
  if (refunded == true && context.mounted) {
    showMessage(context, 'Devolución registrada.');
  }
}

Future<void> showReconcileDialog(
  BuildContext context,
  WidgetRef ref,
  AccountRecord account,
) async {
  final ledger = ref.read(ledgerServiceProvider);
  try {
    final current = await ledger.balance(account.id);
    if (!context.mounted) return;
    final reconciled = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _ReconcileDialog(account: account, current: current, ledger: ledger),
    );
    if (reconciled == true && context.mounted) {
      showMessage(context, 'Saldo conciliado.');
    }
  } catch (error) {
    if (context.mounted) showError(context, error);
  }
}

/// Guarda dentro del diálogo: si falla, el error queda visible y los datos
/// siguen escritos.
final class _RefundDialog extends StatefulWidget {
  const _RefundDialog({required this.purchase, required this.ledger});

  final TransactionRecord purchase;
  final LedgerService ledger;

  @override
  State<_RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<_RefundDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.ledger.refund(
        purchaseId: widget.purchase.id,
        amountMinor: Money.parse(_amount.text).minorUnits,
        occurredAt: _date,
        note: _note.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = userMessage(error);
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final chosen = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (chosen != null && mounted) setState(() => _date = chosen);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Registrar devolución'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.purchase.description.isEmpty
                    ? 'Compra original'
                    : widget.purchase.description,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                inputFormatters: [PygInputFormatter()],
                decoration: const InputDecoration(labelText: 'Importe PYG'),
                validator: validateAmount,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Nota'),
              ),
              ListTile(
                title: const Text('Fecha de devolución'),
                subtitle: Text(
                  MaterialLocalizations.of(context).formatShortDate(_date),
                ),
                onTap: _saving ? null : _pickDate,
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Registrar'),
        ),
      ],
    ),
  );
}

/// Guarda el ajuste dentro del diálogo, con la misma regla de error que la
/// devolución.
final class _ReconcileDialog extends StatefulWidget {
  const _ReconcileDialog({
    required this.account,
    required this.current,
    required this.ledger,
  });

  final AccountRecord account;
  final int current;
  final LedgerService ledger;

  @override
  State<_ReconcileDialog> createState() => _ReconcileDialogState();
}

class _ReconcileDialogState extends State<_ReconcileDialog> {
  final _form = GlobalKey<FormState>();
  final _target = TextEditingController();
  final _note = TextEditingController();
  bool _negative = false;
  bool _saving = false;
  String? _error;

  bool get _isCard => widget.account.type == 'creditCard';

  @override
  void dispose() {
    _target.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final raw = Money.parse(_target.text).minorUnits;
      await widget.ledger.reconcile(
        accountId: widget.account.id,
        targetMinor: _negative ? -raw : raw,
        expectedBalance: widget.current,
        note: _note.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = userMessage(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: Text('Conciliar · ${widget.account.name}'),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Saldo registrado: ${Money(widget.current).format()}'),
              const SizedBox(height: 16),
              TextFormField(
                controller: _target,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                inputFormatters: [PygInputFormatter()],
                decoration: InputDecoration(
                  labelText: _isCard ? 'Deuda real PYG' : 'Saldo real PYG',
                ),
                validator: (value) => validateAmount(value, allowZero: true),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _negative,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _negative = v ?? false),
                title: Text(_isCard ? 'Saldo a favor' : 'Saldo negativo'),
              ),
              TextFormField(
                controller: _note,
                enabled: !_saving,
                decoration: const InputDecoration(
                  labelText: 'Motivo del ajuste',
                ),
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: const Text('Guardar ajuste'),
        ),
      ],
    ),
  );
}

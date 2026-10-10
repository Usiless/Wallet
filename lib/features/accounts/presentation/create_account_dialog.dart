import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../transactions/domain/ledger_models.dart';
import '../data/accounts_service.dart';

Future<CreateAccountDraft?> showCreateAccountDialog(
  BuildContext context, {
  CreateAccountDraft? initial,
}) => showDialog<CreateAccountDraft>(
  context: context,
  builder: (_) => _CreateAccountDialog(initial: initial),
);

class _CreateAccountDialog extends StatefulWidget {
  const _CreateAccountDialog({this.initial});
  final CreateAccountDraft? initial;

  @override
  State<_CreateAccountDialog> createState() => _CreateAccountDialogState();
}

class _CreateAccountDialogState extends State<_CreateAccountDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _initial = TextEditingController(text: '0');
  final _aliases = TextEditingController();
  final _limit = TextEditingController();
  final _closing = TextEditingController();
  final _due = TextEditingController();
  var _type = AccountType.bank;
  var _includeSavings = false;

  @override
  void initState() {
    super.initState();
    final draft = widget.initial;
    if (draft == null) return;
    _name.text = draft.name;
    _initial.text = Money(draft.initialBalanceMinor)
        .format(withCode: false)
        .trim();
    _type = draft.type;
    _aliases.text = draft.aliases.join(', ');
    _includeSavings = draft.includeInAvailableMoney;
    _limit.text = draft.creditLimitMinor == null
        ? ''
        : Money(draft.creditLimitMinor!).format(withCode: false).trim();
    _closing.text = '${draft.closingDay ?? 20}';
    _due.text = '${draft.dueDay ?? 3}';
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _initial,
      _aliases,
      _limit,
      _closing,
      _due,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validateMoney(String? value, {bool positive = false}) {
    try {
      final amount = Money.parse(value ?? '').minorUnits;
      if (positive && amount <= 0) return 'Ingresá un límite mayor que cero.';
      if (_type == AccountType.creditCard && amount < 0) {
        return 'Ingresá una deuda igual o mayor que cero.';
      }
      return null;
    } catch (_) {
      return 'Ingresá un importe válido.';
    }
  }

  String? _validateDay(String? value) {
    final day = int.tryParse(value ?? '');
    return day == null || day < 1 || day > 31
        ? 'Ingresá un día entre 1 y 31.'
        : null;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.initial == null ? 'Nueva cuenta' : 'Editar cuenta'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Ingresá un nombre de cuenta.'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AccountType>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: const [
                DropdownMenuItem(
                  value: AccountType.bank,
                  child: Text('Cuenta bancaria'),
                ),
                DropdownMenuItem(
                  value: AccountType.savings,
                  child: Text('Ahorro'),
                ),
                DropdownMenuItem(
                  value: AccountType.cash,
                  child: Text('Efectivo'),
                ),
                DropdownMenuItem(
                  value: AccountType.creditCard,
                  child: Text('Tarjeta de crédito'),
                ),
              ],
              onChanged: widget.initial != null
                  ? null
                  : (value) => setState(() => _type = value ?? _type),
            ),
            const SizedBox(height: 12),
            if (_type == AccountType.savings) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Incluir en dinero disponible'),
                value: _includeSavings,
                onChanged: (value) => setState(() => _includeSavings = value),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _initial,
              readOnly: widget.initial != null,
              keyboardType: const TextInputType.numberWithOptions(signed: true),
              decoration: InputDecoration(
                labelText: _type == AccountType.creditCard
                    ? 'Deuda inicial PYG'
                    : 'Saldo inicial PYG',
              ),
              validator: _validateMoney,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _aliases,
              decoration: const InputDecoration(
                labelText: 'Alias enmascarados (opcional)',
                helperText:
                    'Separados por coma; nunca ingreses números completos.',
              ),
            ),
            if (_type == AccountType.creditCard) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _limit,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Límite de crédito PYG',
                ),
                validator: (value) => _validateMoney(value, positive: true),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _closing,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Día de cierre'),
                validator: _validateDay,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _due,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Día de vencimiento',
                ),
                validator: _validateDay,
              ),
            ],
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(
            context,
            CreateAccountDraft(
              name: _name.text.trim(),
              type: _type,
              initialBalanceMinor: Money.parse(_initial.text).minorUnits,
              aliases: _aliases.text
                  .split(',')
                  .map((value) => value.trim())
                  .where((value) => value.isNotEmpty)
                  .toList(),
              creditLimitMinor: _type == AccountType.creditCard
                  ? Money.parse(_limit.text).minorUnits
                  : null,
              closingDay: _type == AccountType.creditCard
                  ? int.parse(_closing.text)
                  : null,
              dueDay: _type == AccountType.creditCard
                  ? int.parse(_due.text)
                  : null,
              includeInNetWorth: widget.initial?.includeInNetWorth ?? true,
              includeInAvailableMoney:
                  _type != AccountType.creditCard &&
                  (_type != AccountType.savings || _includeSavings),
            ),
          );
        },
        child: Text(widget.initial == null ? 'Agregar' : 'Guardar'),
      ),
    ],
  );
}

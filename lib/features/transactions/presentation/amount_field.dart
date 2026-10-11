import 'package:flutter/material.dart';

import '../../../core/money/money.dart';
import '../../../core/money/pyg_input_formatter.dart';

/// Importe principal del formulario de movimiento.
final class AmountField extends StatelessWidget {
  const AmountField({
    required this.controller,
    this.autofocus = false,
    super.key,
  });

  final TextEditingController controller;
  final bool autofocus;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    inputFormatters: [PygInputFormatter()],
    autofocus: autofocus,
    keyboardType: TextInputType.number,
    textInputAction: TextInputAction.next,
    style: Theme.of(context).textTheme.headlineMedium,
    decoration: const InputDecoration(prefixText: 'PYG ', labelText: 'Importe'),
    validator: (value) {
      try {
        if (Money.parse(value ?? '').minorUnits <= 0) {
          return 'Debe ser mayor que cero';
        }
      } catch (_) {
        return 'Ingresá un importe válido';
      }
      return null;
    },
  );
}

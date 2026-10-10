import 'package:finanzas_locales/core/money/pyg_input_formatter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final formatter = PygInputFormatter();
  TextEditingValue input(String text, [int? cursor]) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: cursor ?? text.length),
  );
  test('agrupa monto pegado y permite borrar todo', () {
    final grouped = formatter.formatEditUpdate(input(''), input('79500'));
    expect(grouped.text, '79.500');
    expect(grouped.selection.baseOffset, 6);
    expect(formatter.formatEditUpdate(grouped, input('')).text, '');
  });
  test('editar en medio conserva posición relativa a los dígitos', () {
    final changed = formatter.formatEditUpdate(
      input('79.500', 2),
      input('791.500', 3),
    );
    expect(changed.text, '791.500');
    expect(changed.selection.baseOffset, 3);
    expect(
      formatter
          .formatEditUpdate(changed, input('79.500', 2))
          .selection
          .baseOffset,
      2,
    );
  });
  test('texto inválido no sustituye el importe válido', () {
    final old = input('79.500');
    expect(formatter.formatEditUpdate(old, input('-15')), old);
    expect(formatter.formatEditUpdate(old, input('texto')), old);
  });
}

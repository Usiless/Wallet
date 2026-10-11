import 'package:finanzas_locales/core/money/amount_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exige un importe mayor que cero', () {
    expect(validateAmount(null), 'Ingresá un importe.');
    expect(validateAmount('  '), 'Ingresá un importe.');
    expect(validateAmount('abc'), 'Ingresá un importe válido.');
    expect(validateAmount('0'), 'El importe debe ser mayor que cero.');
    expect(validateAmount('15.000'), isNull);
  });

  test('con allowZero admite cero pero no negativos', () {
    expect(validateAmount('0', allowZero: true), isNull);
    expect(validateAmount('-5', allowZero: true), 'No puede ser negativo.');
  });
}

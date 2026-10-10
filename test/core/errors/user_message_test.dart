import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_locales/core/errors/app_exception.dart';
import 'package:finanzas_locales/core/errors/user_message.dart';

void main() {
  test('AppException usa su mensaje', () {
    expect(
      userMessage(const ValidationException('Importe inválido.')),
      'Importe inválido.',
    );
  });

  test(
    'StateError, FormatException y ArgumentError usan su mensaje sin prefijo',
    () {
      expect(userMessage(StateError('Sin cuenta.')), 'Sin cuenta.');
      expect(
        userMessage(const FormatException('Formato malo')),
        'Formato malo',
      );
      expect(userMessage(ArgumentError('Dato inválido')), 'Dato inválido');
    },
  );

  test('otros errores usan mensaje genérico', () {
    expect(userMessage(Exception('x')), 'No se pudo completar la operación.');
    expect(userMessage('texto'), 'No se pudo completar la operación.');
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:finanzas_locales/core/errors/app_exception.dart';
import 'package:finanzas_locales/core/errors/user_message.dart';

void main() {
  const generic = 'No se pudo completar la operación.';

  test('AppException usa su mensaje', () {
    expect(
      userMessage(const ValidationException('Importe inválido.')),
      'Importe inválido.',
    );
  });

  test(
    'StateError y FormatException de la app usan su mensaje sin prefijo',
    () {
      expect(userMessage(StateError('Elegí una cuenta.')), 'Elegí una cuenta.');
      expect(
        userMessage(const FormatException('Importe o cuotas inválidos.')),
        'Importe o cuotas inválidos.',
      );
    },
  );

  test('mensajes internos de Dart usan el texto genérico', () {
    Object caught(void Function() body) {
      try {
        body();
      } catch (error) {
        return error;
      }
      fail('no lanzó');
    }

    expect(userMessage(caught(() => <int>[].single)), generic);
    expect(userMessage(caught(() => [1, 2].single)), generic);
    expect(userMessage(caught(() => int.parse('x'))), generic);
    expect(userMessage(caught(() => DateTime.parse('x'))), generic);
    expect(userMessage(caught(() => [1][3])), generic);
    expect(userMessage(ArgumentError('Dato inválido')), generic);
  });

  test('otros errores usan mensaje genérico', () {
    expect(userMessage(Exception('x')), generic);
    expect(userMessage('texto'), generic);
  });
}

import 'dart:developer' as developer;

import 'app_exception.dart';

/// Texto apto para el usuario a partir de un error. Nunca expone el tipo ni la traza.
///
/// La app lanza `StateError` y `FormatException` con mensajes en español; los
/// mensajes internos de Dart (en inglés) y cualquier otro error se reemplazan
/// por un texto genérico y se registran para diagnóstico.
String userMessage(Object error) => switch (error) {
  AppException(:final message) => message,
  StateError(:final message) when !_dartInternal.hasMatch(message) => message,
  FormatException(:final message) when !_dartInternal.hasMatch(message) =>
    message,
  _ => _generic(error),
};

/// Mensajes de las bibliotecas de Dart (`.single`, `jsonDecode`, `int.parse`,
/// `DateTime.parse`, streams y futures).
final _dartInternal = RegExp(
  r'^(No element|Too (many|few) elements|Bad state|Cannot |Future already|'
  r'Stream has|Unexpected |Invalid |Missing |Unterminated |Control character|'
  r'Expected )',
);

String _generic(Object error) {
  developer.log(
    'Error sin mensaje para el usuario',
    name: 'cabal',
    error: error,
  );
  return 'No se pudo completar la operación.';
}

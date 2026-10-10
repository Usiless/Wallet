import 'app_exception.dart';

/// Texto apto para el usuario a partir de un error. Nunca expone el tipo ni la traza.
String userMessage(Object error) => switch (error) {
  AppException(:final message) => message,
  StateError(:final message) => message.toString(),
  FormatException(:final message) => message,
  ArgumentError(:final message) => message?.toString() ?? _generic,
  _ => _generic,
};

const _generic = 'No se pudo completar la operación.';

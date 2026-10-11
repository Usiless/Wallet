import 'package:flutter/foundation.dart';

/// Registro del actualizador. Va a logcat también en release (debugPrint) con prefijo
/// "[updater]". Nunca registra datos personales: solo versiones, URLs, tamaños, códigos y hashes.
void updaterLog(String message, {Object? error}) {
  final suffix = error == null ? '' : ': $error';
  debugPrint('[updater] $message$suffix');
}

import 'package:flutter/services.dart';

abstract final class DeviceCrypto {
  static const channel = MethodChannel('finanzas_locales/security');
  static Future<String> databaseKey() async {
    final key = await channel.invokeMethod<String>('databaseKey');
    if (key == null || !RegExp(r'^[a-f0-9]{64}$').hasMatch(key)) {
      throw StateError('No se pudo obtener la clave del almacenamiento.');
    }
    return key;
  }
}

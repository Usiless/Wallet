import 'dart:io';

import 'package:flutter/services.dart';

import '../../../core/errors/app_exception.dart';
import 'update_log.dart';

/// Puente nativo para el permiso de instalación y el instalador del sistema.
final class ApkInstaller {
  const ApkInstaller();

  static const _channel = MethodChannel('finanzas_locales/updater');

  /// true si Android permite que Cabal instale paquetes (siempre true en API < 26).
  Future<bool> canInstall() async {
    try {
      return await _channel.invokeMethod<bool>('canInstall') ?? false;
    } on PlatformException catch (error) {
      throw _failure(error);
    }
  }

  /// Abre «Instalar apps desconocidas» para Cabal.
  Future<void> openInstallSettings() async {
    try {
      await _channel.invokeMethod<void>('openInstallSettings');
    } on PlatformException catch (error) {
      throw _failure(error);
    }
  }

  /// Lanza el instalador del sistema con el APK verificado.
  Future<void> install(File apk) async {
    try {
      await _channel.invokeMethod<void>('install', {'path': apk.path});
    } on PlatformException catch (error) {
      throw _failure(error);
    }
  }

  UpdateException _failure(PlatformException error) {
    updaterLog('Instalador: ${error.code}', error: error);
    final message = switch (error.code) {
      'install_not_allowed' =>
        'Android no permite instalar Cabal desde esta fuente.',
      'invalid_apk_path' =>
        'El archivo descargado no es válido. Descargalo de nuevo.',
      'installer_unavailable' =>
        'No hay un instalador disponible en este dispositivo.',
      _ => 'No se pudo abrir el instalador.',
    };
    return UpdateException(
      UpdateFailure.installer,
      message,
      technicalDetail: '${error.code}: ${error.message}',
    );
  }
}

import 'package:local_auth/local_auth.dart';

import '../settings/settings_repository.dart';

final class AppLockService {
  AppLockService(this.settings, {LocalAuthentication? authentication})
    : authentication = authentication ?? LocalAuthentication();

  final SettingsRepository settings;
  final LocalAuthentication authentication;

  Future<bool> isEnabled() => settings.readBool('app_lock_enabled');

  Future<bool> canAuthenticate() async =>
      await authentication.isDeviceSupported() ||
      await authentication.canCheckBiometrics;

  Future<bool> unlock() async {
    if (!await isEnabled()) return true;
    try {
      return await authentication.authenticate(
        localizedReason: 'Desbloqueá Cabal para ver tus datos',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: true,
      );
    } on LocalAuthException {
      return false;
    }
  }

  Future<bool> setEnabled(bool enabled) async {
    if (enabled && !await canAuthenticate()) {
      throw StateError(
        'Este dispositivo no tiene un bloqueo seguro configurado.',
      );
    }
    if (enabled) {
      final authenticated = await authentication.authenticate(
        localizedReason: 'Confirmá el bloqueo de Cabal',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: true,
      );
      if (!authenticated) return false;
    }
    await settings.write('app_lock_enabled', enabled.toString());
    return true;
  }
}

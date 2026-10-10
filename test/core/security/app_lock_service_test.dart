import 'package:drift/native.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/security/app_lock_service.dart';
import 'package:finanzas_locales/core/settings/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

void main() {
  test(
    'un error asíncrono de autenticación mantiene la app bloqueada',
    () async {
      final database = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(database.close);
      final settings = SettingsRepository(database);
      await settings.write('app_lock_enabled', 'true');
      final service = AppLockService(
        settings,
        authentication: _UnavailableAuthentication(),
      );

      expect(await service.unlock(), isFalse);
      expect(await service.isEnabled(), isTrue);
    },
  );
}

class _UnavailableAuthentication extends LocalAuthentication {
  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<dynamic> authMessages = const [],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    await Future<void>.delayed(Duration.zero);
    throw const LocalAuthException(code: LocalAuthExceptionCode.uiUnavailable);
  }
}

import 'package:drift/native.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/security/app_lock_service.dart';
import 'package:finanzas_locales/core/settings/settings_repository.dart';
import 'package:finanzas_locales/shared/widgets/app_lock_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pump(const Duration(milliseconds: 10));
  }
}

void main() {
  late AppDatabase database;
  late SettingsRepository settings;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = SettingsRepository(database);
  });
  tearDown(() => database.close());

  test(
    'un error asíncrono de autenticación mantiene la app bloqueada',
    () async {
      await settings.write('app_lock_enabled', 'true');
      final service = AppLockService(
        settings,
        authentication: _FakeAuthentication(throwsUnavailable: true),
      );

      expect(await service.unlock(), isFalse);
      expect(await service.isEnabled(), isTrue);
    },
  );

  test('con el bloqueo desactivado no pide autenticación', () async {
    final authentication = _FakeAuthentication(result: false);
    final service = AppLockService(settings, authentication: authentication);

    expect(await service.unlock(), isTrue);
    expect(authentication.prompts, 0);
  });

  test(
    'con el bloqueo activado desbloquea solo si el sistema autentica',
    () async {
      await settings.write('app_lock_enabled', 'true');

      expect(
        await AppLockService(
          settings,
          authentication: _FakeAuthentication(result: true),
        ).unlock(),
        isTrue,
      );
      expect(
        await AppLockService(
          settings,
          authentication: _FakeAuthentication(result: false),
        ).unlock(),
        isFalse,
      );
    },
  );

  test('no se puede activar sin un bloqueo seguro en el dispositivo', () async {
    final service = AppLockService(
      settings,
      authentication: _FakeAuthentication(supported: false, biometrics: false),
    );

    await expectLater(service.setEnabled(true), throwsStateError);
    expect(await service.isEnabled(), isFalse);
  });

  test('activar sin confirmar la identidad no guarda el bloqueo', () async {
    final service = AppLockService(
      settings,
      authentication: _FakeAuthentication(result: false),
    );

    expect(await service.setEnabled(true), isFalse);
    expect(await service.isEnabled(), isFalse);
  });

  test('activar confirmando la identidad guarda el bloqueo y desactivar no la pide', () async {
    final authentication = _FakeAuthentication(result: true);
    final service = AppLockService(settings, authentication: authentication);

    expect(await service.setEnabled(true), isTrue);
    expect(await service.isEnabled(), isTrue);

    authentication.result = false;
    expect(await service.setEnabled(false), isTrue);
    expect(await service.isEnabled(), isFalse);
  });

  testWidgets(
    'la compuerta muestra el contenido tras desbloquear y permite reintentar',
    (tester) async {
      await tester.runAsync(() => settings.write('app_lock_enabled', 'true'));
      final authentication = _FakeAuthentication(result: false);
      await tester.pumpWidget(
        MaterialApp(
          home: AppLockGate(
            service: AppLockService(settings, authentication: authentication),
            child: const Text('Contenido'),
          ),
        ),
      );
      await settle(tester);

      expect(find.text('Contenido'), findsNothing);
      expect(find.text('Desbloquear'), findsOneWidget);

      authentication.result = true;
      await tester.tap(find.text('Desbloquear'));
      await settle(tester);

      expect(find.text('Contenido'), findsOneWidget);
      expect(find.text('Desbloquear'), findsNothing);
    },
  );
}

class _FakeAuthentication extends LocalAuthentication {
  _FakeAuthentication({
    this.result = true,
    this.supported = true,
    this.biometrics = true,
    this.throwsUnavailable = false,
  });

  bool result, supported, biometrics;
  final bool throwsUnavailable;
  int prompts = 0;

  @override
  Future<bool> isDeviceSupported() async => supported;

  @override
  Future<bool> get canCheckBiometrics async => biometrics;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    Iterable<dynamic> authMessages = const [],
    bool biometricOnly = false,
    bool sensitiveTransaction = true,
    bool persistAcrossBackgrounding = false,
  }) async {
    prompts++;
    await Future<void>.delayed(Duration.zero);
    if (throwsUnavailable) {
      throw const LocalAuthException(
        code: LocalAuthExceptionCode.uiUnavailable,
      );
    }
    return result;
  }
}

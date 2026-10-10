import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/notifications/native_notification_bridge.dart';
import 'package:finanzas_locales/core/settings/settings_repository.dart';
import 'package:finanzas_locales/features/settings/presentation/wallet_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channel = MethodChannel('finanzas_locales/notification_listener');
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  testWidgets(
    'Wallet y automatización están disponibles sin bandera y apagados inicialmente',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      Map<dynamic, dynamic>? configured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'isAccessGranted') return true;
            if (call.method == 'configure') configured = call.arguments as Map;
            return null;
          });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: WalletSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final detect = find.widgetWithText(
        SwitchListTile,
        'Detectar compras de Google Wallet',
      );
      final automatic = find.widgetWithText(
        SwitchListTile,
        'Registrar automáticamente compras reconocidas',
      );
      expect(tester.widget<SwitchListTile>(detect).value, isFalse);
      expect(tester.widget<SwitchListTile>(automatic).value, isFalse);
      await tester.tap(detect);
      await tester.pumpAndSettle();
      expect(
        await SettingsRepository(db).readBool('notification_listener_enabled'),
        isTrue,
      );
      expect(configured!['enabled'], isTrue);
      await tester.ensureVisible(automatic);
      await tester.tap(automatic);
      await tester.pumpAndSettle();
      expect(
        await SettingsRepository(db).readBool('wallet_auto_register'),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test(
    'consulta de cola no borra eventos y acuse usa identificador de captura',
    () async {
      final methods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            methods.add(call.method);
            if (call.method == 'queuedEnvelopes') {
              return [
                {
                  'packageName': 'com.google.android.gms',
                  'captureId': 'capture-1',
                  'title': 'ECOP',
                },
              ];
            }
            expect(call.arguments, {'captureId': 'capture-1'});
            return null;
          });
      const bridge = NativeNotificationBridge();
      final events = await bridge.queuedEnvelopes();
      expect(methods, ['queuedEnvelopes']);
      await bridge.acknowledge(events.single);
      expect(methods, ['queuedEnvelopes', 'acknowledgeEnvelope']);
    },
  );
  testWidgets('Wallet a 320/texto 2x recupera fallo de carga y ajustes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await db.customStatement(
      'ALTER TABLE app_settings RENAME TO unavailable_settings',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
          throw PlatformException(code: 'test_failure');
        });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const WalletSettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('No se pudo cargar la configuración de Wallet.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await db.customStatement(
      'ALTER TABLE unavailable_settings RENAME TO app_settings',
    );
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsNothing);
    final detect = find.widgetWithText(
      SwitchListTile,
      'Detectar compras de Google Wallet',
    );
    await tester.scrollUntilVisible(detect, 250);
    expect(tester.widget<SwitchListTile>(detect).onChanged, isNotNull);
    final access = find.text('Acceso a notificaciones en Android');
    await tester.scrollUntilVisible(access, 200);
    await tester.tap(access);
    await tester.pumpAndSettle();
    expect(
      find.text('No se pudieron abrir los ajustes de Android.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    expect(
      await SettingsRepository(db).readBool('notification_listener_enabled'),
      isFalse,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

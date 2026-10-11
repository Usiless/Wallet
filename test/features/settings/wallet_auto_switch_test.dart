import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/settings/settings_repository.dart';
import 'package:finanzas_locales/features/settings/presentation/wallet_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'registro automático deshabilitado mientras la detección está apagada',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MaterialApp(home: WalletSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final detect = tester.widget<SwitchListTile>(
        find.widgetWithText(
          SwitchListTile,
          'Detectar compras de Google Wallet',
        ),
      );
      final automatic = tester.widget<SwitchListTile>(
        find.widgetWithText(
          SwitchListTile,
          'Registrar automáticamente compras reconocidas',
        ),
      );
      expect(detect.value, isFalse);
      expect(automatic.onChanged, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('apagar la detección también apaga el registro automático', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    const channel = MethodChannel('finanzas_locales/notification_listener');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (call) async => call.method == 'isAccessGranted' ? true : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.runAsync(() async {
      final settings = SettingsRepository(db);
      await settings.write('notification_listener_enabled', 'true');
      await settings.write('wallet_auto_register', 'true');
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: WalletSettingsScreen()),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
    }
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(
              SwitchListTile,
              'Registrar automáticamente compras reconocidas',
            ),
          )
          .value,
      isTrue,
    );

    await tester.tap(
      find.widgetWithText(SwitchListTile, 'Detectar compras de Google Wallet'),
    );
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 40)),
      );
      await tester.pump();
    }

    final automatic = tester.widget<SwitchListTile>(
      find.widgetWithText(
        SwitchListTile,
        'Registrar automáticamente compras reconocidas',
      ),
    );
    expect(automatic.value, isFalse);
    expect(automatic.onChanged, isNull);
    final stored = await tester.runAsync(
      () => SettingsRepository(db).read('wallet_auto_register'),
    );
    expect(stored, 'false');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
}

import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/settings/presentation/wallet_settings_screen.dart';
import 'package:flutter/material.dart';
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
}

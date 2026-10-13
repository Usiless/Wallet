import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/notifications/expense_check_store.dart';
import 'package:finanzas_locales/core/settings/settings_repository.dart';
import 'package:finanzas_locales/features/settings/presentation/expense_check_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('finanzas_locales/payment_reminders');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  testWidgets('activar guarda el ajuste, pide permiso y muestra la hora', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final methods = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      return true;
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: Scaffold(body: ExpenseCheckTiles())),
      ),
    );
    await tester.pumpAndSettle();
    final toggle = find.widgetWithText(
      SwitchListTile,
      'Recordatorio de gastos',
    );
    expect(tester.widget<SwitchListTile>(toggle).value, isFalse);
    expect(find.text('Hora'), findsNothing);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(
      await SettingsRepository(db).readBool(expenseCheckEnabledKey),
      isTrue,
    );
    expect(methods, ['requestPermission']);
    expect(find.text('21:00'), findsOneWidget);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(
      await SettingsRepository(db).readBool(expenseCheckEnabledKey),
      isFalse,
    );
    expect(methods, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

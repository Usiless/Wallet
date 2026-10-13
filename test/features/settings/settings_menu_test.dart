import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/settings/presentation/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() => database = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => database.close());

  testWidgets('Más organiza pagos y plantillas sin CSV/JSON ni Reportes', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('CSV'), findsNothing);
    expect(find.textContaining('JSON'), findsNothing);
    expect(find.text('Plantillas'), findsOneWidget);
    expect(find.text('Movimientos programados'), findsOneWidget);
    expect(find.text('Pagos pendientes'), findsOneWidget);
    expect(find.text('Reportes'), findsNothing);
    expect(find.text('Backup cifrado'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

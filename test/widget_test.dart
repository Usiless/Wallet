import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/settings/settings_repository.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/onboarding/data/onboarding_service.dart';
import 'package:finanzas_locales/features/onboarding/presentation/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();

  testWidgets('muestra onboarding cuando todavía no fue completado', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await OnboardingService(
      database,
      AccountsService(database),
      SettingsRepository(database),
    ).ensureSystemData();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: OnboardingScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Configurar Cabal'), findsOneWidget);
    expect(find.text('Tus finanzas quedan en tu teléfono'), findsOneWidget);

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Agregá tus cuentas'), findsOneWidget);
    expect(find.textContaining('Sudameris'), findsNothing);
    expect(find.textContaining('Familiar'), findsNothing);
    expect(find.byType(CheckboxListTile), findsNothing);

    await tester.tap(find.text('Agregar cuenta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    expect(find.text('Ingresá un nombre de cuenta.'), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).first,
      'Mi cuenta personal',
    );
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    expect(find.text('Mi cuenta personal'), findsOneWidget);
    // Las cuentas del asistente se guardan solo al terminar la configuración.
    expect(await database.select(database.accounts).get(), isEmpty);
    await tester.tap(find.byTooltip('Quitar cuenta'));
    await tester.pumpAndSettle();
    expect(find.text('Mi cuenta personal'), findsNothing);
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Seguridad'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
    await database.close();
  });
}

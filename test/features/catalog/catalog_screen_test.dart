import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/catalog/catalog_screen.dart';
import 'package:finanzas_locales/features/merchants/merchant_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late MerchantService merchants;
  late String ecop, copaco;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
    merchants = MerchantService(db);
    ecop = await merchants.findOrCreate('Ecop');
    copaco = await merchants.findOrCreate('Copaco');
    await merchants.assignAlias('ECOP SA', ecop);
    await AccountsService(db).createAccount(
      const CreateAccountDraft(
        name: 'Banco',
        type: AccountType.bank,
        aliases: ['1234'],
      ),
    );
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
    }
    await tester.pumpAndSettle();
  }

  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const MaterialApp(home: CatalogScreen()),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> pickKind(WidgetTester tester, String label) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await settle(tester);
  }

  Future<void> choose(WidgetTester tester, String row, String option) async {
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, row),
        matching: find.byType(PopupMenuButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(option));
    await settle(tester);
  }

  Future<List<MerchantRecord>> allMerchants() => db.select(db.merchants).get();

  testWidgets(
    'archivar oculta el comercio y mostrar archivados permite reactivarlo',
    (tester) async {
      await seed(tester);
      await show(tester);
      expect(find.text('Ecop'), findsOneWidget);

      await choose(tester, 'Ecop', 'Archivar');
      expect(find.text('Ecop'), findsNothing);
      expect(find.text('Copaco'), findsOneWidget);

      await tester.tap(find.byTooltip('Mostrar archivados'));
      await settle(tester);
      expect(find.text('Archivado'), findsOneWidget);

      await choose(tester, 'Ecop', 'Reactivar');
      final rows = (await tester.runAsync(allMerchants))!;
      expect(rows.firstWhere((m) => m.id == ecop).isArchived, isFalse);
      await unmount(tester);
    },
  );

  testWidgets('renombrar cambia el nombre del comercio', (tester) async {
    await seed(tester);
    await show(tester);

    await choose(tester, 'Copaco', 'Renombrar');
    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre'),
      'Copaco SA',
    );
    await tester.tap(find.text('Guardar'));
    await settle(tester);

    final rows = (await tester.runAsync(allMerchants))!;
    expect(rows.firstWhere((m) => m.id == copaco).name, 'Copaco SA');
    expect(find.text('Copaco SA'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('renombrar con el nombre de otro comercio se rechaza', (
    tester,
  ) async {
    await seed(tester);
    await show(tester);

    await choose(tester, 'Copaco', 'Renombrar');
    await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'Ecop');
    await tester.tap(find.text('Guardar'));
    await settle(tester);

    expect(find.textContaining('identifica otro comercio'), findsOneWidget);
    final rows = (await tester.runAsync(allMerchants))!;
    expect(rows.firstWhere((m) => m.id == copaco).name, 'Copaco');
    await unmount(tester);
  });

  testWidgets('reasignar mueve el alias al otro comercio', (tester) async {
    await seed(tester);
    await show(tester);
    await pickKind(tester, 'Alias de comercios');

    await choose(tester, 'ECOP SA', 'Reasignar');
    expect(find.text('Asociar a comercio'), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(SimpleDialog),
        matching: find.text('Copaco'),
      ),
    );
    await settle(tester);

    final alias = (await tester.runAsync(
      () => (db.select(
        db.merchantAliases,
      )..where((a) => a.alias.equals('ECOP SA'))).getSingle(),
    ))!;
    expect(alias.merchantId, copaco);
    await unmount(tester);
  });

  testWidgets('agregar un alias de otro comercio no lo desplaza en silencio', (
    tester,
  ) async {
    await seed(tester);
    await show(tester);
    await pickKind(tester, 'Alias de comercios');

    await tester.tap(find.byTooltip('Agregar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Nombre'), 'ECOP SA');
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(SimpleDialog),
        matching: find.text('Copaco'),
      ),
    );
    await settle(tester);

    expect(find.textContaining('ya pertenece a otro comercio'), findsOneWidget);
    final alias = (await tester.runAsync(
      () => (db.select(
        db.merchantAliases,
      )..where((a) => a.alias.equals('ECOP SA'))).getSingle(),
    ))!;
    expect(alias.merchantId, ecop);
    await unmount(tester);
  });

  testWidgets('eliminar un alias de cuenta lo quita sin tocar la cuenta', (
    tester,
  ) async {
    await seed(tester);
    await show(tester);
    await pickKind(tester, 'Alias de cuentas');

    await choose(tester, '1234', 'Eliminar alias');
    await tester.tap(find.widgetWithText(FilledButton, 'Eliminar'));
    await settle(tester);

    expect(
      await tester.runAsync(() => db.select(db.accountAliases).get()),
      isEmpty,
    );
    expect(
      await tester.runAsync(() => db.select(db.accounts).get()),
      hasLength(1),
    );
    expect(find.text('1234'), findsNothing);
    await unmount(tester);
  });

  testWidgets('crear una categoría pide su tipo y la guarda', (tester) async {
    await seed(tester);
    await show(tester);
    await pickKind(tester, 'Categorías');

    await tester.tap(find.byTooltip('Agregar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre'),
      'Mascotas',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(find.text('Tipo de categoría'), findsOneWidget);
    await tester.tap(find.text('Ingreso'));
    await settle(tester);

    final created = (await tester.runAsync(
      () => (db.select(
        db.categories,
      )..where((c) => c.name.equals('Mascotas'))).getSingle(),
    ))!;
    expect(created.kind, 'income');
    expect(find.text('Mascotas'), findsOneWidget);
    await unmount(tester);
  });
}

import 'package:finanzas_locales/app/theme/app_theme.dart';
import 'package:drift/native.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/transactions/presentation/transaction_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Future<void> chooseWhen(WidgetTester tester, String label) async {
  final field = find.widgetWithText(DropdownButtonFormField<String>, 'Cuándo');
  await tester.ensureVisible(field);
  await tester.tap(field);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> openDetails(WidgetTester tester) async {
  final toggle = find.text('Más detalles');
  if (toggle.evaluate().isEmpty) return;
  await tester.ensureVisible(toggle);
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('P01: volver conserva borrador hasta confirmar descarte', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    late GoRouter router;
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => context.push('/new'),
              child: const Text('Abrir'),
            ),
          ),
        ),
        GoRoute(
          path: '/new',
          builder: (context, state) => const TransactionFormScreen(),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          accountsProvider.overrideWith((ref) => Stream.value([])),
          categoriesProvider.overrideWith((ref) => Stream.value([])),
          merchantsProvider.overrideWith((ref) => Stream.value([])),
          merchantAliasesProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '100000');
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar cambios?'), findsOneWidget);
    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      '100.000',
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('Abrir'), findsOneWidget);
    await tester.runAsync(() async {
      expect(await db.select(db.ledgerTransactions).get(), isEmpty);
    });
    await tester.pumpWidget(const SizedBox.shrink());
    router.dispose();
    await tester.pump(const Duration(milliseconds: 1));
  });
  testWidgets('V02: restaurar invalida borrador antes de crear datos', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    late List<AccountRecord> accounts;
    await tester.runAsync(() async {
      await AccountsService(database).createAccount(
        const CreateAccountDraft(name: 'Efectivo', type: AccountType.cash),
      );
      accounts = await database.select(database.accounts).get();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          merchantsProvider.overrideWith((ref) => Stream.value([])),
          merchantAliasesProvider.overrideWith((ref) => Stream.value([])),
          accountsProvider.overrideWith((ref) => Stream.value(accounts)),
          categoriesProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(home: TransactionFormScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '100000');
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Efectivo').last);
    await tester.pumpAndSettle();
    // BackupService advances this session counter inside the restore transaction.
    database.restoreGeneration++;
    await tester.scrollUntilVisible(
      find.text('Guardar movimiento'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Guardar movimiento'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Los datos fueron restaurados'), findsOneWidget);
    await tester.runAsync(() async {
      expect(await database.select(database.ledgerTransactions).get(), isEmpty);
      expect(await database.select(database.accountPostings).get(), isEmpty);
      expect(await database.select(database.merchants).get(), isEmpty);
    });
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 1));
  });
  testWidgets('cambiar gasto a ingreso descarta la categoría de gasto', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(database.close);
    final now = DateTime(2026, 10, 4);
    final categories = [
      CategoryRecord(
        id: 'sys-food',
        name: 'Alimentación',
        kind: 'expense',
        icon: 'category',
        color: 0,
        isSystem: true,
        isArchived: false,
        sortOrder: 0,
        createdAt: now,
        updatedAt: now,
      ),
      CategoryRecord(
        id: 'salary',
        name: 'Salario',
        kind: 'income',
        icon: 'category',
        color: 0,
        isSystem: true,
        isArchived: false,
        sortOrder: 1,
        createdAt: now,
        updatedAt: now,
      ),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          merchantsProvider.overrideWith((ref) => Stream.value([])),
          merchantAliasesProvider.overrideWith((ref) => Stream.value([])),
          accountsProvider.overrideWith((ref) => Stream.value([])),
          categoriesProvider.overrideWith((ref) => Stream.value(categories)),
        ],
        child: MaterialApp(
          theme: AppTheme.dark(),
          home: const TransactionFormScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alimentación').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Dividir entre categorías'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Dividir entre categorías'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ingreso'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Alimentación'), findsNothing);
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    expect(find.text('Salario'), findsOneWidget);
    await tester.tap(find.text('Salario'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Usar una sola categoría'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Usar una sola categoría'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets('cambiar origen al destino limpia la selección incompatible', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    late List<AccountRecord> accounts;
    await tester.runAsync(() async {
      final service = AccountsService(database);
      await service.createAccount(
        const CreateAccountDraft(name: 'Cuenta A', type: AccountType.bank),
      );
      await service.createAccount(
        const CreateAccountDraft(name: 'Cuenta B', type: AccountType.bank),
      );
      accounts = await database.select(database.accounts).get();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          merchantsProvider.overrideWith((ref) => Stream.value([])),
          merchantAliasesProvider.overrideWith((ref) => Stream.value([])),
          databaseProvider.overrideWithValue(database),
          accountsProvider.overrideWith((ref) => Stream.value(accounts)),
          categoriesProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(
          home: TransactionFormScreen(initialType: TransactionType.transfer),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cuenta A').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cuenta B').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cuenta B').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final destination = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>).last,
    );
    expect(destination.initialValue, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.runAsync(database.close);
  });

  testWidgets('fallo al guardar cuotas revierte compra y saldo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    late List<AccountRecord> accounts;
    await tester.runAsync(() async {
      await AccountsService(database).createAccount(
        const CreateAccountDraft(
          name: 'Tarjeta',
          type: AccountType.creditCard,
          creditLimitMinor: 1000000,
        ),
      );
      await database.customStatement(
        "CREATE TRIGGER fail_plan BEFORE INSERT ON installment_plans BEGIN SELECT RAISE(ABORT, 'fallo de prueba'); END",
      );
      accounts = await database.select(database.accounts).get();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          merchantsProvider.overrideWith((ref) => Stream.value([])),
          merchantAliasesProvider.overrideWith((ref) => Stream.value([])),
          databaseProvider.overrideWithValue(database),
          accountsProvider.overrideWith((ref) => Stream.value(accounts)),
          categoriesProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(home: TransactionFormScreen()),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, '60000');
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).first)
          .controller!
          .text,
      '60.000',
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tarjeta').last);
    await tester.pumpAndSettle();
    await openDetails(tester);
    await chooseWhen(tester, 'En cuotas');
    await tester.tap(find.byTooltip('Usar plantilla'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar como plantilla'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Guardar movimiento'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Guardar movimiento'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre de la plantilla'),
      'Compra en cuotas',
    );
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      expect(await database.select(database.ledgerTransactions).get(), isEmpty);
      expect(await database.select(database.accountPostings).get(), isEmpty);
      expect(
        (await database.select(database.appSettings).get()).where(
          (s) => s.key.startsWith('manual_template:'),
        ),
        isEmpty,
      );
    });
    expect(find.textContaining('fallo de prueba'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.runAsync(database.close);
  });
  testWidgets('pago preselecciona la tarjeta indicada y no la primera', (
    tester,
  ) async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    late List<AccountRecord> accounts;
    late String target;
    await tester.runAsync(() async {
      final service = AccountsService(database);
      await service.createAccount(
        const CreateAccountDraft(name: 'Banco', type: AccountType.bank),
      );
      await service.createAccount(
        const CreateAccountDraft(
          name: 'Tarjeta A',
          type: AccountType.creditCard,
          creditLimitMinor: 1000000,
        ),
      );
      target = await service.createAccount(
        const CreateAccountDraft(
          name: 'Tarjeta B',
          type: AccountType.creditCard,
          creditLimitMinor: 1000000,
        ),
      );
      accounts = await database.select(database.accounts).get();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          merchantsProvider.overrideWith((ref) => Stream.value([])),
          merchantAliasesProvider.overrideWith((ref) => Stream.value([])),
          databaseProvider.overrideWithValue(database),
          accountsProvider.overrideWith((ref) => Stream.value(accounts)),
          categoriesProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          home: TransactionFormScreen(
            template: 'cardPayment',
            toAccountId: target,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final destination = tester.widget<DropdownButtonFormField<String>>(
      find.byType(DropdownButtonFormField<String>).last,
    );
    expect(destination.initialValue, target);
    expect(find.text('Tarjeta B'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.runAsync(database.close);
  });
}

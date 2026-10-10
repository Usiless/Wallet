import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/money/money.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/merchants/merchant_service.dart';
import 'package:finanzas_locales/features/transactions/data/category_service.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:finanzas_locales/features/transactions/presentation/transaction_form_screen.dart';
import 'package:finanzas_locales/features/payments/domain/pending_payment_service.dart';
import 'package:finanzas_locales/features/templates/manual_template_service.dart';
import 'package:finanzas_locales/features/templates/scheduled_template_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Caminos de guardado del formulario que mueven dinero o datos guardados.
void main() {
  late AppDatabase db;
  late String bank, food, transport;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
    bank = await AccountsService(db).createAccount(
      const CreateAccountDraft(
        name: 'Banco',
        type: AccountType.bank,
        initialBalanceMinor: 1000000,
      ),
    );
    final categories = CategoryService(db);
    food = await categories.create('Alimentación', kind: 'expense');
    transport = await categories.create('Transporte', kind: 'expense');
  });

  Future<void> show(
    WidgetTester tester,
    Widget form, {
    bool routed = false,
    bool liveCategories = false,
  }) async {
    final accounts = (await tester.runAsync(
      () => db.select(db.accounts).get(),
    ))!;
    final categories = (await tester.runAsync(
      () => db.select(db.categories).get(),
    ))!;
    final merchants = (await tester.runAsync(
      () => db.select(db.merchants).get(),
    ))!;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Inicio')),
        ),
        GoRoute(path: '/form', builder: (_, _) => form),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          accountsProvider.overrideWith((ref) => Stream.value(accounts)),
          if (!liveCategories)
            categoriesProvider.overrideWith((ref) => Stream.value(categories)),
          merchantsProvider.overrideWith((ref) => Stream.value(merchants)),
          merchantAliasesProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: routed
            ? MaterialApp.router(routerConfig: router)
            : MaterialApp(home: form),
      ),
    );
    if (routed) router.push('/form');
    await settle(tester);
  }

  Future<void> pick(WidgetTester tester, String field, String option) async {
    final dropdown = find.widgetWithText(
      DropdownButtonFormField<String>,
      field,
    );
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final target = find.text(text);
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester, String label) async {
    final button = find.text(label);
    await tester.scrollUntilVisible(
      button,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(button);
    await settle(tester);
  }

  Future<List<TransactionSplitRecord>> splitsOf(String transactionId) =>
      (db.select(
        db.transactionSplits,
      )..where((s) => s.transactionId.equals(transactionId))).get();

  group('gasto dividido', () {
    testWidgets('guarda cada categoría con su importe y descuenta el total', (
      tester,
    ) async {
      await seed(tester);
      await show(tester, const TransactionFormScreen());

      await pick(tester, 'Cuenta de origen', 'Banco');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Importe').first,
        '100000',
      );
      await tapText(tester, 'Dividir entre categorías');
      final categoryFields = find.widgetWithText(
        DropdownButtonFormField<String>,
        'Categoría',
      );
      expect(categoryFields, findsNWidgets(2));
      for (final (index, name) in ['Alimentación', 'Transporte'].indexed) {
        await tester.tap(categoryFields.at(index));
        await tester.pumpAndSettle();
        await tester.tap(find.text(name).last);
        await tester.pumpAndSettle();
      }
      final amounts = find.widgetWithText(TextFormField, 'Importe');
      await tester.enterText(amounts.at(1), '60000');
      await tester.enterText(amounts.at(2), '40000');
      await submit(tester, 'Guardar movimiento');

      final expense = (await tester.runAsync(
        () => db.select(db.ledgerTransactions).getSingle(),
      ))!;
      expect(expense.type, 'expense');
      expect(expense.amountMinor, 100000);
      final splits = (await tester.runAsync(() => splitsOf(expense.id)))!;
      expect(
        {for (final s in splits) s.categoryId: s.amountMinor},
        {food: 60000, transport: 40000},
      );
      expect(
        await tester.runAsync(() => LedgerService(db).balance(bank)),
        900000,
      );
    });

    testWidgets('con una categoría sin elegir avisa y no guarda nada', (
      tester,
    ) async {
      await seed(tester);
      await show(tester, const TransactionFormScreen());

      await pick(tester, 'Cuenta de origen', 'Banco');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Importe').first,
        '100000',
      );
      await tapText(tester, 'Dividir entre categorías');
      final categoryFields = find.widgetWithText(
        DropdownButtonFormField<String>,
        'Categoría',
      );
      await tester.tap(categoryFields.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alimentación').last);
      await tester.pumpAndSettle();
      final amounts = find.widgetWithText(TextFormField, 'Importe');
      await tester.enterText(amounts.at(1), '60000');
      await tester.enterText(amounts.at(2), '40000');
      await submit(tester, 'Guardar movimiento');

      expect(find.textContaining('Elegí todas las categorías'), findsOneWidget);
      expect(
        await tester.runAsync(() => db.select(db.ledgerTransactions).get()),
        isEmpty,
      );
      expect(
        await tester.runAsync(() => LedgerService(db).balance(bank)),
        1000000,
      );
    });
  });
  group('editar y clonar un gasto dividido', () {
    Future<String> splitExpense(WidgetTester tester) => tester
        .runAsync(
          () => LedgerService(db).create(
            TransactionDraft(
              type: TransactionType.expense,
              amount: const Money(100000),
              occurredAt: DateTime(2026, 9, 10),
              fromAccountId: bank,
              description: 'Mercado',
              splits: [
                SplitDraft(categoryId: food, amountMinor: 60000),
                SplitDraft(categoryId: transport, amountMinor: 40000),
              ],
            ),
          ),
        )
        .then((id) => id!);

    List<String> amountTexts(WidgetTester tester) => [
      for (final field in tester.widgetList<TextFormField>(
        find.widgetWithText(TextFormField, 'Importe'),
      ))
        field.controller!.text,
    ];

    testWidgets(
      'editar carga las divisiones y conserva importes y categorías',
      (tester) async {
        await seed(tester);
        final id = await splitExpense(tester);
        await show(tester, TransactionFormScreen(editId: id));

        expect(find.text('Editar movimiento'), findsOneWidget);
        expect(amountTexts(tester), ['100.000', '60.000', '40.000']);
        final note = find.widgetWithText(TextFormField, 'Nota');
        await tester.scrollUntilVisible(
          note,
          250,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(note, 'Corregido');
        await submit(tester, 'Guardar cambios');

        final row = (await tester.runAsync(
          () => db.select(db.ledgerTransactions).getSingle(),
        ))!;
        expect(row.id, id);
        expect(row.note, 'Corregido');
        expect(row.amountMinor, 100000);
        final splits = (await tester.runAsync(() => splitsOf(id)))!;
        expect(
          {for (final s in splits) s.categoryId: s.amountMinor},
          {food: 60000, transport: 40000},
        );
        expect(
          await tester.runAsync(() => LedgerService(db).balance(bank)),
          900000,
        );
      },
    );

    testWidgets(
      'clonar crea un segundo gasto con las mismas divisiones y fecha de hoy',
      (tester) async {
        await seed(tester);
        final id = await splitExpense(tester);
        await show(tester, TransactionFormScreen(cloneId: id));

        expect(find.text('Nuevo movimiento'), findsOneWidget);
        expect(amountTexts(tester), ['100.000', '60.000', '40.000']);
        await submit(tester, 'Guardar movimiento');

        final rows = (await tester.runAsync(
          () => db.select(db.ledgerTransactions).get(),
        ))!;
        expect(rows, hasLength(2));
        final copy = rows.firstWhere((r) => r.id != id);
        final today = DateTime.now();
        final date = copy.occurredAt.toLocal();
        expect(
          (date.year, date.month, date.day),
          (today.year, today.month, today.day),
        );
        final splits = (await tester.runAsync(() => splitsOf(copy.id)))!;
        expect(
          {for (final s in splits) s.categoryId: s.amountMinor},
          {food: 60000, transport: 40000},
        );
        expect(
          await tester.runAsync(() => LedgerService(db).balance(bank)),
          800000,
        );
      },
    );
  });
  group('guardar plantilla desde el formulario', () {
    void answerReminderPermission(WidgetTester tester) {
      const channel = MethodChannel('finanzas_locales/payment_reminders');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => true,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
    }

    Future<List<ManualTemplate>> templates() =>
        ManualTemplateService(db).list();

    testWidgets(
      'crea una plantilla programada con importe, cuenta y categoría',
      (tester) async {
        answerReminderPermission(tester);
        await seed(tester);
        await show(
          tester,
          const TransactionFormScreen(editTemplate: true),
          routed: true,
        );

        await pick(tester, 'Cuenta de origen', 'Banco');
        await pick(tester, 'Categoría', 'Alimentación');
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Importe').first,
          '150000',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Descripción'),
          'Internet',
        );
        await submit(tester, 'Guardar plantilla');
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Nombre de la plantilla'),
          'Internet mensual',
        );
        await tester.tap(find.text('Preparar pagos pendientes'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
        await settle(tester);

        final saved = (await tester.runAsync(templates))!;
        expect(saved, hasLength(1));
        expect(saved.single.name, 'Internet mensual');
        final fields = saved.single.fields;
        expect(fields['type'], 'expense');
        expect(fields['amountMinor'], 150000);
        expect(fields['from'], bank);
        expect(fields['category'], food);
        expect(fields['merchant'], 'Internet');
        final schedule = fields['schedule'] as Map;
        expect(schedule['enabled'], isTrue);
        expect(schedule['frequency'], 'monthly');
        expect(schedule['nextDate'], scheduledDate(DateTime.now()));
        expect(find.text('Plantilla guardada.'), findsOneWidget);
        expect(
          await tester.runAsync(() => db.select(db.ledgerTransactions).get()),
          isEmpty,
        );
      },
    );

    testWidgets('programar el mismo día de la compra consume ese vencimiento', (
      tester,
    ) async {
      answerReminderPermission(tester);
      await seed(tester);
      await show(tester, const TransactionFormScreen());

      await pick(tester, 'Cuenta de origen', 'Banco');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Importe').first,
        '80000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descripción'),
        'Gimnasio',
      );
      await tester.tap(find.byTooltip('Usar plantilla'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar como plantilla'));
      await tester.pumpAndSettle();
      await submit(tester, 'Guardar movimiento');

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre de la plantilla'),
        'Gimnasio',
      );
      await tester.tap(find.text('Preparar pagos pendientes'));
      await tester.pumpAndSettle();
      // La próxima fecha propuesta es el mes siguiente: se vuelve al mes de la
      // compra y se elige el mismo día.
      final today = DateTime.now();
      await tester.tap(find.text('Próxima fecha'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(DatePickerDialog),
          matching: find.text('${today.day}'),
        ),
      );
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await settle(tester);

      final saved = (await tester.runAsync(templates))!.single;
      final movement = (await tester.runAsync(
        () => db.select(db.ledgerTransactions).getSingle(),
      ))!;
      expect(
        movement.externalFingerprint,
        'scheduled:${saved.id}:${scheduledDate(today)}',
      );
      expect(movement.sourceReference, saved.id);
      final schedule = saved.fields['schedule'] as Map;
      final following = nextScheduledDate(
        DateTime(today.year, today.month, today.day),
        {'frequency': 'monthly', 'anchorDay': today.day},
      );
      expect(schedule['nextDate'], scheduledDate(following));
      final result = (await tester.runAsync(
        () => ScheduledTemplateService(db).processDue(now: today),
      ))!;
      // Solo se prepara el vencimiento del mes siguiente; el consumido no se duplica.
      expect(result.registered, ['Gimnasio']);
      final pending = (await tester.runAsync(
        () => PendingPaymentService(db).list(),
      ))!;
      expect(pending, hasLength(1));
      expect(scheduledDate(pending.single.dueDate), scheduledDate(following));
      expect(
        await tester.runAsync(() => db.select(db.ledgerTransactions).get()),
        hasLength(1),
      );
    });

    testWidgets('editar conserva el id y la fecha programada y vuelve atrás', (
      tester,
    ) async {
      answerReminderPermission(tester);
      await seed(tester);
      final id = (await tester.runAsync(
        () => ManualTemplateService(db).save('Alquiler', {
          'type': 'expense',
          'amountMinor': 500000,
          'from': bank,
          'merchant': 'Alquiler',
          'channel': 'bankTransfer',
          'schedule': {
            'enabled': true,
            'frequency': 'monthly',
            'nextDate': '2026-11-05',
            'anchorDay': 5,
            'anchorMonth': 11,
          },
        }),
      ))!;
      await show(
        tester,
        TransactionFormScreen(editTemplate: true, savedTemplateId: id),
        routed: true,
      );

      expect(find.text('Editar plantilla'), findsOneWidget);
      await submit(tester, 'Guardar plantilla');
      final name = find.widgetWithText(TextFormField, 'Nombre de la plantilla');
      expect(tester.widget<TextFormField>(name).initialValue, 'Alquiler');
      await tester.enterText(name, 'Alquiler depto');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
      await settle(tester);

      final saved = (await tester.runAsync(templates))!;
      expect(saved, hasLength(1));
      expect(saved.single.id, id);
      expect(saved.single.name, 'Alquiler depto');
      final schedule = saved.single.fields['schedule'] as Map;
      expect(schedule['nextDate'], '2026-11-05');
      expect(schedule['anchorDay'], 5);
      expect(schedule['enabled'], isTrue);
      expect(saved.single.fields['amountMinor'], 500000);
      expect(find.text('Inicio'), findsOneWidget);
    });
  });
  group('fechas de compra y primera cuota', () {
    testWidgets(
      'cambiar la fecha de compra arrastra la primera cuota que coincidía',
      (tester) async {
        await seed(tester);
        await tester.runAsync(
          () => AccountsService(db).createAccount(
            const CreateAccountDraft(
              name: 'Tarjeta',
              type: AccountType.creditCard,
              creditLimitMinor: 5000000,
            ),
          ),
        );
        await show(tester, const TransactionFormScreen());

        await pick(tester, 'Cuenta de origen', 'Tarjeta');
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Importe').first,
          '300000',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Descripción'),
          'Notebook',
        );
        await tapText(tester, 'Más detalles');
        await pick(tester, 'Cuándo', 'En cuotas');

        // Fija la primera cuota en la fecha de compra (hoy) aceptando el selector.
        await tapText(tester, 'Primera cuota');
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        // Cambia la fecha de compra a otro día del mes actual.
        final today = DateTime.now();
        final day = today.day == 15 ? 14 : 15;
        await tester.tap(find.widgetWithText(ListTile, 'Fecha'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.descendant(
            of: find.byType(DatePickerDialog),
            matching: find.text('$day'),
          ),
        );
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await submit(tester, 'Guardar movimiento');

        final purchase = (await tester.runAsync(
          () => db.select(db.ledgerTransactions).getSingle(),
        ))!;
        final bought = purchase.occurredAt.toLocal();
        expect(
          (bought.year, bought.month, bought.day),
          (today.year, today.month, day),
        );
        final plan = (await tester.runAsync(
          () => db.select(db.installmentPlans).getSingle(),
        ))!;
        expect(plan.installmentCount, 2);
        expect(
          plan.firstPeriod.toUtc(),
          DateTime.utc(today.year, today.month, day, 12),
        );
      },
    );
  });

  group('comercio y categoría', () {
    testWidgets(
      'elegir un comercio propone su categoría y guardar la recuerda',
      (tester) async {
        await seed(tester);
        late String ecop;
        await tester.runAsync(() async {
          final merchants = MerchantService(db);
          ecop = await merchants.findOrCreate('Ecop');
          await merchants.rememberCategory(ecop, food);
        });
        await show(tester, const TransactionFormScreen());

        await pick(tester, 'Cuenta de origen', 'Banco');
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Importe').first,
          '50000',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Descripción'),
          'Ec',
        );
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ListTile, 'Ecop'));
        await settle(tester);
        expect(
          find.descendant(
            of: find.widgetWithText(
              DropdownButtonFormField<String>,
              'Categoría',
            ),
            matching: find.text('Alimentación'),
          ),
          findsOneWidget,
        );

        // El usuario corrige la categoría: la preferencia del comercio se actualiza.
        await pick(tester, 'Categoría', 'Transporte');
        await submit(tester, 'Guardar movimiento');

        final purchase = (await tester.runAsync(
          () => db.select(db.ledgerTransactions).getSingle(),
        ))!;
        expect(purchase.merchantId, ecop);
        final splits = (await tester.runAsync(() => splitsOf(purchase.id)))!;
        expect(
          {for (final s in splits) s.categoryId: s.amountMinor},
          {transport: 50000},
        );
        expect(
          await tester.runAsync(
            () => MerchantService(db).defaultCategory(ecop),
          ),
          transport,
        );
      },
    );

    for (final (label, kind) in [('Gasto', 'expense'), ('Ingreso', 'income')]) {
      testWidgets(
        'crear categoría desde el formulario ($kind) la crea y la deja elegida',
        (tester) async {
          await seed(tester);
          await show(
            tester,
            const TransactionFormScreen(),
            liveCategories: true,
          );
          await tester.tap(
            find.descendant(
              of: find.byType(SegmentedButton<TransactionType>),
              matching: find.text(label),
            ),
          );
          await settle(tester);

          await tester.tap(find.byTooltip('Crear categoría'));
          await tester.pumpAndSettle();
          expect(find.text('Nueva categoría'), findsOneWidget);
          await tester.enterText(find.byType(TextField).last, 'Mascotas');
          await tester.tap(find.text('Crear'));
          await settle(tester);

          final created = (await tester.runAsync(
            () => (db.select(
              db.categories,
            )..where((c) => c.name.equals('Mascotas'))).getSingle(),
          ))!;
          expect(created.kind, kind);
          expect(
            find.descendant(
              of: find.widgetWithText(
                DropdownButtonFormField<String>,
                'Categoría',
              ),
              matching: find.text('Mascotas'),
            ),
            findsOneWidget,
          );
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump(const Duration(milliseconds: 50));
        },
      );
    }
  });
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 80)),
    );
  }
  await tester.pumpAndSettle();
}

import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/transactions/presentation/transaction_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:finanzas_locales/features/payments/domain/pending_payment_service.dart';
import 'package:finanzas_locales/features/templates/manual_template_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
  testWidgets('Gasto permite cuotas sin crédito y rango completo', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          accountsProvider.overrideWith((ref) => Stream.value([])),
          categoriesProvider.overrideWith((ref) => Stream.value([])),
          merchantsProvider.overrideWith((ref) => Stream.value([])),
          merchantAliasesProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(home: TransactionFormScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('En cuotas'), findsNothing);
    expect(find.text('Pagar después'), findsNothing);
    await openDetails(tester);
    await chooseWhen(tester, 'Pagar después');
    expect(find.text('Cantidad de cuotas'), findsNothing);
    await chooseWhen(tester, 'En cuotas');
    expect(find.text('Cantidad de cuotas'), findsOneWidget);
    final count = tester.widget<DropdownButton<int>>(
      find.byType(DropdownButton<int>).first,
    );
    expect(count.items!.map((e) => e.value), containsAll([2, 119, 120]));
    expect(find.byIcon(Icons.bookmark_added), findsNothing);
  });
  testWidgets(
    'Pagar después sin cuotas crea un solo pendiente sin mover saldo',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      late List<AccountRecord> accounts;
      await tester.runAsync(() async {
        await AccountsService(db).createAccount(
          const CreateAccountDraft(name: 'Banco', type: AccountType.bank),
        );
        accounts = await db.select(db.accounts).get();
      });
      const channel = MethodChannel('finanzas_locales/payment_reminders');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => false,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            accountsProvider.overrideWith((ref) => Stream.value(accounts)),
            categoriesProvider.overrideWith((ref) => Stream.value([])),
            merchantsProvider.overrideWith((ref) => Stream.value([])),
            merchantAliasesProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(home: TransactionFormScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Cuenta de origen',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Banco').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Importe'),
        '150000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descripción'),
        'Internet',
      );
      await openDetails(tester);
      await chooseWhen(tester, 'Pagar después');
      expect(find.text('Fecha de pago'), findsOneWidget);
      expect(find.text('Recordatorios'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Guardar movimiento'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Guardar movimiento'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 70));
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final pending = await PendingPaymentService(db).list();
        expect(await db.select(db.ledgerTransactions).get(), isEmpty);
        expect(pending, hasLength(1));
        expect(pending.single.installmentCount, 1);
        expect(pending.single.amountMinor, 150000);
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'Pagar después con Repetir crea plantilla programada y prepara pendientes',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      late List<AccountRecord> accounts;
      await tester.runAsync(() async {
        await AccountsService(db).createAccount(
          const CreateAccountDraft(name: 'Banco', type: AccountType.bank),
        );
        accounts = await db.select(db.accounts).get();
      });
      const channel = MethodChannel('finanzas_locales/payment_reminders');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        (_) async => false,
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            accountsProvider.overrideWith((ref) => Stream.value(accounts)),
            categoriesProvider.overrideWith((ref) => Stream.value([])),
            merchantsProvider.overrideWith((ref) => Stream.value([])),
            merchantAliasesProvider.overrideWith((ref) => Stream.value([])),
          ],
          child: const MaterialApp(home: TransactionFormScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(
          DropdownButtonFormField<String>,
          'Cuenta de origen',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Banco').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Importe'),
        '150000',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descripción'),
        'Internet',
      );
      await openDetails(tester);
      await chooseWhen(tester, 'Pagar después');
      expect(find.text('Fecha de pago'), findsOneWidget);
      expect(find.text('Recordatorios'), findsOneWidget);
      await tester.ensureVisible(find.text('No repetir'));
      await tester.tap(find.text('No repetir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mensual').last);
      await tester.pumpAndSettle();
      expect(find.text('Mensual'), findsOneWidget);
      expect(find.text('No repetir'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Guardar movimiento'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Guardar movimiento'));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 70));
      });
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final pending = await PendingPaymentService(db).list();
        expect(await db.select(db.ledgerTransactions).get(), isEmpty);
        final templates = await ManualTemplateService(db).list();
        expect(templates, hasLength(1));
        expect(templates.single.name, 'Internet');
        expect(pending, isNotEmpty);
        expect(pending.every((p) => p.installmentCount == 1), isTrue);
        expect(pending.every((p) => p.amountMinor == 150000), isTrue);
        expect(
          pending.map((p) => p.sourceReference).toSet(),
          hasLength(pending.length),
        );
      });
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
  for (final income in [false, true]) {
    for (final staleTemplate in income ? [false] : [false, true]) {
      testWidgets(
        'Cuotas conservan borrador al cambiar tipo, ingreso=$income, plantilla previa=$staleTemplate',
        (tester) async {
          final db = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(db.close);
          late List<AccountRecord> accounts;
          await tester.runAsync(() async {
            await AccountsService(db).createAccount(
              const CreateAccountDraft(name: 'Banco', type: AccountType.bank),
            );
            accounts = await db.select(db.accounts).get();
          });
          const channel = MethodChannel('finanzas_locales/payment_reminders');
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            (_) async => false,
          );
          addTearDown(
            () => tester.binding.defaultBinaryMessenger
                .setMockMethodCallHandler(channel, null),
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWithValue(db),
                accountsProvider.overrideWith((ref) => Stream.value(accounts)),
                categoriesProvider.overrideWith((ref) => Stream.value([])),
                merchantsProvider.overrideWith((ref) => Stream.value([])),
                merchantAliasesProvider.overrideWith((ref) => Stream.value([])),
              ],
              child: const MaterialApp(home: TransactionFormScreen()),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.widgetWithText(
              DropdownButtonFormField<String>,
              'Cuenta de origen',
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Banco').last);
          await tester.pumpAndSettle();
          await tester.enterText(
            find.widgetWithText(TextFormField, 'Importe'),
            '100000',
          );
          await tester.enterText(
            find.widgetWithText(TextFormField, 'Descripción'),
            'Servicio',
          );
          if (staleTemplate) {
            await tester.tap(find.byTooltip('Usar plantilla'));
            await tester.runAsync(() async {
              await Future<void>.delayed(const Duration(milliseconds: 50));
            });
            await tester.pumpAndSettle();
            await tester.tap(find.text('Guardar como plantilla'));
            await tester.pumpAndSettle();
          }
          await openDetails(tester);
          await chooseWhen(tester, 'Pagar después');
          await chooseWhen(tester, 'En cuotas');
          await tester.scrollUntilVisible(
            find.text('Ingreso'),
            -250,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.text('Ingreso'));
          await tester.pumpAndSettle();
          if (!income) {
            await tester.tap(find.text('Gasto'));
            await tester.pumpAndSettle();
            expect(
              tester
                  .widget<DropdownButtonFormField<String>>(
                    find.widgetWithText(
                      DropdownButtonFormField<String>,
                      'Cuándo',
                    ),
                  )
                  .initialValue,
              'installments',
            );
          }
          if (income) {
            await tester.tap(
              find.widgetWithText(
                DropdownButtonFormField<String>,
                'Cuenta de destino',
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.text('Banco').last);
            await tester.pumpAndSettle();
          }
          await tester.scrollUntilVisible(
            find.text('Guardar y crear otro'),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.text('Guardar y crear otro'));
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.text('Guardar movimiento'),
            250,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(find.text('Guardar movimiento'));
          await tester.runAsync(() async {
            await Future<void>.delayed(const Duration(milliseconds: 70));
          });
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final ledger = await db.select(db.ledgerTransactions).get();
            final pending = await PendingPaymentService(db).list();
            if (income) {
              expect(ledger.single.type, 'income');
              expect(pending, isEmpty);
              expect(await db.select(db.installmentPlans).get(), isEmpty);
            } else {
              expect(ledger, isEmpty);
              expect(pending, hasLength(2));
              expect(pending.fold<int>(0, (n, p) => n + p.amountMinor), 100000);
            }
          });
          if (!income) {
            expect(
              find.text('Guardado. Recordatorios sin permiso.'),
              findsOneWidget,
            );
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
        },
      );
    }
  }
  testWidgets('Formulario en cuotas admite 320px y texto 2x', (tester) async {
    tester.view.physicalSize = const Size(320, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FlutterErrorDetails? layoutError;
    final originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      layoutError = details;
      originalErrorHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalErrorHandler);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          accountsProvider.overrideWith((ref) => Stream.value([])),
          categoriesProvider.overrideWith((ref) => Stream.value([])),
          merchantsProvider.overrideWith((ref) => Stream.value([])),
          merchantAliasesProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const TransactionFormScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: layoutError?.toString());
    await openDetails(tester);
    await chooseWhen(tester, 'Pagar después');
    await chooseWhen(tester, 'En cuotas');
    expect(tester.takeException(), isNull, reason: layoutError?.toString());
    await tester.scrollUntilVisible(
      find.text('Guardar movimiento'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: layoutError?.toString());
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}

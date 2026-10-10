import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/notifications/notification_envelope.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/pending_inbox/presentation/pending_inbox_screen.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late ProviderContainer container;
  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
  });
  tearDown(() async {
    container.dispose();
    await database.close();
  });

  Future<void> open(WidgetTester tester) async {
    await container
        .read(notificationIngestionProvider)
        .ingest(
          NotificationEnvelope(
            version: 1,
            packageName: 'com.google.android.gms',
            notificationKey: 'unknown-card',
            id: 1,
            postTime: DateTime.now().toUtc(),
            title: 'Comercio',
            text: 'PYG 15000 · ••9999',
          ),
        );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PendingInboxScreen()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Revisar'));
    await tester.pumpAndSettle();
  }

  testWidgets('sin coincidencia exige seleccionar y luego registra', (
    tester,
  ) async {
    final now = DateTime.now().toUtc();
    await database
        .into(database.categories)
        .insert(
          CategoriesCompanion.insert(
            id: 'shopping',
            name: 'Compras',
            kind: 'expense',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await container
        .read(accountsServiceProvider)
        .createAccount(
          const CreateAccountDraft(
            name: 'Mi tarjeta',
            type: AccountType.creditCard,
            creditLimitMinor: 1000000,
          ),
        );
    await open(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Importe'),
      '120000',
    );
    expect(find.textContaining('Confianza'), findsNothing);
    expect(find.text('Descartar'), findsOneWidget);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String> &&
            widget.decoration.labelText == 'Categoría',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Compras').last);
    await tester.pumpAndSettle();
    final dropdown = tester.widget<DropdownButtonFormField<String>>(
      find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String> &&
            widget.decoration.labelText == 'Cuenta de origen',
      ),
    );
    expect(dropdown.initialValue, isNull);
    final confirm = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Registrar gasto'),
    );
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is DropdownButtonFormField<String> &&
            widget.decoration.labelText == 'Cuenta de origen',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mi tarjeta').last);
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(confirm).onPressed, isNotNull);
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(
      await database.select(database.ledgerTransactions).get(),
      hasLength(1),
    );
    expect(
      (await database.select(database.ledgerTransactions).getSingle())
          .amountMinor,
      120000,
    );
    expect(
      (await database.select(database.paymentCandidates).getSingle())
          .amountMinor,
      120000,
    );
    expect(
      (await database.select(database.transactionSplits).getSingle())
          .categoryId,
      'shopping',
    );
    final merchant = await database.select(database.merchants).getSingle();
    expect(
      await container
          .read(merchantServiceProvider)
          .defaultCategory(merchant.id),
      'shopping',
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('sin cuentas permite crear y después exige seleccionar', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Nueva cuenta'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nombre'),
      'Mi cuenta',
    );
    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    expect(await database.select(database.accounts).get(), hasLength(1));
    expect(await database.select(database.ledgerTransactions).get(), isEmpty);
    expect(find.text('Cuenta de origen'), findsOneWidget);
    final confirm = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Registrar gasto'),
    );
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Importe'),
      '45000',
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    final pending = await database
        .select(database.paymentCandidates)
        .getSingle();
    expect(pending.status, 'pending');
    expect(pending.amountMinor, 15000);
    expect(await database.select(database.ledgerTransactions).get(), isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/money/money.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:finanzas_locales/features/transactions/presentation/ledger_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late TransactionRecord purchase;
  late String bank;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
    bank = await AccountsService(db).createAccount(
      const CreateAccountDraft(
        name: 'Banco',
        type: AccountType.bank,
        initialBalanceMinor: 500000,
      ),
    );
    final id = await LedgerService(db).create(
      TransactionDraft(
        type: TransactionType.expense,
        amount: const Money(100000),
        occurredAt: DateTime(2026, 9, 10),
        fromAccountId: bank,
        description: 'Compra de prueba',
      ),
    );
    purchase = await (db.select(
      db.ledgerTransactions,
    )..where((t) => t.id.equals(id))).getSingle();
  });

  Future<void> openRefund(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          ),
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Center(
                child: FilledButton(
                  onPressed: () => showRefundDialog(context, ref, purchase),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  Future<void> openReconcile(WidgetTester tester) async {
    final account = (await tester.runAsync(
      () =>
          (db.select(db.accounts)..where((a) => a.id.equals(bank))).getSingle(),
    ))!;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Center(
                child: FilledButton(
                  onPressed: () => showReconcileDialog(context, ref, account),
                  child: const Text('Abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  Future<int> refundCount(WidgetTester tester) async => (await tester.runAsync(
    () => (db.select(
      db.ledgerTransactions,
    )..where((t) => t.type.equals('refund'))).get(),
  ))!.length;

  testWidgets(
    'importe vacío deja el diálogo abierto con el error en el campo',
    (tester) async {
      await seed(tester);
      await openRefund(tester);

      await tester.tap(find.text('Registrar'));
      await tester.pumpAndSettle();

      expect(find.text('Registrar devolución'), findsOneWidget);
      expect(find.text('Ingresá un importe.'), findsOneWidget);
      expect(await refundCount(tester), 0);
    },
  );

  testWidgets(
    'error del servicio deja el diálogo abierto con datos y mensaje',
    (tester) async {
      await seed(tester);
      await openRefund(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Importe PYG'),
        '100001',
      );

      await tester.tap(find.text('Registrar'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Registrar devolución'), findsOneWidget);
      expect(find.text('100.001'), findsOneWidget);
      final errorColor = Theme.of(tester.element(find.byType(AlertDialog)))
          .colorScheme
          .error;
      final errorTexts = tester
          .widgetList<Text>(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.byType(Text),
            ),
          )
          .where((text) => text.style?.color == errorColor);
      expect(errorTexts, isNotEmpty);
      expect(find.text('Devolución registrada.'), findsNothing);
      expect(await refundCount(tester), 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('conciliar a saldo real 0 es válido y registra el ajuste', (
    tester,
  ) async {
    await seed(tester);
    await openReconcile(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Saldo real PYG'),
      '0',
    );

    await tester.tap(find.text('Guardar ajuste'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Guardar ajuste'), findsNothing);
    expect(find.text('Ingresá un importe válido.'), findsNothing);
    expect(find.text('Saldo conciliado.'), findsOneWidget);
    expect(await tester.runAsync(() => LedgerService(db).balance(bank)), 0);
    expect(tester.takeException(), isNull);
  });
}

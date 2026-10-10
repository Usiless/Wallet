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
  late String bank, card, purchaseId;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> seed(WidgetTester tester) => tester.runAsync(() async {
    final accounts = AccountsService(db);
    bank = await accounts.createAccount(
      const CreateAccountDraft(
        name: 'Banco',
        type: AccountType.bank,
        initialBalanceMinor: 500000,
      ),
    );
    card = await accounts.createAccount(
      const CreateAccountDraft(
        name: 'Tarjeta',
        type: AccountType.creditCard,
        creditLimitMinor: 2000000,
      ),
    );
    purchaseId = await LedgerService(db).create(
      TransactionDraft(
        type: TransactionType.expense,
        amount: const Money(100000),
        occurredAt: DateTime(2026, 9, 10),
        fromAccountId: bank,
        description: 'Compra de prueba',
      ),
    );
  });

  Future<void> open(
    WidgetTester tester,
    Future<void> Function(BuildContext, WidgetRef) action,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Center(
                child: FilledButton(
                  onPressed: () => action(context, ref),
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

  /// Cierra el diálogo, espera la escritura real en la base y deja correr el
  /// retardo de limpieza avanzando el reloj por fotogramas, como en uso real.
  Future<void> finish(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 200));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  Future<List<TransactionRecord>> refunds() => (db.select(
    db.ledgerTransactions,
  )..where((t) => t.type.equals('refund'))).get();

  Future<AccountRecord> account(String id) =>
      (db.select(db.accounts)..where((a) => a.id.equals(id))).getSingle();

  group('devolución', () {
    testWidgets('registra la devolución vinculada a la compra', (tester) async {
      await seed(tester);
      final purchase = await tester.runAsync(
        () => (db.select(
          db.ledgerTransactions,
        )..where((t) => t.id.equals(purchaseId))).getSingle(),
      );
      await open(
        tester,
        (context, ref) => showRefundDialog(context, ref, purchase!),
      );
      expect(find.text('Registrar devolución'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Importe PYG'),
        '30000',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Nota'),
        'Producto defectuoso',
      );
      await tester.tap(find.text('Registrar'));
      await finish(tester);

      final rows = (await tester.runAsync(refunds))!;
      expect(rows, hasLength(1));
      expect(rows.single.amountMinor, 30000);
      expect(rows.single.parentTransactionId, purchaseId);
      expect(rows.single.note, 'Producto defectuoso');
      expect(find.text('Devolución registrada.'), findsOneWidget);
      expect(
        await tester.runAsync(() => LedgerService(db).balance(bank)),
        430000,
      );
    });

    testWidgets('importe vacío avisa y no escribe', (tester) async {
      await seed(tester);
      final purchase = await tester.runAsync(
        () => (db.select(
          db.ledgerTransactions,
        )..where((t) => t.id.equals(purchaseId))).getSingle(),
      );
      await open(
        tester,
        (context, ref) => showRefundDialog(context, ref, purchase!),
      );
      await tester.tap(find.text('Registrar'));
      await finish(tester);

      expect(find.textContaining('Ingresá un importe'), findsOneWidget);
      expect(find.text('Devolución registrada.'), findsNothing);
      expect(await tester.runAsync(refunds), isEmpty);
    });

    testWidgets('una devolución mayor que la compra se rechaza', (
      tester,
    ) async {
      await seed(tester);
      final purchase = await tester.runAsync(
        () => (db.select(
          db.ledgerTransactions,
        )..where((t) => t.id.equals(purchaseId))).getSingle(),
      );
      await open(
        tester,
        (context, ref) => showRefundDialog(context, ref, purchase!),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Importe PYG'),
        '100001',
      );
      await tester.tap(find.text('Registrar'));
      await finish(tester);

      expect(find.text('Devolución registrada.'), findsNothing);
      expect(await tester.runAsync(refunds), isEmpty);
      expect(
        await tester.runAsync(() => LedgerService(db).balance(bank)),
        400000,
      );
    });

    testWidgets('cancelar no escribe', (tester) async {
      await seed(tester);
      final purchase = await tester.runAsync(
        () => (db.select(
          db.ledgerTransactions,
        )..where((t) => t.id.equals(purchaseId))).getSingle(),
      );
      await open(
        tester,
        (context, ref) => showRefundDialog(context, ref, purchase!),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Importe PYG'),
        '30000',
      );
      await tester.tap(find.text('Cancelar'));
      await finish(tester);

      expect(await tester.runAsync(refunds), isEmpty);
      expect(
        await tester.runAsync(() => LedgerService(db).balance(bank)),
        400000,
      );
    });
  });

  group('conciliación', () {
    testWidgets('ajusta el saldo de una cuenta al valor real', (tester) async {
      await seed(tester);
      final target = (await tester.runAsync(() => account(bank)))!;
      await open(
        tester,
        (context, ref) => showReconcileDialog(context, ref, target),
      );
      expect(find.text('Conciliar · Banco'), findsOneWidget);
      expect(find.textContaining('Saldo registrado'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Saldo real PYG'),
        '350000',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Motivo del ajuste'),
        'Conteo',
      );
      await tester.tap(find.text('Guardar ajuste'));
      await finish(tester);

      expect(find.text('Saldo conciliado.'), findsOneWidget);
      expect(
        await tester.runAsync(() => LedgerService(db).balance(bank)),
        350000,
      );
    });

    testWidgets('en tarjeta usa deuda real y admite saldo a favor', (
      tester,
    ) async {
      await seed(tester);
      final target = (await tester.runAsync(() => account(card)))!;
      await open(
        tester,
        (context, ref) => showReconcileDialog(context, ref, target),
      );
      expect(find.widgetWithText(TextField, 'Deuda real PYG'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Deuda real PYG'),
        '10000',
      );
      await tester.tap(find.text('Saldo a favor'));
      await tester.enterText(
        find.widgetWithText(TextField, 'Motivo del ajuste'),
        'Estado de cuenta',
      );
      await tester.tap(find.text('Guardar ajuste'));
      await finish(tester);

      expect(
        await tester.runAsync(() => LedgerService(db).balance(card)),
        -10000,
      );
    });

    testWidgets('cancelar no crea ajuste', (tester) async {
      await seed(tester);
      final target = (await tester.runAsync(() => account(bank)))!;
      await open(
        tester,
        (context, ref) => showReconcileDialog(context, ref, target),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Saldo real PYG'),
        '1',
      );
      await tester.tap(find.text('Cancelar'));
      await finish(tester);

      expect(
        await tester.runAsync(() => LedgerService(db).balance(bank)),
        400000,
      );
    });
  });
}

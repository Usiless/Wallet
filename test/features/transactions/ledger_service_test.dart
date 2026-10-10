import 'package:drift/native.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/money/money.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_repository.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late AccountsService accounts;
  late LedgerService ledger;
  late LedgerRepository repository;
  late String bankId;
  late String cardId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    accounts = AccountsService(database);
    ledger = LedgerService(database);
    repository = LedgerRepository(database);
    bankId = await accounts.createAccount(
      const CreateAccountDraft(
        name: 'Banco',
        type: AccountType.bank,
        initialBalanceMinor: 1000000,
      ),
    );
    cardId = await accounts.createAccount(
      const CreateAccountDraft(
        name: 'Tarjeta',
        type: AccountType.creditCard,
        creditLimitMinor: 2000000,
        includeInAvailableMoney: false,
      ),
    );
  });

  tearDown(() => database.close());

  test(
    'ahorro admite transferencias y su inclusión no modifica el saldo',
    () async {
      final savingsId = await accounts.createAccount(
        const CreateAccountDraft(name: 'Reserva', type: AccountType.savings),
      );
      var saving = await (database.select(
        database.accounts,
      )..where((a) => a.id.equals(savingsId))).getSingle();
      expect(saving.includeInAvailableMoney, isFalse);
      expect(saving.includeInNetWorth, isTrue);
      await ledger.create(
        TransactionDraft(
          type: TransactionType.transfer,
          amount: const Money(100000),
          occurredAt: DateTime.now(),
          fromAccountId: bankId,
          toAccountId: savingsId,
        ),
      );
      await ledger.create(
        TransactionDraft(
          type: TransactionType.transfer,
          amount: const Money(20000),
          occurredAt: DateTime.now(),
          fromAccountId: savingsId,
          toAccountId: bankId,
        ),
      );
      await accounts.setSavingsIncludedInAvailableMoney(savingsId, true);
      final balance = (await repository.watchAccountBalances().first)
          .firstWhere((a) => a.id == savingsId);
      expect(balance.balanceMinor, 80000);
      expect(balance.includeInAvailableMoney, isTrue);
      await accounts.setSavingsIncludedInAvailableMoney(savingsId, false);
      final excluded = (await repository.watchAccountBalances().first)
          .firstWhere((a) => a.id == savingsId);
      expect(excluded.balanceMinor, 80000);
      expect(excluded.includeInAvailableMoney, isFalse);
      await expectLater(
        accounts.setSavingsIncludedInAvailableMoney(cardId, true),
        throwsException,
      );
    },
  );

  test('canal incompatible no guarda movimiento ni modifica saldos', () async {
    final cashId = await accounts.createAccount(
      const CreateAccountDraft(
        name: 'Efectivo',
        type: AccountType.cash,
        initialBalanceMinor: 100000,
      ),
    );
    for (final channel in [
      PaymentChannel.onlineCard,
      PaymentChannel.googleWalletContactless,
      PaymentChannel.physicalCard,
    ]) {
      await expectLater(
        ledger.create(
          TransactionDraft(
            type: TransactionType.expense,
            amount: const Money(10000),
            occurredAt: DateTime.now(),
            fromAccountId: cashId,
            paymentChannel: channel,
          ),
        ),
        throwsException,
      );
    }
    await expectLater(
      ledger.create(
        TransactionDraft(
          type: TransactionType.expense,
          amount: const Money(10000),
          occurredAt: DateTime.now(),
          fromAccountId: bankId,
          paymentChannel: PaymentChannel.cash,
        ),
      ),
      throwsException,
    );
    expect(await database.select(database.ledgerTransactions).get(), isEmpty);
    expect(await database.select(database.accountPostings).get(), isEmpty);
  });

  test('compra y pago parcial mantienen deuda y no duplican gasto', () async {
    await ledger.create(
      TransactionDraft(
        type: TransactionType.expense,
        amount: const Money(300000),
        occurredAt: DateTime.utc(2026, 7, 10),
        fromAccountId: cardId,
        description: 'Compra',
      ),
    );
    await ledger.create(
      TransactionDraft(
        type: TransactionType.transfer,
        amount: const Money(100000),
        occurredAt: DateTime.utc(2026, 7, 15),
        fromAccountId: bankId,
        toAccountId: cardId,
        description: 'Pago parcial',
      ),
    );
    final balances = await repository.watchAccountBalances().first;
    expect(
      balances.singleWhere((row) => row.id == bankId).balanceMinor,
      900000,
    );
    expect(
      balances.singleWhere((row) => row.id == cardId).balanceMinor,
      200000,
    );
    final expenses = await (database.select(
      database.ledgerTransactions,
    )..where((table) => table.type.equals('expense'))).get();
    expect(expenses, hasLength(1));
  });

  test(
    'eliminación lógica revierte postings y deshacer los restaura',
    () async {
      final id = await ledger.create(
        TransactionDraft(
          type: TransactionType.expense,
          amount: const Money(50000),
          occurredAt: DateTime.utc(2026, 7, 10),
          fromAccountId: bankId,
        ),
      );
      await ledger.softDelete(id);
      var balances = await repository.watchAccountBalances().first;
      expect(
        balances.singleWhere((row) => row.id == bankId).balanceMinor,
        1000000,
      );
      await ledger.restore(id);
      balances = await repository.watchAccountBalances().first;
      expect(
        balances.singleWhere((row) => row.id == bankId).balanceMinor,
        950000,
      );
    },
  );

  test('dos deshacer concurrentes restauran el saldo una sola vez', () async {
    final id = await ledger.create(
      TransactionDraft(
        type: TransactionType.expense,
        amount: const Money(50000),
        occurredAt: DateTime(2026, 10, 4),
        fromAccountId: bankId,
      ),
    );
    await ledger.softDelete(id);
    final results = await Future.wait([
      for (var i = 0; i < 2; i++)
        ledger.restore(id).then((_) => true).catchError((Object _) => false),
    ]);
    expect(results.where((success) => success), hasLength(1));
    final balance = (await repository.watchAccountBalances().first).singleWhere(
      (row) => row.id == bankId,
    );
    expect(balance.balanceMinor, 950000);
  });

  test('reporte mensual incluye más de 100 compras y excluye pendientes y otros meses', () async {
    for (var i = 0; i < 105; i++) {
      await ledger.create(
        TransactionDraft(
          type: TransactionType.expense,
          amount: const Money(1000),
          occurredAt: DateTime(2026, 10, 1, 0, 1),
          fromAccountId: bankId,
        ),
      );
    }
    await ledger.create(
      TransactionDraft(
        type: TransactionType.expense,
        status: TransactionStatus.pending,
        amount: const Money(9999),
        occurredAt: DateTime(2026, 10, 5),
        fromAccountId: bankId,
      ),
    );
    await ledger.create(
      TransactionDraft(
        type: TransactionType.expense,
        amount: const Money(9999),
        occurredAt: DateTime(2026, 11),
        fromAccountId: bankId,
      ),
    );
    final month = await repository
        .watchConfirmedMonth(DateTime(2026, 10))
        .first;
    expect(month, hasLength(105));
    expect(month.fold<int>(0, (sum, row) => sum + row.amountMinor), 105000);
  });

  test('esquema v1 habilita claves foráneas y preserva datos', () async {
    expect(database.schemaVersion, 1);
    final version = await database
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.read<int>('user_version'), 1);
    expect(await accounts.findByNameOrAlias('Banco'), isNotNull);
  });
}

import 'dart:io';

import 'package:drift/native.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/backup/backup_service.dart';
import 'package:finanzas_locales/core/money/money.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/installments/domain/installment_calculator.dart';
import 'package:finanzas_locales/features/installments/domain/installment_service.dart';
import 'package:finanzas_locales/features/reports/data/report_service.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_repository.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late LedgerService ledger;
  late String card, bank;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ledger = LedgerService(db);
    card = await AccountsService(db).createAccount(
      const CreateAccountDraft(
        name: 'Tarjeta ficticia',
        type: AccountType.creditCard,
        creditLimitMinor: 2000000,
      ),
    );
    bank = await AccountsService(db).createAccount(
      const CreateAccountDraft(
        name: 'Banco ficticio',
        type: AccountType.bank,
        initialBalanceMinor: 1000000,
      ),
    );
  });
  tearDown(() => db.close());
  TransactionDraft purchase({int amount = 1000000, DateTime? date}) =>
      TransactionDraft(
        type: TransactionType.expense,
        amount: Money(amount),
        occurredAt: date ?? DateTime(2026, 10, 6),
        fromAccountId: card,
        description: 'Compra ficticia 100%',
      );
  Future<String> create({DateTime? first}) => db.transaction(() async {
    final id = await ledger.create(purchase());
    await InstallmentService(db).attachPlan(
      transactionId: id,
      count: 10,
      firstPeriod: first ?? DateTime(2026, 10, 6),
    );
    return id;
  });
  Future<ReportTotals> report(int month) => ReportService(db).watch((
    start: DateTime(2026, month),
    end: DateTime(2026, month + 1),
    category: null,
    monthlyInstallments: true,
  )).first;

  test('día 31 recuperado tras febrero común y bisiesto; enteros exactos', () {
    for (final year in [2024, 2025]) {
      final plan = const InstallmentCalculator().schedule(
        totalMinor: 101,
        count: 3,
        firstPeriod: DateTime(year, 1, 31),
      );
      expect(plan.map((e) => e.periodStart.day), [
        31,
        year == 2024 ? 29 : 28,
        31,
      ]);
      expect(plan.map((e) => e.amountMinor), [33, 33, 35]);
    }
  });
  test(
    'deuda completa inmediata y filas mensuales sin duplicar pagos',
    () async {
      final id = await create();
      expect(await ledger.balance(card), 1000000);
      expect((await report(10)).expenses, 100000);
      final repo = LedgerRepository(db),
          rows = await repo
              .watchMovements(
                filter: (
                  search: '100%',
                  account: null,
                  merchant: null,
                  category: null,
                  type: 'expense',
                  start: DateTime(2026, 10),
                  end: DateTime(2027, 8),
                ),
              )
              .first;
      expect(rows, hasLength(10));
      expect(
        rows.every((r) => r.transaction.id == id && r.amountMinor == 100000),
        isTrue,
      );
      expect(rows.map((r) => r.number).toSet(), hasLength(10));
      expect(await db.select(db.ledgerTransactions).get(), hasLength(1));
      await ledger.create(
        TransactionDraft(
          type: TransactionType.transfer,
          amount: const Money(100000),
          occurredAt: DateTime(2026, 10, 6),
          fromAccountId: bank,
          toAccountId: card,
          paymentChannel: PaymentChannel.bankTransfer,
        ),
      );
      expect(await ledger.balance(card), 900000);
      expect((await report(10)).expenses, 100000);
    },
  );
  test(
    'diferir primera fecha conserva deuda y filtra cuotas por fecha exacta',
    () async {
      await create(first: DateTime(2026, 11, 6));
      expect(await ledger.balance(card), 1000000);
      expect((await report(10)).expenses, 0);
      expect((await report(11)).expenses, 100000);
      Future<List<MovementRow>> range(int end) =>
          LedgerRepository(db)
              .watchMovements(
                filter: (
                  search: '',
                  account: null,
                  merchant: null,
                  category: null,
                  type: null,
                  start: DateTime(2026, 11, 1),
                  end: DateTime(2026, 11, end),
                ),
              )
              .first;
      expect(await range(6), isEmpty);
      final rows = await range(7);
      expect(rows.single.occurredAt, DateTime(2026, 11, 6));
      expect(rows.single.planned, isTrue);
    },
  );
  test('fallo al adjuntar plan revierte compra y partidas; fecha anterior se rechaza', () async {
    await expectLater(create(first: DateTime(2026, 10, 5)), throwsException);
    expect(await db.select(db.ledgerTransactions).get(), isEmpty);
    expect(await db.select(db.accountPostings).get(), isEmpty);
    expect(await ledger.balance(card), 0);
  });
  test(
    'ediciones concurrentes no sobrescriben calendario ni duplican compra',
    () async {
      final id = await create();
      final original = await db.select(db.ledgerTransactions).getSingle();
      final results = await Future.wait([
        for (final day in [6, 7])
          ledger
              .update(
                id,
                purchase(),
                expectedUpdatedAt: original.updatedAt,
                firstInstallmentDate: DateTime(2026, 11, day),
              )
              .then((_) => true)
              .catchError((Object e) => false),
      ]);
      expect(results.where((v) => v), hasLength(1));
      expect(await db.select(db.ledgerTransactions).get(), hasLength(1));
      expect(await db.select(db.installmentEntries).get(), hasLength(10));
      expect((await report(10)).expenses, 0);
    },
  );
  test('respaldo conserva fechas, referencias y una sola compra; invalida borradores', () async {
    final directory = await Directory.systemTemp.createTemp(
      'cabal-monthly-backup-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final id = await create(first: DateTime(2026, 11, 30));
    final service = BackupService(db, directory: directory);
    final before = await db.select(db.installmentEntries).get();
    final bytes = await service.createBytes('contraseña ficticia');
    await ledger.softDelete(id);
    await service.restore(bytes, 'contraseña ficticia');
    expect(db.restoreGeneration, 1);
    expect(await db.select(db.installmentEntries).get(), before);
    expect(await db.select(db.ledgerTransactions).get(), hasLength(1));
    expect(await ledger.balance(card), 1000000);
  });
  test(
    'planes históricos mantienen día 1 al editar sin reemplazar fecha',
    () async {
      final id = await ledger.create(purchase(date: DateTime(2026, 9, 20)));
      await InstallmentService(db).attachPlan(
        transactionId: id,
        count: 3,
        firstPeriod: DateTime(2026, 9, 1),
        preserveHistoricalDate: true,
      );
      await ledger.update(
        id,
        purchase(amount: 900000, date: DateTime(2026, 9, 20)),
      );
      final plan = await db.select(db.installmentEntries).get();
      expect(plan.every((e) => e.periodStart.toUtc().day == 1), isTrue);
      expect(plan.fold<int>(0, (s, e) => s + e.amountMinor), 900000);
    },
  );
}

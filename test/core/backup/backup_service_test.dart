import 'package:finanzas_locales/core/database/encrypted_storage.dart';

import 'dart:io';
import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:finanzas_locales/features/payments/domain/pending_payment_service.dart';

import 'package:drift/native.dart';
import 'package:finanzas_locales/core/backup/backup_service.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/errors/app_exception.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_service.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_repository.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:finanzas_locales/core/money/money.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:typed_data';

void main() {
  late Directory directory;
  late AppDatabase database;
  late BackupService service;
  late Uint8List backup;
  late String restoredAccount;
  const password = 'clave de prueba ñ';
  setUpAll(() async {
    final sourceDirectory = await Directory.systemTemp.createTemp(
      'wallet-backup-source-',
    );
    final source = AppDatabase.forTesting(NativeDatabase.memory());
    restoredAccount = await AccountsService(source).createAccount(
      const CreateAccountDraft(
        name: 'Cuenta del backup',
        type: AccountType.bank,
        initialBalanceMinor: 100000,
      ),
    );
    await LedgerService(source).create(
      TransactionDraft(
        type: TransactionType.expense,
        amount: const Money(20000),
        occurredAt: DateTime(2026, 10, 4),
        fromAccountId: restoredAccount,
      ),
    );
    backup = await BackupService(
      source,
      directory: sourceDirectory,
    ).createBytes(password);
    await source.close();
    await sourceDirectory.delete(recursive: true);
  });
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('wallet-restore-test-');
    database = AppDatabase.forTesting(NativeDatabase.memory());
    await AccountsService(database).createAccount(
      const CreateAccountDraft(
        name: 'Estado actual',
        type: AccountType.bank,
        initialBalanceMinor: 90000,
      ),
    );
    service = BackupService(database, directory: directory);
  });
  tearDown(() async {
    await database.close();
    await directory.delete(recursive: true);
  });

  test('versioned obligations and linked payments round trip; missing account rejected', () async {
    final account = (await database.select(database.accounts).get()).single.id;
    final payments = PendingPaymentService(database);
    final p = (await payments.createPlan(
      amountMinor: 1000,
      installmentCount: 1,
      firstDueDate: DateTime(2026, 10, 7),
      accountId: account,
    )).single;
    await payments.pay(
      id: p.id,
      expectedRevision: 0,
      amountMinor: 300,
      paidAt: DateTime(2026, 10, 7),
      accountId: account,
    );
    final bytes = await service.createBytes(password);
    await service.restore(bytes, password);
    expect((await payments.read(p.id))!.remainingMinor, 700);
    final row =
        await (database.select(database.appSettings)..where(
              (s) => s.key.equals('${PendingPaymentService.prefix}${p.id}'),
            ))
            .getSingle();
    final json = Map<String, dynamic>.from(jsonDecode(row.value) as Map)
      ..['accountId'] = 'missing';
    await (database.update(database.appSettings)
          ..where((s) => s.key.equals(row.key)))
        .write(AppSettingsCompanion(value: Value(jsonEncode(json))));
    final invalid = await service.createBytes(password);
    await expectLater(
      service.restore(invalid, password),
      throwsA(isA<BackupException>()),
    );
  });
  test('edited and deleted linked payments remain portable', () async {
    final account = (await database.select(database.accounts).get()).single.id;
    final payments = PendingPaymentService(database);
    final p = (await payments.createPlan(
      amountMinor: 1000,
      installmentCount: 1,
      firstDueDate: DateTime(2026, 10, 7),
      accountId: account,
    )).single;
    final tx = await payments.pay(
      id: p.id,
      expectedRevision: 0,
      amountMinor: 300,
      paidAt: DateTime(2026, 10, 7),
      accountId: account,
    );
    await LedgerService(database).update(
      tx,
      TransactionDraft(
        type: TransactionType.expense,
        amount: const Money(200),
        occurredAt: DateTime(2026, 10, 8),
        fromAccountId: account,
      ),
    );
    await service.restore(await service.createBytes(password), password);
    expect((await payments.read(p.id))!.remainingMinor, 800);
    await LedgerService(database).softDelete(tx);
    await service.restore(await service.createBytes(password), password);
    expect((await payments.read(p.id))!.remainingMinor, 1000);
  });
  test(
    'backup rejects forged unrelated payment and invalid installment metadata',
    () async {
      final account =
          (await database.select(database.accounts).get()).single.id;
      final payments = PendingPaymentService(database);
      final p = (await payments.createPlan(
        amountMinor: 1000,
        installmentCount: 1,
        firstDueDate: DateTime(2026, 10, 7),
        accountId: account,
      )).single;
      final unrelated = await LedgerService(database).create(
        TransactionDraft(
          type: TransactionType.expense,
          amount: const Money(100),
          occurredAt: DateTime(2026, 10, 7),
          fromAccountId: account,
        ),
      );
      final key = '${PendingPaymentService.prefix}${p.id}';
      for (final corrupt in [
        <String, dynamic>{
          'payments': [
            {
              'transactionId': unrelated,
              'amountMinor': 100,
              'paidAt': DateTime(2026, 10, 7).toIso8601String(),
              'accountId': account,
              'splits': [],
            },
          ],
        },
        <String, dynamic>{'installmentNumber': 0},
      ]) {
        await (database.update(
          database.appSettings,
        )..where((s) => s.key.equals(key))).write(
          AppSettingsCompanion(
            value: Value(jsonEncode({...p.data, ...corrupt})),
          ),
        );
        await expectLater(
          service.restore(await service.createBytes(password), password),
          throwsA(isA<BackupException>()),
        );
      }
    },
  );
  test(
    'restaura sin cerrar conexión y conserva respaldo cifrado anterior',
    () async {
      final stages = <String>[];
      await service.restore(backup, password, onProgress: stages.add);
      expect(stages.last, 'Restauración completada');
      final accounts = await database.select(database.accounts).get();
      expect(accounts.single.id, restoredAccount);
      expect(
        (await LedgerRepository(
          database,
        ).watchAccountBalances().first).single.balanceMinor,
        80000,
      );
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
      final safety = directory
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.finbackup'))
          .single;
      // Restoring the safety copy exercises a second restoration on the same open connection.
      await service.restore(await safety.readAsBytes(), password);
      expect(
        (await database.select(database.accounts).get()).single.name,
        'Estado actual',
      );
      expect(
        directory.listSync().whereType<File>().where(
          (file) => file.path.endsWith('.sqlite'),
        ),
        isEmpty,
      );
    },
  );
  test(
    'contraseña incorrecta no cambia la base y no deja copia descifrada',
    () async {
      await expectLater(
        service.restore(backup, 'otra contraseña'),
        throwsA(isA<BackupException>()),
      );
      expect(
        (await database.select(database.accounts).get()).single.name,
        'Estado actual',
      );
      expect(directory.listSync(), isEmpty);
    },
  );
  test('fallo al insertar revierte todas las tablas y permite seguir usando la conexión', () async {
    await database.customStatement(
      "CREATE TRIGGER fail_restore BEFORE INSERT ON accounts BEGIN SELECT RAISE(ABORT, 'fallo descartable'); END",
    );
    await expectLater(
      service.restore(backup, password),
      throwsA(
        predicate(
          (Object error) => error.toString().contains('fallo descartable'),
        ),
      ),
    );
    expect(
      (await database.select(database.accounts).get()).single.name,
      'Estado actual',
    );
    expect(await database.select(database.ledgerTransactions).get(), isEmpty);
    expect(
      await database.customSelect('PRAGMA foreign_key_check').get(),
      isEmpty,
    );
  });
  test(
    'backup y restauración son portables manteniendo la base activa cifrada',
    () async {
      const key =
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final file = File('${directory.path}/encrypted.sqlite');
      final encryptedDb = AppDatabase.forTesting(
        NativeDatabase(
          file,
          setup: (raw) {
            requireCipher(raw);
            raw.execute("PRAGMA key = '$key'");
          },
        ),
      );
      try {
        await AccountsService(encryptedDb).createAccount(
          const CreateAccountDraft(
            name: 'Base cifrada',
            type: AccountType.bank,
            initialBalanceMinor: 12345,
          ),
        );
        final protectedService = BackupService(
          encryptedDb,
          directory: directory,
          encryptionKey: () async => key,
        );
        final portable = await protectedService.createBytes(password);
        expect(isPlaintextDatabase(file), isFalse);
        final decoded = await protectedService.codec.decode(
          portable,
          password: password,
        );
        expect(
          String.fromCharCodes(decoded.databaseBytes.take(16)),
          'SQLite format 3\u0000',
        );
        await protectedService.restore(backup, password);
        expect(
          (await encryptedDb.select(encryptedDb.accounts).get()).single.id,
          restoredAccount,
        );
        expect(isPlaintextDatabase(file), isFalse);
      } finally {
        await encryptedDb.close();
      }
    },
  );
}

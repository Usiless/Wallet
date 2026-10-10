import 'package:drift/native.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/imports/data/csv_import_service.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late CsvImportService service;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final accounts = AccountsService(database);
    await accounts.createAccount(
      const CreateAccountDraft(
        name: 'Cuenta principal',
        type: AccountType.bank,
      ),
    );
    service = CsvImportService(database, accounts, LedgerService(database));
  });

  tearDown(() => database.close());

  test('importa filas válidas atómicamente y revierte el lote', () async {
    const csv =
        'fecha;tipo;importe;moneda;cuenta_origen;cuenta_destino;categoria;subcategoria;comercio;canal;nota;referencia\n'
        '2026-07-07;gasto;75000;PYG;Cuenta principal;;Alimentación;;Tienda;debito;;compra-1\n'
        'fecha-mala;gasto;10000;PYG;Cuenta principal;;;;;;;mala';
    final preview = await service.preview(csv);
    expect(preview.validCount, 1);
    expect(preview.invalidCount, 1);

    final batchId = await service.importValid(
      preview,
      fileName: 'prueba.csv',
      createUnknownCategories: true,
    );
    var transactions = await database.select(database.ledgerTransactions).get();
    expect(transactions, hasLength(1));
    expect(transactions.single.importBatchId, batchId);
    expect(transactions.single.status, 'confirmed');
    expect(await database.select(database.importRows).get(), hasLength(2));

    await service.revertBatch(batchId);
    transactions = await database.select(database.ledgerTransactions).get();
    expect(transactions.single.status, 'deleted');
    expect(await database.select(database.accountPostings).get(), isEmpty);
    final batch = await database.select(database.importBatches).getSingle();
    expect(batch.status, 'reverted');
  });

  test('P03: los metadatos importados históricos permanecen legibles', () async {
    const csv =
        'fecha;tipo;importe;moneda;cuenta_origen;cuenta_destino;categoria;subcategoria;comercio;canal;nota;referencia\n2026-07-07;gasto;75000;PYG;Cuenta principal;;;;Tienda;debito;nota;compra-antigua';
    await service.importValid(
      await service.preview(csv),
      fileName: 'histórico.csv',
    );
    final row = await database.select(database.ledgerTransactions).getSingle();
    expect(row.sourceReference, 'compra-antigua');
    expect(row.source, 'csv');
    expect(row.importBatchId, isNotNull);
    expect(await database.select(database.importRows).get(), hasLength(1));
  });
}

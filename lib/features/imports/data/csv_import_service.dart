import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/money/money.dart';
import '../../../core/text/normalization.dart';
import '../../accounts/data/accounts_service.dart';
import '../../transactions/data/ledger_service.dart';
import '../../transactions/domain/ledger_models.dart';
import '../domain/csv_import_models.dart';
import '../domain/csv_import_parser.dart';

final class CsvImportService {
  CsvImportService(
    this.database,
    this.accounts,
    this.ledger, {
    Uuid? uuid,
    CsvImportParser? parser,
  }) : uuid = uuid ?? const Uuid(),
       parser = parser ?? const CsvImportParser();

  final AppDatabase database;
  final AccountsService accounts;
  final LedgerService ledger;
  final Uuid uuid;
  final CsvImportParser parser;

  Future<CsvImportPreview> preview(String content, {String? delimiter}) async {
    final accountRows = await accounts.getAccounts();
    final categories = await database.select(database.categories).get();
    final references =
        await (database.selectOnly(database.ledgerTransactions)
              ..addColumns([database.ledgerTransactions.sourceReference])
              ..where(database.ledgerTransactions.sourceReference.isNotNull()))
            .map(
              (row) => row.read(database.ledgerTransactions.sourceReference)!,
            )
            .get();
    final fingerprints =
        await (database.selectOnly(database.ledgerTransactions)
              ..addColumns([database.ledgerTransactions.externalFingerprint])
              ..where(
                database.ledgerTransactions.externalFingerprint.isNotNull(),
              ))
            .map(
              (row) =>
                  row.read(database.ledgerTransactions.externalFingerprint)!,
            )
            .get();
    return parser.parse(
      content,
      delimiter: delimiter,
      existingReferences: references.toSet(),
      existingFingerprints: fingerprints.toSet(),
      knownAccounts: accountRows.map((row) => row.name).toSet(),
      knownCategories: categories.map((row) => row.name).toSet(),
    );
  }

  Future<String> importValid(
    CsvImportPreview preview, {
    required String fileName,
    bool createUnknownCategories = false,
  }) async {
    final valid = preview.rows.where((row) => row.isValid).toList();
    if (valid.isEmpty) {
      throw const ValidationException('No hay filas válidas para importar.');
    }
    final batchId = uuid.v4();
    final now = DateTime.now().toUtc();
    await database
        .into(database.importBatches)
        .insert(
          ImportBatchesCompanion.insert(
            id: batchId,
            fileName: fileName,
            delimiter: Value(preview.delimiter),
            status: 'importing',
            validRows: Value(valid.length),
            invalidRows: Value(preview.invalidCount),
            duplicateRows: Value(preview.duplicateCount),
            createdAt: now,
          ),
        );

    try {
      await database.transaction(() async {
        for (final rowPreview in preview.rows) {
          final rowId = uuid.v4();
          String? transactionId;
          if (rowPreview.isValid) {
            final row = rowPreview.value!;
            final from = await _account(row.fromAccountName);
            final to = await _account(row.toAccountName);
            final categoryId = await _category(
              row.subcategory ?? row.category,
              create: createUnknownCategories,
            );
            transactionId = await ledger.create(
              TransactionDraft(
                type: row.type,
                amount: Money(row.amountMinor, currencyCode: row.currencyCode),
                occurredAt: row.occurredAt,
                source: TransactionSource.csv,
                fromAccountId: from?.id,
                toAccountId: to?.id,
                description: row.merchant ?? '',
                note: row.note,
                paymentChannel: row.channel,
                splits: categoryId == null
                    ? const []
                    : [
                        SplitDraft(
                          categoryId: categoryId,
                          amountMinor: row.amountMinor,
                        ),
                      ],
                externalFingerprint: row.fingerprint,
                sourceReference: row.reference,
                importBatchId: batchId,
              ),
            );
          }
          await database
              .into(database.importRows)
              .insert(
                ImportRowsCompanion.insert(
                  id: rowId,
                  batchId: batchId,
                  rowNumber: rowPreview.rowNumber,
                  originalJson: jsonEncode(rowPreview.original),
                  status: rowPreview.isDuplicate
                      ? 'duplicate'
                      : rowPreview.errors.isNotEmpty
                      ? 'invalid'
                      : 'imported',
                  errorsJson: Value(jsonEncode(rowPreview.errors)),
                  fingerprint: Value(rowPreview.value?.fingerprint),
                  transactionId: Value(transactionId),
                ),
              );
        }
        await (database.update(
          database.importBatches,
        )..where((table) => table.id.equals(batchId))).write(
          ImportBatchesCompanion(
            status: const Value('completed'),
            importedAt: Value(DateTime.now().toUtc()),
          ),
        );
      });
      return batchId;
    } catch (_) {
      await (database.update(database.importBatches)
            ..where((table) => table.id.equals(batchId)))
          .write(const ImportBatchesCompanion(status: Value('failed')));
      rethrow;
    }
  }

  Future<void> revertBatch(String batchId) async {
    final batch = await (database.select(
      database.importBatches,
    )..where((table) => table.id.equals(batchId))).getSingleOrNull();
    if (batch == null ||
        batch.status != 'completed' ||
        batch.revertedAt != null) {
      throw const ValidationException('Este lote no se puede revertir.');
    }
    final rows =
        await (database.select(database.importRows)..where(
              (table) =>
                  table.batchId.equals(batchId) &
                  table.transactionId.isNotNull(),
            ))
            .get();
    for (final row in rows) {
      await ledger.softDelete(row.transactionId!);
    }
    await (database.update(
      database.importBatches,
    )..where((table) => table.id.equals(batchId))).write(
      ImportBatchesCompanion(
        status: const Value('reverted'),
        revertedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<AccountRecord?> _account(String? name) async {
    if (name == null) return null;
    final account = await accounts.findByNameOrAlias(name);
    if (account == null) throw ValidationException('Cuenta sin mapear: $name.');
    return account;
  }

  Future<String?> _category(String? name, {required bool create}) async {
    if (name == null) return null;
    final normalized = normalizeForMatching(name);
    final rows = await database.select(database.categories).get();
    for (final row in rows) {
      if (normalizeForMatching(row.name) == normalized) return row.id;
    }
    if (!create) throw ValidationException('Categoría sin mapear: $name.');
    final id = uuid.v4();
    final now = DateTime.now().toUtc();
    await database
        .into(database.categories)
        .insert(
          CategoriesCompanion.insert(
            id: id,
            name: name,
            kind: 'both',
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }
}

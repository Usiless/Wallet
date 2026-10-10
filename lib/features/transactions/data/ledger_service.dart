import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/money/money.dart';
import '../domain/ledger_models.dart';
import '../domain/posting_calculator.dart';
import '../domain/payment_channel_policy.dart';
import '../../installments/domain/installment_service.dart';

final class LedgerService {
  LedgerService(this.database, {Uuid? uuid, PostingCalculator? calculator})
    : uuid = uuid ?? const Uuid(),
      calculator = calculator ?? const PostingCalculator();

  final AppDatabase database;
  final Uuid uuid;
  final PostingCalculator calculator;

  Future<String> create(TransactionDraft draft) =>
      database.transaction(() async {
        await _validateRefund(draft);
        final from = await _loadAccount(draft.fromAccountId);
        final to = await _loadAccount(draft.toAccountId);
        PaymentChannelPolicy.validate(draft, from: from, to: to);
        final postings = calculator.calculate(draft, from: from, to: to);
        final now = DateTime.now().toUtc();
        final transactionId = uuid.v4();

        await database.transaction(() async {
          await database
              .into(database.ledgerTransactions)
              .insert(
                LedgerTransactionsCompanion.insert(
                  id: transactionId,
                  type: draft.type.name,
                  status: draft.status.name,
                  source: draft.source.name,
                  occurredAt: draft.occurredAt.toUtc(),
                  occurredTimeZone: Value(draft.timeZone),
                  createdAt: now,
                  updatedAt: now,
                  currencyCode: draft.amount.currencyCode,
                  amountMinor: draft.amount.minorUnits,
                  fromAccountId: Value(draft.fromAccountId),
                  toAccountId: Value(draft.toAccountId),
                  merchantId: Value(draft.merchantId),
                  description: Value(draft.description.trim()),
                  note: Value(draft.note.trim()),
                  paymentChannel: Value(draft.paymentChannel.name),
                  externalFingerprint: Value(draft.externalFingerprint),
                  sourceReference: Value(draft.sourceReference),
                  importBatchId: Value(draft.importBatchId),
                  parentTransactionId: Value(draft.parentTransactionId),
                ),
              );

          for (final posting in postings) {
            await database
                .into(database.accountPostings)
                .insert(
                  AccountPostingsCompanion.insert(
                    id: uuid.v4(),
                    transactionId: transactionId,
                    accountId: posting.accountId,
                    deltaMinor: posting.deltaMinor,
                    currencyCode: draft.amount.currencyCode,
                    occurredAt: draft.occurredAt.toUtc(),
                    createdAt: now,
                  ),
                );
          }

          for (final split in draft.splits) {
            await database
                .into(database.transactionSplits)
                .insert(
                  TransactionSplitsCompanion.insert(
                    id: uuid.v4(),
                    transactionId: transactionId,
                    categoryId: split.categoryId,
                    amountMinor: split.amountMinor,
                    note: Value(split.note),
                  ),
                );
          }

          await database
              .into(database.auditLogs)
              .insert(
                AuditLogsCompanion.insert(
                  id: uuid.v4(),
                  entityType: 'transaction',
                  entityId: transactionId,
                  action: 'created',
                  changesJson: Value(jsonEncode({'source': draft.source.name})),
                  createdAt: now,
                ),
              );
        });
        return transactionId;
      });

  Future<int> balance(String accountId) async {
    final account = await (database.select(
      database.accounts,
    )..where((t) => t.id.equals(accountId))).getSingle();
    final postings = await (database.select(
      database.accountPostings,
    )..where((t) => t.accountId.equals(accountId))).get();
    return account.initialBalanceMinor +
        postings.fold<int>(0, (sum, p) => sum + p.deltaMinor);
  }

  Future<String> reconcile({
    required String accountId,
    required int targetMinor,
    required int expectedBalance,
    required String note,
  }) => database.transaction(() async {
    final account = await _loadAccount(accountId);
    final current = await balance(accountId);
    if (current != expectedBalance) {
      throw const ValidationException(
        'El saldo cambió mientras conciliabas. Volvé a intentarlo.',
      );
    }
    final delta = targetMinor - current;
    if (delta == 0) {
      throw const ValidationException(
        'El saldo ya coincide; no hace falta un ajuste.',
      );
    }
    final increaseByInflow = account!.isLiability ? delta < 0 : delta > 0;
    return create(
      TransactionDraft(
        type: TransactionType.adjustment,
        source: TransactionSource.adjustment,
        amount: Money(delta.abs(), currencyCode: account.currencyCode),
        occurredAt: DateTime.now(),
        fromAccountId: increaseByInflow ? null : accountId,
        toAccountId: increaseByInflow ? accountId : null,
        description: 'Conciliación de saldo',
        note: note,
      ),
    );
  });

  Future<String> refund({
    required String purchaseId,
    required int amountMinor,
    required DateTime occurredAt,
    String note = '',
  }) => database.transaction(() async {
    final purchase =
        await (database.select(database.ledgerTransactions)..where(
              (t) =>
                  t.id.equals(purchaseId) &
                  t.status.equals('confirmed') &
                  t.type.equals('expense'),
            ))
            .getSingleOrNull();
    if (purchase == null) {
      throw const ValidationException('Elegí una compra confirmada.');
    }
    final originals =
        await (database.select(database.transactionSplits)
              ..where((t) => t.transactionId.equals(purchaseId))
              ..orderBy([(t) => OrderingTerm.asc(t.id)]))
            .get();
    final previous =
        await (database.select(database.ledgerTransactions)..where(
              (t) =>
                  t.parentTransactionId.equals(purchaseId) &
                  t.type.equals('refund') &
                  t.status.equals('confirmed'),
            ))
            .get();
    final priorSplits = await (database.select(
      database.transactionSplits,
    )..where((t) => t.transactionId.isIn(previous.map((r) => r.id)))).get();
    final weights = <String, int>{};
    for (final split in originals) {
      weights.update(
        split.categoryId,
        (v) => v + split.amountMinor,
        ifAbsent: () => split.amountMinor,
      );
    }
    for (final split in priorSplits) {
      if (weights.containsKey(split.categoryId)) {
        weights[split.categoryId] =
            (weights[split.categoryId]! - split.amountMinor).clamp(0, 1 << 62);
      }
    }
    final remainingWeight = weights.values.fold<int>(0, (sum, v) => sum + v);
    int cumulative = 0, assigned = 0;
    final splits = <SplitDraft>[];
    for (final entry in weights.entries) {
      if (remainingWeight == 0) break;
      cumulative += entry.value;
      final total = amountMinor * cumulative ~/ remainingWeight;
      final portion = total - assigned;
      assigned = total;
      if (portion > 0) {
        splits.add(SplitDraft(categoryId: entry.key, amountMinor: portion));
      }
    }
    return create(
      TransactionDraft(
        type: TransactionType.refund,
        amount: Money(amountMinor, currencyCode: purchase.currencyCode),
        occurredAt: occurredAt,
        toAccountId: purchase.fromAccountId,
        merchantId: purchase.merchantId,
        description: 'Devolución · ${purchase.description}',
        note: note,
        paymentChannel: PaymentChannel.other,
        parentTransactionId: purchaseId,
        splits: splits,
      ),
    );
  });

  Future<void> _validateRefund(
    TransactionDraft draft, {
    String? excludingId,
  }) async {
    if (draft.type != TransactionType.refund ||
        draft.parentTransactionId == null) {
      return;
    }
    final parent = await (database.select(
      database.ledgerTransactions,
    )..where((t) => t.id.equals(draft.parentTransactionId!))).getSingleOrNull();
    if (parent == null ||
        parent.type != 'expense' ||
        parent.status != 'confirmed' ||
        parent.currencyCode != draft.amount.currencyCode ||
        parent.fromAccountId != draft.toAccountId) {
      throw const ValidationException(
        'La devolución debe corresponder a una compra activa y su cuenta de origen.',
      );
    }
    if (DateTime(
      draft.occurredAt.toLocal().year,
      draft.occurredAt.toLocal().month,
      draft.occurredAt.toLocal().day,
    ).isBefore(
      DateTime(
        parent.occurredAt.toLocal().year,
        parent.occurredAt.toLocal().month,
        parent.occurredAt.toLocal().day,
      ),
    )) {
      throw const ValidationException(
        'La devolución no puede ser anterior a la compra.',
      );
    }
    final children =
        await (database.select(database.ledgerTransactions)..where(
              (t) =>
                  t.parentTransactionId.equals(parent.id) &
                  t.type.equals('refund') &
                  t.status.equals('confirmed'),
            ))
            .get();
    final already = children
        .where((r) => r.id != excludingId)
        .fold<int>(0, (sum, r) => sum + r.amountMinor);
    if (already + draft.amount.minorUnits > parent.amountMinor) {
      throw const ValidationException(
        'Las devoluciones no pueden superar el importe de la compra.',
      );
    }
  }

  Future<void> update(
    String id,
    TransactionDraft draft, {
    DateTime? expectedUpdatedAt,
    int? installmentCount,
    DateTime? firstInstallmentDate,
    bool preserveInstallments = true,
  }) => database.transaction(() async {
    final old = await (database.select(
      database.ledgerTransactions,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (old == null || old.status != 'confirmed') {
      throw const ValidationException(
        'El movimiento ya no está disponible para editar.',
      );
    }
    if (expectedUpdatedAt != null && old.updatedAt != expectedUpdatedAt) {
      throw const ValidationException(
        'El movimiento cambió. Volvé a abrirlo antes de guardar.',
      );
    }
    if (!['expense', 'income', 'transfer'].contains(old.type)) {
      throw const ValidationException(
        'Para corregir una devolución o ajuste, eliminá el registro y crealo de nuevo.',
      );
    }
    if (old.type != draft.type.name ||
        old.currencyCode != draft.amount.currencyCode) {
      throw const ValidationException(
        'No se puede cambiar la naturaleza ni la moneda de un movimiento existente.',
      );
    }
    final children =
        await (database.select(database.ledgerTransactions)..where(
              (t) =>
                  t.parentTransactionId.equals(id) &
                  t.status.equals('confirmed'),
            ))
            .get();
    final refunded = children
        .where((r) => r.type == 'refund')
        .fold<int>(0, (sum, r) => sum + r.amountMinor);
    if (refunded > draft.amount.minorUnits ||
        (refunded > 0 && old.fromAccountId != draft.fromAccountId)) {
      throw const ValidationException(
        'La compra tiene devoluciones; conservá su cuenta y un importe que las cubra.',
      );
    }
    if (refunded > 0) {
      final refundSplits =
          await (database.select(database.transactionSplits)..where(
                (t) => t.transactionId.isIn(
                  children.where((r) => r.type == 'refund').map((r) => r.id),
                ),
              ))
              .get();
      final credited = <String, int>{};
      for (final s in refundSplits) {
        credited.update(
          s.categoryId,
          (v) => v + s.amountMinor,
          ifAbsent: () => s.amountMinor,
        );
      }
      final proposed = <String, int>{};
      for (final s in draft.splits) {
        proposed.update(
          s.categoryId,
          (v) => v + s.amountMinor,
          ifAbsent: () => s.amountMinor,
        );
      }
      if (credited.entries.any((e) => (proposed[e.key] ?? 0) < e.value)) {
        throw const ValidationException(
          'Las categorías deben cubrir las devoluciones ya registradas.',
        );
      }
    }
    final from = await _loadAccount(
      draft.fromAccountId,
      allowArchived: old.fromAccountId == draft.fromAccountId,
    );
    final to = await _loadAccount(
      draft.toAccountId,
      allowArchived: old.toAccountId == draft.toAccountId,
    );
    PaymentChannelPolicy.validate(draft, from: from, to: to);
    final postings = calculator.calculate(draft, from: from, to: to);
    final plan = await (database.select(
      database.installmentPlans,
    )..where((t) => t.transactionId.equals(id))).getSingleOrNull();
    final oldDay = old.occurredAt.toLocal(),
        newDay = draft.occurredAt.toLocal();
    final samePurchaseDay =
        oldDay.year == newDay.year &&
        oldDay.month == newDay.month &&
        oldDay.day == newDay.day;
    final count =
        installmentCount ??
        (preserveInstallments ? plan?.installmentCount : null);
    if (count != null &&
        (draft.type != TransactionType.expense ||
            from?.type != AccountType.creditCard)) {
      throw const ValidationException(
        'Las cuotas requieren una compra con tarjeta de crédito.',
      );
    }
    await _refreshPendingLink(id, newAmount: draft.amount.minorUnits);
    final clockNow = DateTime.now().toUtc();
    final now = clockNow.difference(old.updatedAt).inSeconds < 1
        ? old.updatedAt.add(const Duration(seconds: 1))
        : clockNow;
    await (database.update(
      database.ledgerTransactions,
    )..where((t) => t.id.equals(id))).write(
      LedgerTransactionsCompanion(
        amountMinor: Value(draft.amount.minorUnits),
        occurredAt: Value(draft.occurredAt.toUtc()),
        fromAccountId: Value(draft.fromAccountId),
        toAccountId: Value(draft.toAccountId),
        merchantId: Value(draft.merchantId),
        description: Value(draft.description.trim()),
        note: Value(draft.note.trim()),
        paymentChannel: Value(draft.paymentChannel.name),
        updatedAt: Value(now),
      ),
    );
    await (database.delete(
      database.accountPostings,
    )..where((t) => t.transactionId.equals(id))).go();
    // Preserve split identity/order: reports allocate quota residues by split ID.
    // Editing a note must not move one guaraní between historical months.
    final previousSplits = await (database.select(
      database.transactionSplits,
    )..where((t) => t.transactionId.equals(id))).get();
    await (database.delete(
      database.transactionSplits,
    )..where((t) => t.transactionId.equals(id))).go();
    for (final posting in postings) {
      await database
          .into(database.accountPostings)
          .insert(
            AccountPostingsCompanion.insert(
              id: uuid.v4(),
              transactionId: id,
              accountId: posting.accountId,
              deltaMinor: posting.deltaMinor,
              currencyCode: draft.amount.currencyCode,
              occurredAt: draft.occurredAt.toUtc(),
              createdAt: now,
            ),
          );
    }
    for (final split in draft.splits) {
      final previousIndex = previousSplits.indexWhere(
        (part) => part.categoryId == split.categoryId,
      );
      final splitId = previousIndex < 0
          ? uuid.v4()
          : previousSplits.removeAt(previousIndex).id;
      await database
          .into(database.transactionSplits)
          .insert(
            TransactionSplitsCompanion.insert(
              id: splitId,
              transactionId: id,
              categoryId: split.categoryId,
              amountMinor: split.amountMinor,
              note: Value(split.note),
            ),
          );
    }
    await (database.delete(
      database.installmentPlans,
    )..where((t) => t.transactionId.equals(id))).go();
    if (count != null) {
      await InstallmentService(database).attachPlan(
        transactionId: id,
        count: count,
        firstPeriod:
            firstInstallmentDate ??
            (plan != null && samePurchaseDay
                ? plan.firstPeriod.toUtc()
                : draft.occurredAt.toLocal()),
        preserveHistoricalDate:
            plan != null &&
            samePurchaseDay &&
            (firstInstallmentDate == null ||
                firstInstallmentDate == plan.firstPeriod.toUtc()),
      );
    }
    await database
        .into(database.auditLogs)
        .insert(
          AuditLogsCompanion.insert(
            id: uuid.v4(),
            entityType: 'transaction',
            entityId: id,
            action: 'edited',
            changesJson: Value(
              jsonEncode({
                'before': {
                  'amountMinor': old.amountMinor,
                  'from': old.fromAccountId,
                  'to': old.toAccountId,
                },
                'after': {
                  'amountMinor': draft.amount.minorUnits,
                  'from': draft.fromAccountId,
                  'to': draft.toAccountId,
                },
              }),
            ),
            createdAt: now,
          ),
        );
  });

  Future<void> softDelete(String transactionId) async {
    final now = DateTime.now().toUtc();
    await database.transaction(() async {
      final children =
          await (database.select(database.ledgerTransactions)..where(
                (t) =>
                    t.parentTransactionId.equals(transactionId) &
                    t.status.equals('confirmed'),
              ))
              .get();
      if (children.isNotEmpty) {
        throw const ValidationException(
          'Eliminá primero las devoluciones vinculadas a esta compra.',
        );
      }
      final changed =
          await (database.update(
            database.ledgerTransactions,
          )..where((table) => table.id.equals(transactionId))).write(
            LedgerTransactionsCompanion(
              status: const Value('deleted'),
              deletedAt: Value(now),
              updatedAt: Value(now),
            ),
          );
      await _refreshPendingLink(transactionId);
      if (changed != 1) {
        throw const ValidationException('El movimiento ya no existe.');
      }
      await (database.delete(
        database.accountPostings,
      )..where((table) => table.transactionId.equals(transactionId))).go();
      await database
          .into(database.auditLogs)
          .insert(
            AuditLogsCompanion.insert(
              id: uuid.v4(),
              entityType: 'transaction',
              entityId: transactionId,
              action: 'soft_deleted',
              createdAt: now,
            ),
          );
    });
  }

  Future<void> restore(String transactionId) => database.transaction(() async {
    final row = await (database.select(
      database.ledgerTransactions,
    )..where((table) => table.id.equals(transactionId))).getSingleOrNull();
    if (row == null || row.status != TransactionStatus.deleted.name) {
      throw const ValidationException('No se puede restaurar este movimiento.');
    }
    final draft = TransactionDraft(
      type: TransactionType.values.byName(row.type),
      amount: Money(row.amountMinor, currencyCode: row.currencyCode),
      occurredAt: row.occurredAt,
      status: TransactionStatus.confirmed,
      source: TransactionSource.values.byName(row.source),
      fromAccountId: row.fromAccountId,
      toAccountId: row.toAccountId,
      merchantId: row.merchantId,
      description: row.description,
      note: row.note,
      paymentChannel: PaymentChannel.values.byName(row.paymentChannel),
      externalFingerprint: row.externalFingerprint,
      sourceReference: row.sourceReference,
      importBatchId: row.importBatchId,
      parentTransactionId: row.parentTransactionId,
      timeZone: row.occurredTimeZone,
    );
    await _validateRefund(draft, excludingId: row.id);
    await _refreshPendingLink(transactionId, newAmount: row.amountMinor);
    final from = await _loadAccount(row.fromAccountId);
    final to = await _loadAccount(row.toAccountId);
    final postings = calculator.calculate(draft, from: from, to: to);
    final now = DateTime.now().toUtc();
    if (row.externalFingerprint != null) {
      final active =
          await (database.select(database.ledgerTransactions)..where(
                (table) =>
                    table.externalFingerprint.equals(row.externalFingerprint!) &
                    table.status.equals('deleted').not(),
              ))
              .get();
      if (active.isNotEmpty) {
        throw const ValidationException(
          'Esta compra ya tiene otro movimiento activo.',
        );
      }
    }
    await (database.update(
      database.ledgerTransactions,
    )..where((table) => table.id.equals(transactionId))).write(
      LedgerTransactionsCompanion(
        status: const Value('confirmed'),
        deletedAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
    for (final posting in postings) {
      await database
          .into(database.accountPostings)
          .insert(
            AccountPostingsCompanion.insert(
              id: uuid.v4(),
              transactionId: transactionId,
              accountId: posting.accountId,
              deltaMinor: posting.deltaMinor,
              currencyCode: row.currencyCode,
              occurredAt: row.occurredAt,
              createdAt: now,
            ),
          );
    }
  });

  // Pending obligations retain their historical links when a payment changes.
  Future<void> _refreshPendingLink(
    String transactionId, {
    int? newAmount,
  }) async {
    final rows = await (database.select(
      database.appSettings,
    )..where((s) => s.key.like('pending_payment:v1:%'))).get();
    for (final row in rows) {
      final pending = Map<String, dynamic>.from(jsonDecode(row.value) as Map);
      final links = pending['payments'] as List;
      if (!links.any((p) => p['transactionId'] == transactionId)) continue;
      if (newAmount != null) {
        var otherPaid = 0;
        for (final link in links) {
          if (link['transactionId'] == transactionId) continue;
          final tx =
              await (database.select(
                    database.ledgerTransactions,
                  )..where((t) => t.id.equals(link['transactionId'] as String)))
                  .getSingleOrNull();
          if (tx?.status == 'confirmed') otherPaid += tx!.amountMinor;
        }
        if (newAmount + otherPaid + (pending['carriedMinor'] as int? ?? 0) >
            (pending['amountMinor'] as int)) {
          throw const ValidationException(
            'El pago supera el importe pendiente.',
          );
        }
      }
      pending['revision'] = (pending['revision'] as int) + 1;
      await database
          .into(database.appSettings)
          .insertOnConflictUpdate(
            AppSettingsCompanion.insert(
              key: row.key,
              value: jsonEncode(pending),
              updatedAt: DateTime.now().toUtc(),
            ),
          );
    }
  }

  Future<AccountSnapshot?> _loadAccount(
    String? accountId, {
    bool allowArchived = false,
  }) async {
    if (accountId == null) return null;
    final row = await (database.select(
      database.accounts,
    )..where((table) => table.id.equals(accountId))).getSingleOrNull();
    if (row == null || (row.isArchived && !allowArchived)) {
      throw const ValidationException(
        'La cuenta seleccionada no está disponible.',
      );
    }
    return AccountSnapshot(
      id: row.id,
      type: AccountType.values.byName(row.type),
      currencyCode: row.currencyCode,
    );
  }
}

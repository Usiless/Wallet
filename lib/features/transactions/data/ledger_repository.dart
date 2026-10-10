import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../domain/ledger_models.dart';

typedef HistoryFilter = ({
  String search,
  String? account,
  String? merchant,
  String? category,
  String? type,
  DateTime? start,
  DateTime? end,
});
const emptyHistoryFilter = (
  search: '',
  account: null,
  merchant: null,
  category: null,
  type: null,
  start: null,
  end: null,
);

/// Read-only view: canonical purchase owns postings; entries never add debt.
final class MovementRow {
  const MovementRow(
    this.transaction, {
    this.date,
    this.quotaMinor,
    this.number,
    this.count,
  });
  final TransactionRecord transaction;
  final DateTime? date;
  final int? quotaMinor, number, count;
  DateTime get occurredAt => date ?? transaction.occurredAt.toLocal();
  int get amountMinor => quotaMinor ?? transaction.amountMinor;
  bool get isQuota => number != null;
  bool get planned {
    final now = DateTime.now();
    return occurredAt.isAfter(
      DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }
}

final class LedgerRepository {
  LedgerRepository(this.database);

  final AppDatabase database;

  Stream<List<MovementRow>> watchMovements({
    HistoryFilter filter = emptyHistoryFilter,
    int limit = 100,
    bool unclassifiedOnly = false,
    bool reportOnly = false,
    bool withoutMerchant = false,
  }) {
    final where = <String>["t.status = 'confirmed'"];
    final variables = <Variable>[];
    void condition(String sql, List<Variable> args) {
      where.add(sql);
      variables.addAll(args);
    }

    if (reportOnly) {
      where.add(
        "t.currency_code = 'PYG' AND t.type IN ('income','expense','refund')",
      );
    }
    if (withoutMerchant) where.add('t.merchant_id IS NULL');
    if (filter.account != null) {
      condition('(t.from_account_id = ? OR t.to_account_id = ?)', [
        Variable(filter.account!),
        Variable(filter.account!),
      ]);
    }
    if (filter.merchant != null) {
      condition('t.merchant_id = ?', [Variable(filter.merchant!)]);
    }
    if (filter.type == 'purchases') {
      where.add("t.type IN ('expense','refund')");
    } else if (filter.type != null) {
      condition('t.type = ?', [Variable(filter.type!)]);
    }
    final now = DateTime.now();
    final end = filter.end ?? DateTime(now.year, now.month, now.day + 1);
    DateTime quotaDate(DateTime v) => DateTime.utc(v.year, v.month, v.day, 12);
    if (filter.start != null) {
      condition(
        '((ie.id IS NULL AND t.occurred_at >= ?) OR (ie.id IS NOT NULL AND ie.period_start >= ?))',
        [
          Variable.withDateTime(filter.start!.toUtc()),
          Variable.withDateTime(quotaDate(filter.start!)),
        ],
      );
    }
    condition(
      '((ie.id IS NULL AND t.occurred_at < ?) OR (ie.id IS NOT NULL AND ie.period_start < ?))',
      [
        Variable.withDateTime(end.toUtc()),
        Variable.withDateTime(quotaDate(end)),
      ],
    );
    if (unclassifiedOnly) {
      where.add(
        'NOT EXISTS (SELECT 1 FROM transaction_splits s WHERE s.transaction_id = t.id)',
      );
    }
    if (filter.category != null) {
      condition(
        'EXISTS (SELECT 1 FROM transaction_splits s WHERE s.transaction_id = t.id AND s.category_id = ?)',
        [Variable(filter.category!)],
      );
    }
    if (filter.search.trim().isNotEmpty) {
      final escaped = filter.search
          .trim()
          .replaceAll('\\', '\\\\')
          .replaceAll('%', '\\%')
          .replaceAll('_', '\\_');
      final term = '%$escaped%';
      condition(
        "(t.description LIKE ? ESCAPE '\\' OR t.note LIKE ? ESCAPE '\\' OR EXISTS (SELECT 1 FROM merchants m WHERE m.id=t.merchant_id AND m.name LIKE ? ESCAPE '\\'))",
        [Variable(term), Variable(term), Variable(term)],
      );
    }
    return database
        .customSelect(
          "SELECT t.*, ie.period_start AS movement_date, ie.amount_minor AS movement_amount, ie.installment_number AS movement_number, ip.installment_count AS movement_count FROM transactions t LEFT JOIN installment_plans ip ON ip.transaction_id=t.id AND t.type='expense' LEFT JOIN installment_entries ie ON ie.plan_id=ip.id WHERE ${where.join(' AND ')} ORDER BY COALESCE(ie.period_start,t.occurred_at) DESC,t.id DESC LIMIT ?",
          variables: [...variables, Variable(limit)],
          readsFrom: {
            database.ledgerTransactions,
            database.installmentPlans,
            database.installmentEntries,
            database.transactionSplits,
            database.merchants,
          },
        )
        .watch()
        .map(
          (rows) => rows.map((row) {
            final raw = row.readNullable<DateTime>('movement_date')?.toUtc();
            return MovementRow(
              database.ledgerTransactions.map(row.data),
              date: raw == null ? null : DateTime(raw.year, raw.month, raw.day),
              quotaMinor: row.readNullable<int>('movement_amount'),
              number: row.readNullable<int>('movement_number'),
              count: row.readNullable<int>('movement_count'),
            );
          }).toList(),
        );
  }

  Stream<List<TransactionRecord>> watchTransactions({int limit = 100}) {
    final query = database.select(database.ledgerTransactions)
      ..where((table) => table.status.isNotValue('deleted'))
      ..orderBy([
        (table) => OrderingTerm.desc(table.occurredAt),
        (table) => OrderingTerm.desc(table.id),
      ])
      ..limit(limit);
    return query.watch();
  }

  Stream<List<TransactionRecord>> watchFiltered({
    required HistoryFilter filter,
    int limit = 51,
    bool installmentPeriod = false,
    bool unclassifiedOnly = false,
    bool reportOnly = false,
    bool withoutMerchant = false,
  }) {
    final t = database.ledgerTransactions;
    final query = database.select(t)
      ..where((t) => t.status.equals('confirmed'));
    if (reportOnly) {
      query.where(
        (t) =>
            t.currencyCode.equals('PYG') &
            t.type.isIn(['income', 'expense', 'refund']),
      );
    }
    if (withoutMerchant) query.where((t) => t.merchantId.isNull());
    if (filter.account != null) {
      query.where(
        (t) =>
            t.fromAccountId.equals(filter.account!) |
            t.toAccountId.equals(filter.account!),
      );
    }
    if (filter.merchant != null) {
      query.where((t) => t.merchantId.equals(filter.merchant!));
    }
    if (filter.type != null) {
      query.where(
        (t) => filter.type == 'purchases'
            ? t.type.isIn(['expense', 'refund'])
            : t.type.equals(filter.type!),
      );
    }
    Expression<bool> originalDates = const Constant(true);
    if (filter.start != null) {
      originalDates &= t.occurredAt.isBiggerOrEqualValue(filter.start!.toUtc());
    }
    if (filter.end != null) {
      originalDates &= t.occurredAt.isSmallerThanValue(filter.end!.toUtc());
    }
    if (installmentPeriod) {
      final plans = database.installmentPlans;
      final entries = database.installmentEntries;
      final allPlans = database.selectOnly(plans)
        ..addColumns([plans.transactionId]);
      final eligibleEntries = database.selectOnly(entries)
        ..addColumns([entries.planId]);
      DateTime periodDate(DateTime date) =>
          DateTime.utc(date.year, date.month, date.day, 12);
      if (filter.start != null) {
        eligibleEntries.where(
          entries.periodStart.isBiggerOrEqualValue(periodDate(filter.start!)),
        );
      }
      if (filter.end != null) {
        eligibleEntries.where(
          entries.periodStart.isSmallerThanValue(periodDate(filter.end!)),
        );
      }
      final eligiblePlans = database.selectOnly(plans)
        ..addColumns([plans.transactionId])
        ..where(plans.id.isInQuery(eligibleEntries));
      final plannedExpense =
          t.type.equals('expense') & t.id.isInQuery(allPlans);
      query.where(
        (t) =>
            (plannedExpense.not() & originalDates) |
            (t.type.equals('expense') & t.id.isInQuery(eligiblePlans)),
      );
    } else {
      query.where((t) => originalDates);
    }
    if (unclassifiedOnly) {
      final classified = database.selectOnly(database.transactionSplits)
        ..addColumns([database.transactionSplits.transactionId]);
      query.where((t) => t.id.isNotInQuery(classified));
    }
    if (filter.category != null) {
      final splits = database.selectOnly(database.transactionSplits)
        ..addColumns([database.transactionSplits.transactionId])
        ..where(database.transactionSplits.categoryId.equals(filter.category!));
      query.where((t) => t.id.isInQuery(splits));
    }
    if (filter.search.trim().isNotEmpty) {
      final escaped = filter.search
          .trim()
          .replaceAll('\\', '\\\\')
          .replaceAll('%', '\\%')
          .replaceAll('_', '\\_');
      final names = database.selectOnly(database.merchants)
        ..addColumns([database.merchants.id])
        ..where(database.merchants.name.like('%$escaped%', escapeChar: '\\'));
      query.where(
        (t) =>
            t.description.like('%$escaped%', escapeChar: '\\') |
            t.note.like('%$escaped%', escapeChar: '\\') |
            t.merchantId.isInQuery(names),
      );
    }
    query.orderBy([
      (t) => OrderingTerm.desc(t.occurredAt),
      (t) => OrderingTerm.desc(t.id),
    ]);
    query.limit(limit);
    return query.watch();
  }

  Stream<List<TransactionRecord>> watchConfirmedMonth(DateTime month) {
    final start = DateTime(month.year, month.month).toUtc();
    final end = DateTime(month.year, month.month + 1).toUtc();
    return (database.select(database.ledgerTransactions)
          ..where(
            (table) =>
                table.status.equals('confirmed') &
                table.occurredAt.isBiggerOrEqualValue(start) &
                table.occurredAt.isSmallerThanValue(end),
          )
          ..orderBy([(table) => OrderingTerm.desc(table.occurredAt)]))
        .watch();
  }

  Stream<List<AccountBalance>> watchAccountBalances() {
    return database
        .customSelect(
          '''
      SELECT a.id, a.name, a.type, a.currency_code,
             a.include_in_available_money, a.include_in_net_worth,
             a.initial_balance_minor + COALESCE(SUM(p.delta_minor), 0) AS balance_minor
      FROM accounts a
      LEFT JOIN account_postings p ON p.account_id = a.id
      WHERE a.is_archived = 0
      GROUP BY a.id
      ORDER BY a.sort_order, a.created_at
      ''',
          readsFrom: {database.accounts, database.accountPostings},
        )
        .watch()
        .map(
          (rows) => rows
              .map(
                (row) => AccountBalance(
                  id: row.read<String>('id'),
                  name: row.read<String>('name'),
                  type: AccountType.values.byName(row.read<String>('type')),
                  currencyCode: row.read<String>('currency_code'),
                  balanceMinor: row.read<int>('balance_minor'),
                  includeInAvailableMoney:
                      row.read<int>('include_in_available_money') == 1,
                  includeInNetWorth: row.read<int>('include_in_net_worth') == 1,
                ),
              )
              .toList(growable: false),
        );
  }
}

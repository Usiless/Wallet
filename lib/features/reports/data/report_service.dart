import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../payments/domain/pending_payment_service.dart';

typedef ReportRequest = ({
  DateTime start,
  DateTime end,
  String? category,
  bool monthlyInstallments,
});
typedef AnalysisRequest = ({ReportRequest period, String? account});

class ReportTotals {
  const ReportTotals({
    required this.income,
    required this.expenses,
    required this.refunds,
    this.pendingExpenses = 0,
  });
  final int income, expenses, refunds, pendingExpenses;
  int get netExpenses => expenses - refunds;
  int get balance => income - netExpenses;
}

class ReportGroup {
  const ReportGroup({
    required this.id,
    required this.name,
    required this.totals,
    required this.expenseCount,
  });
  final String? id;
  final String name;
  final ReportTotals totals;
  final int expenseCount;
}

class ReportMonth {
  const ReportMonth(this.month, this.totals);
  final DateTime month;
  final ReportTotals totals;
}

class ReportAnalysis {
  const ReportAnalysis({
    required this.totals,
    required this.previous,
    required this.previousStart,
    required this.previousEnd,
    required this.months,
    required this.categories,
    required this.merchants,
    required this.accounts,
    required this.expenseCount,
    required this.unclassifiedAmount,
    required this.unclassifiedCount,
  });
  final ReportTotals totals, previous;
  final DateTime previousStart, previousEnd;
  final List<ReportMonth> months;
  final List<ReportGroup> categories, merchants, accounts;
  final int expenseCount, unclassifiedAmount, unclassifiedCount;
  int get pendingMinor => totals.pendingExpenses;
  int get difference => totals.netExpenses - previous.netExpenses;
  double? get changePercent =>
      previous.netExpenses > 0 ? difference * 100 / previous.netExpenses : null;
}

class ReportService {
  ReportService(this.database);
  final AppDatabase database;
  Stream<ReportTotals> watch(ReportRequest request) =>
      watchAnalysis((period: request, account: null)).map((a) => a.totals);

  Stream<ReportAnalysis> watchAnalysis(AnalysisRequest request) {
    final period = request.period;
    final calendarMonth =
        period.start.day == 1 &&
        period.end == DateTime(period.start.year, period.start.month + 1);
    // Calendar months compare to the previous calendar month; custom ranges to
    // the preceding range with the same number of calendar days, including DST.
    final days = DateTime.utc(period.end.year, period.end.month, period.end.day)
        .difference(
          DateTime.utc(period.start.year, period.start.month, period.start.day),
        )
        .inDays;
    final previousStart = calendarMonth
        ? DateTime(period.start.year, period.start.month - 1)
        : DateTime(
            period.start.year,
            period.start.month,
            period.start.day - days,
          );
    final trendStart = calendarMonth
        ? DateTime(period.start.year, period.start.month - 5)
        : DateTime(period.start.year, period.start.month);
    final queryStart = previousStart.isBefore(trendStart)
        ? previousStart
        : trendStart;
    return database
        .customSelect(
          '''
      SELECT t.id, t.type, t.amount_minor, t.occurred_at, t.merchant_id,
        m.name AS merchant_name,
        CASE WHEN t.type = 'expense' THEN t.from_account_id ELSE t.to_account_id END AS account_id,
        a.name AS account_name, ip.id AS plan_id,
        ie.id AS entry_id, ie.period_start, ie.amount_minor AS quota, ie.installment_number,
        s.id AS split_id, s.category_id, s.amount_minor AS split_amount, c.name AS category_name
      FROM transactions t
      LEFT JOIN merchants m ON m.id = t.merchant_id
      LEFT JOIN accounts a ON a.id = CASE WHEN t.type = 'expense' THEN t.from_account_id ELSE t.to_account_id END
      LEFT JOIN installment_plans ip ON ip.transaction_id = t.id
      LEFT JOIN installment_entries ie ON ie.plan_id = ip.id
      LEFT JOIN transaction_splits s ON s.transaction_id = t.id
      LEFT JOIN categories c ON c.id = s.category_id
      WHERE t.status = 'confirmed' AND t.currency_code = 'PYG'
        AND t.type IN ('income', 'expense', 'refund')
        AND (? IS NULL OR a.id = ?)
        AND ((t.occurred_at >= ? AND t.occurred_at < ?) OR EXISTS (
          SELECT 1 FROM installment_entries eligible WHERE eligible.plan_id = ip.id
          AND eligible.period_start >= ? AND eligible.period_start < ?
        ))
      ORDER BY t.id, ie.installment_number, s.id
    ''',
          variables: [
            Variable<String>(request.account),
            Variable<String>(request.account),
            Variable.withDateTime(queryStart.toUtc()),
            Variable.withDateTime(period.end.toUtc()),
            Variable.withDateTime(
              DateTime.utc(
                queryStart.year,
                queryStart.month,
                queryStart.day,
                12,
              ),
            ),
            Variable.withDateTime(
              DateTime.utc(
                period.end.year,
                period.end.month,
                period.end.day,
                12,
              ),
            ),
          ],
          readsFrom: {
            database.ledgerTransactions,
            database.transactionSplits,
            database.installmentPlans,
            database.installmentEntries,
            database.categories,
            database.merchants,
            database.accounts,
            database.appSettings,
          },
        )
        .watch()
        .asyncMap((rows) async {
          final transactions = <String, _Transaction>{};
          for (final row in rows) {
            final t = transactions.putIfAbsent(
              row.read<String>('id'),
              () => _Transaction(row),
            );
            final split = row.readNullable<String>('split_id');
            if (split != null) {
              t.splits[split] = (
                id: row.readNullable<String>('category_id'),
                name:
                    row.readNullable<String>('category_name') ??
                    'Sin categoría',
                amount: row.read<int>('split_amount'),
              );
            }
            final entry = row.readNullable<String>('entry_id');
            if (entry != null) {
              final raw = row.read<DateTime>('period_start').toUtc();
              t.entries[entry] = (
                date: DateTime(raw.year, raw.month, raw.day),
                amount: row.read<int>('quota'),
                number: row.read<int>('installment_number'),
              );
            }
          }
          final current = _Totals(), previous = _Totals();
          final categories = <String?, _Group>{},
              merchants = <String?, _Group>{},
              accounts = <String?, _Group>{};
          final months = <DateTime, _Totals>{};
          for (
            var month = trendStart;
            month.isBefore(period.end);
            month = DateTime(month.year, month.month + 1)
          ) {
            months[month] = _Totals();
          }
          final expenseIds = <String>{}, unclassifiedIds = <String>{};
          var unclassified = 0;
          for (final transaction in transactions.values) {
            for (final impact in transaction.impacts(
              period.monthlyInstallments,
            )) {
              final parts = period.category == null
                  ? impact.parts
                  : impact.parts.where((p) => p.id == period.category).toList();
              final amount = parts.fold<int>(0, (sum, p) => sum + p.amount);
              if (amount == 0) continue;
              if (!impact.date.isBefore(
                    calendarMonth ? trendStart : period.start,
                  ) &&
                  impact.date.isBefore(period.end)) {
                months[DateTime(impact.date.year, impact.date.month)]?.add(
                  transaction.type,
                  amount,
                );
              }
              if (!impact.date.isBefore(previousStart) &&
                  impact.date.isBefore(period.start)) {
                previous.add(transaction.type, amount);
              }
              if (impact.date.isBefore(period.start) ||
                  !impact.date.isBefore(period.end)) {
                continue;
              }
              current.add(transaction.type, amount);
              accounts
                  .putIfAbsent(
                    transaction.accountId,
                    () =>
                        _Group(transaction.accountId, transaction.accountName),
                  )
                  .add(transaction, amount);
              if (transaction.type == 'income') continue;
              merchants
                  .putIfAbsent(
                    transaction.merchantId,
                    () => _Group(
                      transaction.merchantId,
                      transaction.merchantName,
                    ),
                  )
                  .add(transaction, amount);
              for (final part in parts) {
                if (part.amount == 0) continue;
                categories
                    .putIfAbsent(part.id, () => _Group(part.id, part.name))
                    .add(transaction, part.amount);
                if (part.id == null && transaction.type == 'expense') {
                  unclassified += part.amount;
                  unclassifiedIds.add(transaction.id);
                }
              }
              if (transaction.type == 'expense') expenseIds.add(transaction.id);
            }
          }
          List<ReportGroup> groups(Map<String?, _Group> values) =>
              values.values.map((g) => g.value).toList()..sort((a, b) {
                final byAmount = b.totals.expenses.compareTo(a.totals.expenses);
                return byAmount != 0 ? byAmount : a.name.compareTo(b.name);
              });
          var pending = 0;
          for (final p in await PendingPaymentService(database).list()) {
            if (p.cancelled ||
                p.remainingMinor <= 0 ||
                p.dueDate.isBefore(period.start) ||
                !p.dueDate.isBefore(period.end) ||
                (request.account != null && p.accountId != request.account)) {
              continue;
            }
            if (period.category == null) {
              pending += p.remainingMinor;
            } else {
              pending += p.remainingSplits[period.category] ?? 0;
            }
          }
          return ReportAnalysis(
            totals: ReportTotals(
              income: current.value.income,
              expenses: current.value.expenses,
              refunds: current.value.refunds,
              pendingExpenses: pending,
            ),
            previous: previous.value,
            previousStart: previousStart,
            previousEnd: period.start,
            months: months.entries
                .map((e) => ReportMonth(e.key, e.value.value))
                .toList(),
            categories: groups(categories),
            merchants: groups(merchants),
            accounts: groups(accounts),
            expenseCount: expenseIds.length,
            unclassifiedAmount: unclassified,
            unclassifiedCount: unclassifiedIds.length,
          );
        });
  }
}

typedef _Part = ({String? id, String name, int amount});
typedef _Entry = ({DateTime date, int amount, int number});

class _Impact {
  const _Impact(this.date, this.parts);
  final DateTime date;
  final List<_Part> parts;
}

class _Transaction {
  _Transaction(QueryRow row)
    : id = row.read<String>('id'),
      type = row.read<String>('type'),
      amount = row.read<int>('amount_minor'),
      date = row.read<DateTime>('occurred_at').toLocal(),
      merchantId = row.readNullable<String>('merchant_id'),
      merchantName =
          row.readNullable<String>('merchant_name') ?? 'Sin comercio',
      accountId = row.readNullable<String>('account_id'),
      accountName = row.readNullable<String>('account_name') ?? 'Sin cuenta',
      hasPlan = row.readNullable<String>('plan_id') != null;
  final String id, type, merchantName, accountName;
  final String? merchantId, accountId;
  final int amount;
  final DateTime date;
  final bool hasPlan;
  final splits = <String, _Part>{};
  final entries = <String, _Entry>{};
  Iterable<_Impact> impacts(bool quotas) sync* {
    final weights = splits.values.toList();
    if (weights.isEmpty) {
      weights.add((id: null, name: 'Sin categoría', amount: amount));
    }
    if (!quotas || type != 'expense' || !hasPlan) {
      yield _Impact(date, weights);
      return;
    }
    final schedule = entries.values.toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    final remaining = [for (final part in weights) part.amount];
    // Allocate each quota from remaining category weights. Integer rounding is
    // deterministic and the entire plan sums exactly to each original split.
    for (final entry in schedule) {
      final totalWeight = remaining.fold<int>(0, (sum, v) => sum + v);
      if (totalWeight <= 0) continue;
      var cumulative = 0, assigned = 0;
      final parts = <_Part>[];
      for (var i = 0; i < weights.length; i++) {
        cumulative += remaining[i];
        final total = entry.amount * cumulative ~/ totalWeight;
        final portion = total - assigned;
        assigned = total;
        remaining[i] -= portion;
        parts.add((id: weights[i].id, name: weights[i].name, amount: portion));
      }
      yield _Impact(entry.date, parts);
    }
  }
}

class _Totals {
  int income = 0, expenses = 0, refunds = 0;
  void add(String type, int amount) {
    switch (type) {
      case 'income':
        income += amount;
      case 'expense':
        expenses += amount;
      case 'refund':
        refunds += amount;
    }
  }

  ReportTotals get value =>
      ReportTotals(income: income, expenses: expenses, refunds: refunds);
}

class _Group {
  _Group(this.id, this.name);
  final String? id;
  final String name;
  final totals = _Totals();
  final ids = <String>{};
  void add(_Transaction t, int amount) {
    totals.add(t.type, amount);
    if (t.type == 'expense') ids.add(t.id);
  }

  ReportGroup get value => ReportGroup(
    id: id,
    name: name,
    totals: totals.value,
    expenseCount: ids.length,
  );
}

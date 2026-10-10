import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/app_exception.dart';
import 'budget_calculator.dart';
import '../../reports/data/report_service.dart';

final class BudgetWithProgress {
  const BudgetWithProgress(this.budget, this.progress);

  final BudgetRecord budget;
  final BudgetProgress progress;
}

final class BudgetService {
  BudgetService(this.database, {Uuid? uuid}) : uuid = uuid ?? const Uuid();

  final AppDatabase database;
  final Uuid uuid;
  final calculator = const BudgetCalculator();

  Future<String> create({
    required String name,
    required DateTime month,
    required int targetMinor,
    String currencyCode = 'PYG',
    String? categoryId,
    bool repeatMonthly = false,
    int? expectedBookGeneration,
  }) => database.transaction(() async {
    _checkBook(expectedBookGeneration);
    if (targetMinor <= 0) {
      throw const ValidationException(
        'El presupuesto debe ser mayor que cero.',
      );
    }
    final id = uuid.v4();
    final now = DateTime.now().toUtc();
    await database
        .into(database.budgets)
        .insert(
          BudgetsCompanion.insert(
            id: id,
            name: name.trim().isEmpty ? 'Presupuesto mensual' : name.trim(),
            periodStart: DateTime.utc(month.year, month.month, 1, 12),
            categoryId: Value(categoryId),
            targetMinor: targetMinor,
            currencyCode: currencyCode,
            createdAt: now,
            updatedAt: now,
          ),
        );
    if (repeatMonthly) {
      final budget = await (database.select(
        database.budgets,
      )..where((b) => b.id.equals(id))).getSingle();
      await _writeTemplate(budget, active: true);
    }
    return id;
  });

  static const _templatePrefix = 'budget_template:';
  void _checkBook(int? expected) {
    if (expected != null && expected != database.restoreGeneration) {
      throw const ValidationException(
        'Los datos fueron restaurados. Volvé a abrir el presupuesto.',
      );
    }
  }

  Future<List<_BudgetTemplate>> _templates() async => [
    for (final row in await (database.select(
      database.appSettings,
    )..where((s) => s.key.like(r'budget\_template:%', escapeChar: '\\'))).get())
      _BudgetTemplate.fromJson(
        row.key.substring(_templatePrefix.length),
        jsonDecode(row.value) as Map<String, dynamic>,
      ),
  ];
  Future<_BudgetTemplate?> _templateFor(BudgetRecord budget) async {
    for (final template in await _templates()) {
      if (template.owns(budget.id)) return template;
    }
    return null;
  }

  Future<bool> repeatsMonthly(BudgetRecord budget) async =>
      (await _templateFor(budget))?.active ?? false;
  Future<void> _writeTemplate(
    BudgetRecord budget, {
    required bool active,
    _BudgetTemplate? previous,
  }) async {
    final template = _BudgetTemplate(
      id: previous?.id ?? budget.id,
      anchorId: previous?.anchorId ?? budget.id,
      start: budget.periodStart.toUtc(),
      anchorMonth: previous?.anchorMonth ?? budget.periodStart.toUtc(),
      name: budget.name,
      target: budget.targetMinor,
      category: budget.categoryId,
      currency: budget.currencyCode,
      thresholds: budget.thresholds,
      active: active,
    );
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: '$_templatePrefix${template.id}',
            value: jsonEncode(template.toJson()),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  /// Edits the selected month and existing later members, never earlier months.
  Future<void> edit(
    BudgetRecord expected, {
    required String name,
    required int targetMinor,
    String? categoryId,
    required bool repeatMonthly,
    int? expectedBookGeneration,
  }) => database.transaction(() async {
    _checkBook(expectedBookGeneration);
    final current = await (database.select(
      database.budgets,
    )..where((b) => b.id.equals(expected.id))).getSingleOrNull();
    if (current == null || current.updatedAt != expected.updatedAt) {
      throw const ValidationException(
        'El presupuesto cambió. Volvé a abrirlo.',
      );
    }
    if (targetMinor <= 0) {
      throw const ValidationException(
        'El presupuesto debe ser mayor que cero.',
      );
    }
    if (categoryId != null && categoryId != current.categoryId) {
      final category = await (database.select(
        database.categories,
      )..where((c) => c.id.equals(categoryId))).getSingleOrNull();
      if (category == null ||
          category.isArchived ||
          category.kind == 'income') {
        throw const ValidationException(
          'Seleccioná una categoría de gasto activa.',
        );
      }
    }
    final template = await _templateFor(current);
    final now = DateTime.now().toUtc();
    final members = await database.select(database.budgets).get();
    for (final member in members.where(
      (b) =>
          b.id == current.id ||
          (repeatMonthly &&
              template != null &&
              template.owns(b.id) &&
              !b.periodStart.isBefore(current.periodStart)),
    )) {
      await (database.update(
        database.budgets,
      )..where((b) => b.id.equals(member.id))).write(
        BudgetsCompanion(
          name: Value(
            name.trim().isEmpty ? 'Presupuesto mensual' : name.trim(),
          ),
          targetMinor: Value(targetMinor),
          categoryId: Value(categoryId),
          updatedAt: Value(
            now.isAfter(member.updatedAt.add(const Duration(seconds: 1)))
                ? now
                : member.updatedAt.toUtc().add(const Duration(seconds: 1)),
          ),
        ),
      );
    }
    final updated = await (database.select(
      database.budgets,
    )..where((b) => b.id.equals(current.id))).getSingle();
    if (repeatMonthly || template != null) {
      await _writeTemplate(updated, active: repeatMonthly, previous: template);
    }
  });

  /// Runs on opening/resuming only. It does not backfill closed historical months.
  Future<void> ensureCurrentMonth({DateTime? now}) =>
      database.transaction(() async {
        final date = now ?? DateTime.now(), templates = await _templates();
        final month = DateTime.utc(date.year, date.month, 1, 12);
        for (final template in templates.where(
          (t) => t.active && !t.start.isAfter(month),
        )) {
          if (template.category != null) {
            final category = await (database.select(
              database.categories,
            )..where((c) => c.id.equals(template.category!))).getSingleOrNull();
            if (category == null ||
                category.isArchived ||
                category.kind == 'income') {
              continue;
            }
          }
          final id = template.idFor(month);
          final timestamp = DateTime.now().toUtc();
          await database
              .into(database.budgets)
              .insert(
                BudgetsCompanion.insert(
                  id: id,
                  name: template.name,
                  periodStart: month,
                  categoryId: Value(template.category),
                  targetMinor: template.target,
                  currencyCode: template.currency,
                  thresholds: Value(template.thresholds),
                  createdAt: timestamp,
                  updatedAt: timestamp,
                ),
                mode: InsertMode.insertOrIgnore,
              );
        }
      });

  Stream<List<BudgetRecord>> watchBudgets(DateTime month) {
    final start = DateTime.utc(month.year, month.month, 1, 12);
    return (database.select(database.budgets)..where(
          (table) =>
              table.periodStart.equals(start) & table.isArchived.equals(false),
        ))
        .watch();
  }

  // H01: use the same exact per-installment category allocation as reports.
  Stream<BudgetWithProgress> watchProgress(BudgetRecord budget) {
    final anchor = budget.periodStart.toUtc();
    return ReportService(database)
        .watch((
          start: DateTime(anchor.year, anchor.month),
          end: DateTime(anchor.year, anchor.month + 1),
          category: budget.categoryId,
          monthlyInstallments: true,
        ))
        .map(
          (totals) => BudgetWithProgress(
            budget,
            calculator.progress(
              targetMinor: budget.targetMinor,
              expenseAmounts: [totals.expenses],
              pendingMinor: totals.pendingExpenses,
              refundAmounts: [totals.refunds],
              thresholds: budget.thresholds.split(',').map(int.parse),
            ),
          ),
        );
  }

  Future<BudgetWithProgress> progress(BudgetRecord budget) =>
      watchProgress(budget).first;
}

final class _BudgetTemplate {
  const _BudgetTemplate({
    required this.id,
    required this.anchorId,
    required this.start,
    required this.anchorMonth,
    required this.name,
    required this.target,
    required this.category,
    required this.currency,
    required this.thresholds,
    required this.active,
  });
  final String id, anchorId, name, currency, thresholds;
  final DateTime start, anchorMonth;
  final int target;
  final String? category;
  final bool active;
  String idFor(DateTime month) =>
      month.year == anchorMonth.year && month.month == anchorMonth.month
      ? anchorId
      : 'budget:$id:${month.year}-${month.month.toString().padLeft(2, '0')}';
  bool owns(String budgetId) =>
      budgetId == anchorId || budgetId.startsWith('budget:$id:');
  Map<String, dynamic> toJson() => {
    'version': 1,
    'anchorId': anchorId,
    'start': start.toIso8601String(),
    'anchorMonth': anchorMonth.toIso8601String(),
    'name': name,
    'target': target,
    'category': category,
    'currency': currency,
    'thresholds': thresholds,
    'active': active,
  };
  factory _BudgetTemplate.fromJson(String id, Map<String, dynamic> value) {
    if (value['version'] != 1 ||
        value['target'] is! int ||
        (value['target'] as int) <= 0) {
      throw const ValidationException('Plantilla de presupuesto inválida.');
    }
    return _BudgetTemplate(
      id: id,
      anchorId: value['anchorId'] as String,
      start: DateTime.parse(value['start'] as String).toUtc(),
      anchorMonth: DateTime.parse(value['anchorMonth'] as String).toUtc(),
      name: value['name'] as String,
      target: value['target'] as int,
      category: value['category'] as String?,
      currency: value['currency'] as String,
      thresholds: value['thresholds'] as String,
      active: value['active'] as bool,
    );
  }
}

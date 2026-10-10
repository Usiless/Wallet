import 'package:drift/native.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/budgets/domain/budget_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('presupuesto repetido desde un mes pasado crea el mes actual sin meses intermedios', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final service = BudgetService(db);

    await service.create(
      name: 'Comida',
      month: DateTime(2026, 3),
      targetMinor: 500000,
      repeatMonthly: true,
    );
    await service.ensureCurrentMonth(now: DateTime(2026, 10, 10));

    final rows = await db.select(db.budgets).get();
    final months = rows
        .map((b) => (b.periodStart.year, b.periodStart.month))
        .toSet();
    expect(months, {(2026, 3), (2026, 10)});
  });
}

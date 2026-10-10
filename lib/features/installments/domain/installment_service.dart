import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/app_exception.dart';
import 'installment_calculator.dart';

final class InstallmentService {
  InstallmentService(this.database);

  final AppDatabase database;
  static const _uuid = Uuid();
  static const _calculator = InstallmentCalculator();

  Future<String> attachPlan({
    required String transactionId,
    required int count,
    required DateTime firstPeriod,
    bool preserveHistoricalDate = false,
  }) => database.transaction(() async {
    final transaction = await (database.select(
      database.ledgerTransactions,
    )..where((table) => table.id.equals(transactionId))).getSingleOrNull();
    if (transaction == null || transaction.type != 'expense') {
      throw const ValidationException(
        'Las cuotas requieren una compra existente.',
      );
    }
    final origin =
        await (database.select(database.accounts)
              ..where((a) => a.id.equals(transaction.fromAccountId ?? '')))
            .getSingleOrNull();
    if (origin?.type != 'creditCard') {
      throw const ValidationException(
        'Las cuotas requieren una tarjeta de crédito.',
      );
    }
    final day = DateTime(firstPeriod.year, firstPeriod.month, firstPeriod.day);
    final bought = transaction.occurredAt.toLocal();
    if (!preserveHistoricalDate &&
        day.isBefore(DateTime(bought.year, bought.month, bought.day))) {
      throw const ValidationException(
        'La primera cuota debe ser desde la compra.',
      );
    }
    final schedule = _calculator.schedule(
      totalMinor: transaction.amountMinor,
      count: count,
      firstPeriod: firstPeriod,
    );
    final planId = _uuid.v4();
    final now = DateTime.now().toUtc();
    await database
        .into(database.installmentPlans)
        .insert(
          InstallmentPlansCompanion.insert(
            id: planId,
            transactionId: transactionId,
            totalCommittedMinor: transaction.amountMinor,
            installmentCount: count,
            firstPeriod: DateTime.utc(
              firstPeriod.year,
              firstPeriod.month,
              firstPeriod.day,
              12,
            ),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await database.batch((batch) {
      batch.insertAll(database.installmentEntries, [
        for (final item in schedule)
          InstallmentEntriesCompanion.insert(
            id: _uuid.v4(),
            planId: planId,
            installmentNumber: item.number,
            periodStart: item.periodStart,
            amountMinor: item.amountMinor,
          ),
      ]);
    });
    return planId;
  });
}

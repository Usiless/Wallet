import '../../../core/errors/app_exception.dart';

final class BudgetProgress {
  const BudgetProgress({
    required this.targetMinor,
    required this.consumedMinor,
    required this.triggeredThresholds,
    this.pendingMinor = 0,
  });

  final int targetMinor;
  final int consumedMinor;
  final int pendingMinor;
  int get paidMinor => consumedMinor - pendingMinor;
  final List<int> triggeredThresholds;

  int get remainingMinor => targetMinor - consumedMinor;
  double get ratio => targetMinor == 0 ? 0 : consumedMinor / targetMinor;
}

final class BudgetCalculator {
  const BudgetCalculator();

  BudgetProgress progress({
    required int targetMinor,
    required Iterable<int> expenseAmounts,
    Iterable<int> refundAmounts = const [],
    int pendingMinor = 0,
    Iterable<int> thresholds = const [50, 80, 100],
  }) {
    if (targetMinor <= 0) {
      throw const ValidationException(
        'El presupuesto debe ser mayor que cero.',
      );
    }
    final spent =
        expenseAmounts.fold<int>(0, (sum, value) => sum + value) -
        refundAmounts.fold<int>(0, (sum, value) => sum + value);
    final percentage = (spent + pendingMinor) * 100 / targetMinor;
    final triggered =
        thresholds.where((threshold) => percentage >= threshold).toList()
          ..sort();
    return BudgetProgress(
      targetMinor: targetMinor,
      consumedMinor: spent.clamp(0, 1 << 62) + pendingMinor,
      pendingMinor: pendingMinor,
      triggeredThresholds: triggered,
    );
  }
}

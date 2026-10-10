import '../../../core/errors/app_exception.dart';

final class InstallmentAmount {
  const InstallmentAmount({
    required this.number,
    required this.periodStart,
    required this.amountMinor,
  });

  final int number;
  final DateTime periodStart;
  final int amountMinor;
}

/// Reparto entero exacto: cuotas iguales y el resto en la última.
List<int> evenInstallmentAmounts(int totalMinor, int count) {
  final base = totalMinor ~/ count;
  return [
    for (var index = 0; index < count; index++)
      index == count - 1 ? totalMinor - base * (count - 1) : base,
  ];
}

/// Calendario mensual con día ancla sin deriva (31 → fin de mes → 31).
({int year, int month, int day}) monthlyAnchorDate(DateTime first, int offset) {
  final month = DateTime.utc(first.year, first.month + offset, 1);
  final last = DateTime.utc(month.year, month.month + 1, 0).day;
  return (
    year: month.year,
    month: month.month,
    day: first.day > last ? last : first.day,
  );
}

final class InstallmentCalculator {
  const InstallmentCalculator();

  List<InstallmentAmount> schedule({
    required int totalMinor,
    required int count,
    required DateTime firstPeriod,
  }) {
    if (totalMinor <= 0) {
      throw const ValidationException(
        'El total de la compra debe ser mayor que cero.',
      );
    }
    if (count < 2 || count > 120) {
      throw const ValidationException(
        'La cantidad de cuotas debe estar entre 2 y 120.',
      );
    }
    final amounts = evenInstallmentAmounts(totalMinor, count);
    // Financial months are stored at UTC noon. Drift converts timestamps back
    // to device-local time; noon keeps the calendar month stable in Paraguay.
    final first = DateTime.utc(
      firstPeriod.year,
      firstPeriod.month,
      firstPeriod.day,
      12,
    );
    return [
      for (var index = 0; index < count; index++)
        InstallmentAmount(
          number: index + 1,
          periodStart: () {
            final date = monthlyAnchorDate(first, index);
            return DateTime.utc(date.year, date.month, date.day, 12);
          }(),
          amountMinor: amounts[index],
        ),
    ];
  }
}

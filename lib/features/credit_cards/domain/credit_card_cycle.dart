final class CardCycleDates {
  const CardCycleDates({required this.nextClosing, required this.nextDue});

  final DateTime nextClosing;
  final DateTime nextDue;
}

final class CreditCardCycleCalculator {
  const CreditCardCycleCalculator();

  CardCycleDates nextDates({
    required DateTime localDate,
    required int closingDay,
    required int dueDay,
  }) {
    final closingThisMonth = _safeDate(
      localDate.year,
      localDate.month,
      closingDay,
    );
    final closing = localDate.isAfter(_endOfDay(closingThisMonth))
        ? _safeDate(localDate.year, localDate.month + 1, closingDay)
        : closingThisMonth;
    var due = _safeDate(closing.year, closing.month + 1, dueDay);
    if (!due.isAfter(closing)) {
      due = _safeDate(closing.year, closing.month + 1, dueDay);
    }
    return CardCycleDates(nextClosing: closing, nextDue: due);
  }

  int availableCredit({
    required int creditLimitMinor,
    required int debtMinor,
  }) => creditLimitMinor - debtMinor;

  DateTime _safeDate(int year, int month, int requestedDay) {
    final firstNextMonth = DateTime(year, month + 1);
    final lastDay = firstNextMonth.subtract(const Duration(days: 1)).day;
    return DateTime(year, month, requestedDay.clamp(1, lastDay));
  }

  DateTime _endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59, 999);
}

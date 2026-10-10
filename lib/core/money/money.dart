import 'package:intl/intl.dart';

/// An immutable monetary value stored in integer minor units.
///
/// PYG has zero visible fraction digits. No financial operation in the app
/// uses binary floating point.
final class Money implements Comparable<Money> {
  const Money(this.minorUnits, {this.currencyCode = 'PYG'});

  final int minorUnits;
  final String currencyCode;

  static Money zero([String currencyCode = 'PYG']) =>
      Money(0, currencyCode: currencyCode);

  static Money parse(String input, {String currencyCode = 'PYG'}) {
    final raw = input
        .trim()
        .toUpperCase()
        .replaceAll(currencyCode.toUpperCase(), '')
        .replaceAll(RegExp(r'\s+'), '');
    if (raw.isEmpty) throw const FormatException('Ingresá un importe.');

    final negative = raw.startsWith('-');
    final unsigned = raw.replaceFirst(RegExp(r'^[+-]'), '');
    if (!RegExp(r'^\d+(?:[.,]\d+)*$').hasMatch(unsigned)) {
      throw FormatException('Importe inválido: $input');
    }

    // For PYG, separators followed by exactly three digits are thousands
    // separators. A trailing .00 or ,00 is accepted from bank exports.
    var normalized = unsigned;
    if (currencyCode == 'PYG') {
      normalized = normalized.replaceFirst(RegExp(r'[.,]00$'), '');
      normalized = normalized.replaceAll(RegExp(r'[.,]'), '');
    } else {
      final lastSeparator = [
        normalized.lastIndexOf('.'),
        normalized.lastIndexOf(','),
      ].reduce((a, b) => a > b ? a : b);
      if (lastSeparator >= 0) {
        final whole = normalized
            .substring(0, lastSeparator)
            .replaceAll(RegExp(r'[.,]'), '');
        final fraction = normalized
            .substring(lastSeparator + 1)
            .padRight(2, '0');
        if (fraction.length != 2) {
          throw FormatException('Importe ambiguo: $input');
        }
        normalized = '$whole$fraction';
      }
    }

    final parsed = int.tryParse(normalized);
    if (parsed == null) throw FormatException('Importe fuera de rango: $input');
    return Money(negative ? -parsed : parsed, currencyCode: currencyCode);
  }

  Money operator +(Money other) {
    _requireSameCurrency(other);
    return Money(minorUnits + other.minorUnits, currencyCode: currencyCode);
  }

  Money operator -(Money other) {
    _requireSameCurrency(other);
    return Money(minorUnits - other.minorUnits, currencyCode: currencyCode);
  }

  Money operator -() => Money(-minorUnits, currencyCode: currencyCode);

  Money abs() => Money(minorUnits.abs(), currencyCode: currencyCode);

  String format({String locale = 'es_PY', bool withCode = true}) {
    final fractionDigits = currencyCode == 'PYG' ? 0 : 2;
    final divisor = fractionDigits == 0 ? 1 : 100;
    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: withCode ? '$currencyCode ' : '',
      decimalDigits: fractionDigits,
    );
    return formatter.format(minorUnits / divisor);
  }

  void _requireSameCurrency(Money other) {
    if (other.currencyCode != currencyCode) {
      throw ArgumentError(
        'No se pueden mezclar $currencyCode y ${other.currencyCode}.',
      );
    }
  }

  @override
  int compareTo(Money other) {
    _requireSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  @override
  bool operator ==(Object other) =>
      other is Money &&
      other.minorUnits == minorUnits &&
      other.currencyCode == currencyCode;

  @override
  int get hashCode => Object.hash(minorUnits, currencyCode);

  @override
  String toString() => format();
}

import '../money/money.dart';
import '../text/normalization.dart';

enum SudamerisEventType {
  cardPayment,
  salary,
  incomingTransfer,
  outgoingTransfer,
  expense,
  minimumPaymentNotice,
  ignored,
}

final class SudamerisParsedEvent {
  const SudamerisParsedEvent({
    required this.type,
    this.amountMinor,
    this.occurredAt,
    this.accountAlias,
    this.cardAlias,
    this.description,
    this.minimumDueDate,
  });

  final SudamerisEventType type;
  final int? amountMinor;
  final DateTime? occurredAt;
  final String? accountAlias;
  final String? cardAlias;
  final String? description;
  final DateTime? minimumDueDate;
}

final class SudamerisNotificationParser {
  const SudamerisNotificationParser();

  SudamerisParsedEvent? parse(String raw) {
    final normalized = normalizeForMatching(raw);
    if (_isOtp(normalized)) {
      return const SudamerisParsedEvent(type: SudamerisEventType.ignored);
    }

    final minimum = RegExp(
      r'PAGO\s+MINIMO.*?(?:\*{2,}|•{2,})\s*(\d{4}).*?PYG\s*([0-9](?:[0-9,.]*[0-9])?).*?(?:VTO\.?\s+DE\s+PAGO\s+EL|VENCIMIENTO)\s*:?\s*(\d{2}/\d{2}/\d{2,4})',
      caseSensitive: false,
    ).firstMatch(raw);
    if (minimum != null) {
      return SudamerisParsedEvent(
        type: SudamerisEventType.minimumPaymentNotice,
        cardAlias: minimum.group(1),
        amountMinor: _amount(minimum.group(2)),
        minimumDueDate: _date(minimum.group(3)!),
      );
    }

    final amountMatch = RegExp(
      r'PYG\s*([0-9](?:[0-9,.]*[0-9])?)',
      caseSensitive: false,
    ).firstMatch(raw);
    final dateMatch = RegExp(
      r'(\d{2}/\d{2}/(?:\d{2}|\d{4}))\s+(\d{2}:\d{2}(?::\d{2})?)',
    ).firstMatch(raw);
    if (amountMatch == null) return null;

    final amount = _amount(amountMatch.group(1));
    final occurredAt = dateMatch == null
        ? null
        : _dateTime(dateMatch.group(1)!, dateMatch.group(2)!);
    final accountAlias = _accountAlias(raw);
    final type = _type(normalized);
    return SudamerisParsedEvent(
      type: type,
      amountMinor: amount,
      occurredAt: occurredAt,
      accountAlias: accountAlias,
      description: _description(raw, amountMatch.start),
    );
  }

  bool _isOtp(String value) => RegExp(
    r'\b(OTP|CODIGO\s+DE\s+SEGURIDAD|CLAVE\s+TEMPORAL|NO\s+COMPARTAS)\b',
  ).hasMatch(value);

  SudamerisEventType _type(String value) {
    if (RegExp(r'PAGO\s+(?:DE\s+)?(?:TARJ|T\s*C)|PAGO\s+TARJ')
        .hasMatch(value)) {
      return SudamerisEventType.cardPayment;
    }
    if (value.contains('SALARIO') || value.contains('AGUINALDO')) {
      return SudamerisEventType.salary;
    }
    if (value.contains('SPI ENTRANTE')) {
      return SudamerisEventType.incomingTransfer;
    }
    if (value.contains('SPI SALIENTE') || value.contains('TRANSF E BANK')) {
      return SudamerisEventType.outgoingTransfer;
    }
    return SudamerisEventType.expense;
  }

  int? _amount(String? value) {
    if (value == null) return null;
    try {
      return Money.parse(value, currencyCode: 'PYG').minorUnits;
    } on FormatException {
      return null;
    }
  }

  String? _accountAlias(String raw) {
    final contextual = RegExp(
      r'(?:CAJA\s+DE\s+AHORROS|CUENTA).*?(?:\*{2,}|•{2,})\s*(\d{4,6})',
      caseSensitive: false,
    ).firstMatch(raw);
    return contextual?.group(1);
  }

  String? _description(String raw, int amountStart) {
    final prefix = raw.substring(0, amountStart);
    final pieces = prefix.split(RegExp(r'\s*,\s*'));
    if (pieces.length < 2) return null;
    return pieces[pieces.length - 2].trim();
  }

  DateTime _date(String value) {
    final parts = value.split('/').map(int.parse).toList();
    final year = parts[2] < 100 ? 2000 + parts[2] : parts[2];
    return DateTime(year, parts[1], parts[0]);
  }

  DateTime _dateTime(String date, String time) {
    final base = _date(date);
    final parts = time.split(':').map(int.parse).toList();
    return DateTime(
      base.year,
      base.month,
      base.day,
      parts[0],
      parts[1],
      parts.length > 2 ? parts[2] : 0,
    );
  }
}

import 'money.dart';

/// Validador de campos de importe. Por defecto exige un valor mayor que cero;
/// con [allowZero] admite cero (saldo real 0 al conciliar), pero no negativo.
String? validateAmount(
  String? value, {
  bool allowZero = false,
  String currencyCode = 'PYG',
}) {
  if (value == null || value.trim().isEmpty) return 'Ingresá un importe.';
  final int minor;
  try {
    minor = Money.parse(value, currencyCode: currencyCode).minorUnits;
  } on FormatException {
    return 'Ingresá un importe válido.';
  }
  if (allowZero) return minor >= 0 ? null : 'No puede ser negativo.';
  return minor > 0 ? null : 'El importe debe ser mayor que cero.';
}

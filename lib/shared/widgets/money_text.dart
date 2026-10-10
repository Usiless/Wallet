import 'package:flutter/material.dart';

import '../../core/money/money.dart';

final class MoneyText extends StatelessWidget {
  const MoneyText(
    this.minorUnits, {
    this.currencyCode = 'PYG',
    this.style,
    this.signed = false,
    this.currencySymbol,
    this.maxLines = 1,
    this.fitWidth = false,
    super.key,
  });

  final int minorUnits;
  final String currencyCode;
  final TextStyle? style;
  final bool signed;
  final String? currencySymbol;
  final int? maxLines;

  /// Reduce la escala del importe para que quepa completo en el ancho
  /// disponible, en lugar de cortarlo con «…». Solo se usa por opción explícita.
  final bool fitWidth;

  @override
  Widget build(BuildContext context) {
    final money = Money(minorUnits, currencyCode: currencyCode);
    final formatted = currencySymbol == null
        ? money.format()
        : '${money.format(withCode: false).trim()} $currencySymbol';
    final text = Text(
      signed && minorUnits > 0 ? '+$formatted' : formatted,
      style: style,
      maxLines: fitWidth ? 1 : maxLines,
      overflow: fitWidth ? TextOverflow.visible : TextOverflow.ellipsis,
    );
    if (!fitWidth) return text;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: text,
    );
  }
}

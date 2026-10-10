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
    super.key,
  });

  final int minorUnits;
  final String currencyCode;
  final TextStyle? style;
  final bool signed;
  final String? currencySymbol;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final money = Money(minorUnits, currencyCode: currencyCode);
    final formatted = currencySymbol == null
        ? money.format()
        : '${money.format(withCode: false).trim()} $currencySymbol';
    return Text(
      signed && minorUnits > 0 ? '+$formatted' : formatted,
      style: style,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
    );
  }
}

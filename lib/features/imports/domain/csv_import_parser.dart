import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:csv/csv.dart';

import '../../../core/money/money.dart';
import '../../../core/text/normalization.dart';
import '../../transactions/domain/ledger_models.dart';
import 'csv_import_models.dart';

final class CsvImportParser {
  const CsvImportParser();

  CsvImportPreview parse(
    String content, {
    String? delimiter,
    Set<String> existingReferences = const {},
    Set<String> existingFingerprints = const {},
    Set<String> knownAccounts = const {},
    Set<String> knownCategories = const {},
  }) {
    final clean = content.startsWith('\ufeff') ? content.substring(1) : content;
    final selectedDelimiter = delimiter ?? _detectDelimiter(clean);
    final matrix = Csv(
      fieldDelimiter: selectedDelimiter,
      autoDetect: false,
    ).decode(clean);
    if (matrix.isEmpty) {
      return CsvImportPreview(
        delimiter: selectedDelimiter,
        rows: const [],
        headers: const [],
      );
    }
    final headers = matrix.first
        .map((value) => _normalizeHeader('$value'))
        .toList();
    final missing = {'fecha', 'tipo', 'importe'}.difference(headers.toSet());
    if (missing.isNotEmpty) {
      final message = 'Faltan encabezados obligatorios: ${missing.join(', ')}.';
      return CsvImportPreview(
        delimiter: selectedDelimiter,
        headers: headers,
        rows: [
          CsvRowPreview(
            rowNumber: 1,
            original: const {},
            errors: [message],
            warnings: const [],
          ),
        ],
      );
    }

    final seenReferences = <String>{};
    final seenFingerprints = <String>{};
    final previews = <CsvRowPreview>[];
    for (var index = 1; index < matrix.length; index++) {
      final fields = <String, String>{};
      for (var column = 0; column < headers.length; column++) {
        fields[headers[column]] = column < matrix[index].length
            ? '${matrix[index][column]}'.trim()
            : '';
      }
      previews.add(
        _parseRow(
          index + 1,
          fields,
          knownAccounts: knownAccounts.map(normalizeForMatching).toSet(),
          knownCategories: knownCategories.map(normalizeForMatching).toSet(),
          existingReferences: existingReferences,
          existingFingerprints: existingFingerprints,
          seenReferences: seenReferences,
          seenFingerprints: seenFingerprints,
        ),
      );
    }
    return CsvImportPreview(
      delimiter: selectedDelimiter,
      rows: previews,
      headers: headers,
    );
  }

  CsvRowPreview _parseRow(
    int rowNumber,
    Map<String, String> fields, {
    required Set<String> knownAccounts,
    required Set<String> knownCategories,
    required Set<String> existingReferences,
    required Set<String> existingFingerprints,
    required Set<String> seenReferences,
    required Set<String> seenFingerprints,
  }) {
    final errors = <String>[];
    final warnings = <String>[];
    final type = _type(fields['tipo']);
    if (type == null) {
      errors.add('Tipo desconocido. Usá ingreso, gasto o transferencia.');
    }
    final date = _date(fields['fecha']);
    if (date == null) {
      errors.add('Fecha inválida. Usá YYYY-MM-DD o DD/MM/YYYY.');
    }
    final currency = (fields['moneda']?.trim().isEmpty ?? true)
        ? 'PYG'
        : fields['moneda']!.trim().toUpperCase();
    int? amount;
    try {
      amount = Money.parse(
        fields['importe'] ?? '',
        currencyCode: currency,
      ).minorUnits;
      if (amount <= 0) errors.add('El importe debe ser positivo.');
    } on FormatException {
      errors.add('Importe inválido.');
    }

    final from = _emptyToNull(fields['cuenta_origen']);
    final to = _emptyToNull(fields['cuenta_destino']);
    if (type == TransactionType.expense && from == null) {
      errors.add('El gasto requiere cuenta_origen.');
    }
    if (type == TransactionType.income && to == null) {
      errors.add('El ingreso requiere cuenta_destino.');
    }
    if (type == TransactionType.transfer && (from == null || to == null)) {
      errors.add('La transferencia requiere origen y destino.');
    }
    for (final account in [from, to].whereType<String>()) {
      if (knownAccounts.isNotEmpty &&
          !knownAccounts.contains(normalizeForMatching(account))) {
        warnings.add(
          'Cuenta desconocida: $account. Requiere mapeo antes de importar.',
        );
      }
    }
    final category = _emptyToNull(fields['categoria']);
    if (category != null &&
        knownCategories.isNotEmpty &&
        !knownCategories.contains(normalizeForMatching(category))) {
      warnings.add('Categoría nueva: $category.');
    }

    final reference = _emptyToNull(fields['referencia']);
    final fingerprint = sha256
        .convert(
          utf8.encode(
            [
              'csv-v1',
              date?.toIso8601String() ?? '',
              type?.name ?? '',
              amount?.toString() ?? '',
              currency,
              normalizeForMatching(from ?? ''),
              normalizeForMatching(to ?? ''),
              normalizeForMatching(_emptyToNull(fields['comercio']) ?? ''),
            ].join('|'),
          ),
        )
        .toString();
    final duplicate =
        (reference != null &&
            (existingReferences.contains(reference) ||
                !seenReferences.add(reference))) ||
        existingFingerprints.contains(fingerprint) ||
        !seenFingerprints.add(fingerprint);

    CsvTransactionRow? value;
    if (errors.isEmpty) {
      value = CsvTransactionRow(
        rowNumber: rowNumber,
        original: fields,
        type: type!,
        occurredAt: date!,
        amountMinor: amount!,
        currencyCode: currency,
        fromAccountName: from,
        toAccountName: to,
        category: category,
        subcategory: _emptyToNull(fields['subcategoria']),
        merchant: _emptyToNull(fields['comercio']),
        channel: _channel(fields['canal']),
        note: fields['nota'] ?? '',
        reference: reference,
        fingerprint: fingerprint,
      );
    }
    return CsvRowPreview(
      rowNumber: rowNumber,
      original: fields,
      errors: errors,
      warnings: warnings,
      value: value,
      isDuplicate: duplicate,
    );
  }

  String _detectDelimiter(String content) {
    final firstLine = content.split(RegExp(r'\r?\n')).first;
    final semicolons = ';'.allMatches(firstLine).length;
    final commas = ','.allMatches(firstLine).length;
    final tabs = '\t'.allMatches(firstLine).length;
    if (semicolons >= commas && semicolons >= tabs && semicolons > 0) {
      return ';';
    }
    if (tabs > commas) return '\t';
    return ',';
  }

  String _normalizeHeader(String value) =>
      normalizeForMatching(value).toLowerCase().replaceAll(' ', '_');

  TransactionType? _type(String? value) =>
      switch (normalizeForMatching(value ?? '')) {
        'INGRESO' || 'INCOME' => TransactionType.income,
        'GASTO' || 'EXPENSE' => TransactionType.expense,
        'TRANSFERENCIA' || 'TRANSFER' => TransactionType.transfer,
        'REEMBOLSO' || 'REFUND' => TransactionType.refund,
        'AJUSTE' || 'ADJUSTMENT' => TransactionType.adjustment,
        _ => null,
      };

  PaymentChannel _channel(String? value) => switch (normalizeForMatching(
    value ?? '',
  )) {
    'EFECTIVO' || 'CASH' => PaymentChannel.cash,
    'TARJETA FISICA' || 'PHYSICAL CARD' => PaymentChannel.physicalCard,
    'DEBITO' || 'DEBIT CARD' => PaymentChannel.debitCard,
    'TARJETA CREDITO' ||
    'PHYSICAL CREDIT CARD' => PaymentChannel.physicalCreditCard,
    'GOOGLE WALLET' ||
    'GOOGLE WALLET CONTACTLESS' => PaymentChannel.googleWalletContactless,
    'ONLINE' || 'ONLINE CARD' => PaymentChannel.onlineCard,
    'TRANSFERENCIA BANCARIA' || 'BANK TRANSFER' => PaymentChannel.bankTransfer,
    _ => PaymentChannel.other,
  };

  DateTime? _date(String? value) {
    if (value == null) return null;
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value.trim());
    if (iso != null) {
      return _checkedDate(iso.group(1)!, iso.group(2)!, iso.group(3)!);
    }
    final local = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(value.trim());
    if (local != null) {
      return _checkedDate(local.group(3)!, local.group(2)!, local.group(1)!);
    }
    return null;
  }

  DateTime? _checkedDate(String year, String month, String day) {
    final parsed = DateTime(int.parse(year), int.parse(month), int.parse(day));
    if (parsed.year != int.parse(year) ||
        parsed.month != int.parse(month) ||
        parsed.day != int.parse(day)) {
      return null;
    }
    return parsed;
  }

  String? _emptyToNull(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }
}

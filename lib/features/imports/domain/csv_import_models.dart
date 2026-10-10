import '../../transactions/domain/ledger_models.dart';

const canonicalCsvHeaders = [
  'fecha',
  'tipo',
  'importe',
  'moneda',
  'cuenta_origen',
  'cuenta_destino',
  'categoria',
  'subcategoria',
  'comercio',
  'canal',
  'nota',
  'referencia',
];

final class CsvTransactionRow {
  const CsvTransactionRow({
    required this.rowNumber,
    required this.original,
    required this.type,
    required this.occurredAt,
    required this.amountMinor,
    required this.currencyCode,
    required this.fingerprint,
    this.fromAccountName,
    this.toAccountName,
    this.category,
    this.subcategory,
    this.merchant,
    this.channel = PaymentChannel.other,
    this.note = '',
    this.reference,
  });

  final int rowNumber;
  final Map<String, String> original;
  final TransactionType type;
  final DateTime occurredAt;
  final int amountMinor;
  final String currencyCode;
  final String? fromAccountName;
  final String? toAccountName;
  final String? category;
  final String? subcategory;
  final String? merchant;
  final PaymentChannel channel;
  final String note;
  final String? reference;
  final String fingerprint;
}

final class CsvRowPreview {
  const CsvRowPreview({
    required this.rowNumber,
    required this.original,
    required this.errors,
    required this.warnings,
    this.value,
    this.isDuplicate = false,
  });

  final int rowNumber;
  final Map<String, String> original;
  final List<String> errors;
  final List<String> warnings;
  final CsvTransactionRow? value;
  final bool isDuplicate;

  bool get isValid => errors.isEmpty && value != null && !isDuplicate;
}

final class CsvImportPreview {
  const CsvImportPreview({
    required this.delimiter,
    required this.rows,
    required this.headers,
  });

  final String delimiter;
  final List<CsvRowPreview> rows;
  final List<String> headers;

  int get validCount => rows.where((row) => row.isValid).length;
  int get invalidCount => rows.where((row) => row.errors.isNotEmpty).length;
  int get duplicateCount => rows.where((row) => row.isDuplicate).length;
  int get warningCount => rows.where((row) => row.warnings.isNotEmpty).length;
}

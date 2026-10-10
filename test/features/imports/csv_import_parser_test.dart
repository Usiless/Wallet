import 'package:finanzas_locales/features/imports/domain/csv_import_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = CsvImportParser();
  const header =
      'fecha;tipo;importe;moneda;cuenta_origen;cuenta_destino;categoria;subcategoria;comercio;canal;nota;referencia';

  test('archivo completo válido y BOM UTF-8', () {
    final preview = parser.parse(
      '\ufeff$header\n2026-07-07;gasto;75000;PYG;Tarjeta;;;;Tienda;google_wallet;;compra-001',
      knownAccounts: const {'Tarjeta'},
    );
    expect(preview.delimiter, ';');
    expect(preview.validCount, 1);
    expect(preview.rows.single.value!.amountMinor, 75000);
  });

  test('separador incorrecto informa encabezados faltantes', () {
    final preview = parser.parse(
      '$header\n2026-07-07;gasto;1;PYG;Cuenta;;;;;;;x',
      delimiter: ',',
    );
    expect(preview.invalidCount, 1);
    expect(preview.rows.single.errors.single, contains('encabezados'));
  });

  test('cuenta desconocida y categoría nueva son advertencias visibles', () {
    final preview = parser.parse(
      '$header\n2026-07-07;gasto;75000;PYG;Desconocida;;Comida;;;;;x',
      knownAccounts: const {'Conocida'},
      knownCategories: const {'Transporte'},
    );
    expect(preview.validCount, 1);
    expect(preview.rows.single.warnings, hasLength(2));
  });

  test('rechaza fecha ambigua e importe inválido', () {
    final preview = parser.parse(
      '$header\n07/08/26;gasto;12x;PYG;Cuenta;;;;;;;x',
    );
    expect(preview.invalidCount, 1);
    expect(
      preview.rows.single.errors,
      containsAll([
        'Fecha inválida. Usá YYYY-MM-DD o DD/MM/YYYY.',
        'Importe inválido.',
      ]),
    );
  });

  test('detecta referencia repetida y huella secundaria', () {
    final content =
        '$header\n'
        '2026-07-07;gasto;75000;PYG;Cuenta;;;;Tienda;;;r1\n'
        '2026-07-07;gasto;75000;PYG;Cuenta;;;;Tienda;;;r1';
    final preview = parser.parse(content);
    expect(preview.validCount, 1);
    expect(preview.duplicateCount, 1);
  });

  test('permite importación parcial al conservar filas válidas', () {
    final content =
        '$header\n'
        '2026-07-07;gasto;75000;PYG;Cuenta;;;;Tienda;;;ok\n'
        'fecha-mala;gasto;75000;PYG;Cuenta;;;;Tienda;;;bad';
    final preview = parser.parse(content);
    expect(preview.validCount, 1);
    expect(preview.invalidCount, 1);
  });
}

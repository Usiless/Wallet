import 'dart:io';

import 'package:finanzas_locales/core/notifications/sudameris_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = SudamerisNotificationParser();

  test('pago de tarjeta se interpreta como transferencia', () {
    final event = parser.parse(
      File('test/fixtures/sudameris_notifications.txt').readAsLinesSync().first,
    );
    expect(event!.type, SudamerisEventType.cardPayment);
    expect(event.amountMinor, 75000);
    expect(event.accountAlias, '9647');
    expect(event.occurredAt, DateTime(2025, 11, 24, 19, 30, 25));
  });

  test('salario acepta año de dos dígitos y errores menores', () {
    final event = parser.parse(
      'SUDAMERIS Informa: Movimiento de Crédito , Salario s/instrucion , '
      'Caja de Ahorros N0 ***647000 , PYG 3,688,653.00 , 06/07/26 11:16:34',
    );
    expect(event!.type, SudamerisEventType.salary);
    expect(event.amountMinor, 3688653);
    expect(event.accountAlias, '647000');
    expect(event.occurredAt!.year, 2026);
  });

  test('transferencias sin contraparte quedan tipadas para completar', () {
    expect(
      parser
          .parse(
            'Transferencia SPI Entrante, PYG 190,000, 01/07/2026 10:00:00',
          )!
          .type,
      SudamerisEventType.incomingTransfer,
    );
    expect(
      parser
          .parse(
            'Transferencia SPI Saliente, PYG 190,000.00, 01/07/2026 10:00:00',
          )!
          .type,
      SudamerisEventType.outgoingTransfer,
    );
  });

  test('aviso de mínimo actualiza perfil y no representa movimiento', () {
    final event = parser.parse(
      'SUDAMERIS le informa: el Pago Minimo de su MASTERCARD CLASICA ****5962 '
      'es de PYG 1,603,000.00 con vto. de pago el: 03/02/26',
    );
    expect(event!.type, SudamerisEventType.minimumPaymentNotice);
    expect(event.cardAlias, '5962');
    expect(event.amountMinor, 1603000);
    expect(event.minimumDueDate, DateTime(2026, 2, 3));
  });

  test('ignora OTP sin almacenar contenido financiero', () {
    expect(
      parser.parse('Tu código de seguridad OTP es 123456. No compartas.')!.type,
      SudamerisEventType.ignored,
    );
  });

  test('salario y pago con misma hora permanecen tipos distintos', () {
    final salary = parser.parse(
      'Salario, Caja de Ahorros ***9647, PYG 100,000, 01/07/26 10:00:00',
    );
    final payment = parser.parse(
      'Pago de T.C.- Debito, Caja de Ahorros ***9647, PYG 100,000, 01/07/26 10:00:00',
    );
    expect(salary!.type, SudamerisEventType.salary);
    expect(payment!.type, SudamerisEventType.cardPayment);
  });
}

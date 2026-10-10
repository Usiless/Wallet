import 'package:drift/native.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/templates/manual_template_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plantillas se crean, editan y eliminan sin movimientos', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final service = ManualTemplateService(db);
    final id = await service.save('Alquiler', {
      'type': 'expense',
      'amountMinor': null,
    });
    expect((await service.read(id))!.fields['amountMinor'], isNull);
    await service.save('Alquiler mensual', {
      'type': 'expense',
      'amountMinor': 100000,
    }, id: id);
    expect((await service.watch().first).single.name, 'Alquiler mensual');
    expect((await service.read(id))!.fields['amountMinor'], 100000);
    expect(await db.select(db.ledgerTransactions).get(), isEmpty);
    expect(await db.select(db.accountPostings).get(), isEmpty);
    await service.delete(id);
    expect(await service.read(id), isNull);
    await db.close();
  });
}

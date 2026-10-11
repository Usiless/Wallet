import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/templates/manual_template_service.dart';
import 'package:finanzas_locales/features/templates/scheduled_template_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';

import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'un error inesperado al procesar deja un motivo de pendiente legible',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final account = await AccountsService(db).createAccount(
        const CreateAccountDraft(
          name: 'Banco',
          type: AccountType.bank,
          aliases: ['1234'],
        ),
      );
      final templates = ManualTemplateService(db);
      final id = await templates.save('Netflix', {
        'type': 'expense',
        'amountMinor': 10000,
        'from': account,
        'merchant': 'NETFLIX',
        'schedule': {
          'enabled': true,
          'frequency': 'monthly',
          'nextDate': '2026-10-04',
          'anchorDay': 4,
          'anchorMonth': 10,
        },
      });
      // Dato malformado escrito directo en la base: la fecha no es texto,
      // así que el procesamiento falla con un TypeError no previsto.
      final key = '${ManualTemplateService.prefix}$id';
      final row = await (db.select(
        db.appSettings,
      )..where((t) => t.key.equals(key))).getSingle();
      final json = jsonDecode(row.value) as Map<String, dynamic>;
      (json['fields'] as Map)['schedule'] = {
        'enabled': true,
        'frequency': 'monthly',
        'nextDate': 20261004,
        'anchorDay': 4,
        'anchorMonth': 10,
      };
      await (db.update(db.appSettings)..where((t) => t.key.equals(key))).write(
        AppSettingsCompanion(value: Value(jsonEncode(json))),
      );

      await ScheduledTemplateService(db).processDue(now: DateTime(2026, 10, 5));

      final saved = (await templates.read(id))!.fields['schedule'] as Map;
      expect(saved['pendingReason'], 'No se pudo completar la operación.');
    },
  );
}

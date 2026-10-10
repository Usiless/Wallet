import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../payments/domain/pending_payment_service.dart';
import '../transactions/domain/ledger_models.dart';

final class ManualTemplate {
  const ManualTemplate(this.id, this.name, this.fields);
  final String id;
  final String name;
  final Map<String, dynamic> fields;
}

final class ManualTemplateService {
  ManualTemplateService(this.database);
  final AppDatabase database;
  static const prefix = 'manual_template:';
  ManualTemplate _decode(SettingRecord row) {
    final json = jsonDecode(row.value) as Map<String, dynamic>;
    return ManualTemplate(
      row.key.substring(prefix.length),
      json['name'] as String,
      Map<String, dynamic>.from(json['fields'] as Map),
    );
  }

  Stream<List<ManualTemplate>> watch() =>
      (database.select(
        database.appSettings,
      )..where((t) => t.key.like('$prefix%'))).watch().map(
        (rows) => rows.map(_decode).toList()
          ..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          ),
      );
  Future<ManualTemplate?> read(String id) async {
    final row = await (database.select(
      database.appSettings,
    )..where((t) => t.key.equals('$prefix$id'))).getSingleOrNull();
    return row == null ? null : _decode(row);
  }

  Future<List<ManualTemplate>> list() async => (await (database.select(
    database.appSettings,
  )..where((t) => t.key.like('$prefix%'))).get()).map(_decode).toList();

  Future<String> save(
    String name,
    Map<String, dynamic> fields, {
    String? id,
    bool reconcilePreparedSchedule = true,
  }) => database.transaction(() async {
    if (name.trim().isEmpty) {
      throw const FormatException('Ingresá un nombre de plantilla.');
    }
    final schedule = fields['schedule'] as Map?;
    if (schedule?['enabled'] == true && schedule?['pendingReason'] == null) {
      final rawDate = schedule?['nextDate'];
      final parsed = rawDate is String ? DateTime.tryParse(rawDate) : null;
      if (parsed == null ||
          rawDate !=
              '${parsed.year.toString().padLeft(4, '0')}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')}') {
        throw const FormatException('Elegí una fecha válida.');
      }
      if (fields['type'] != 'expense' ||
          fields['installments'] == true ||
          fields['amountMinor'] is! int ||
          (fields['amountMinor'] as int) <= 0 ||
          fields['from'] == null ||
          !['monthly', 'yearly'].contains(schedule?['frequency']) ||
          schedule?['nextDate'] is! String) {
        throw const FormatException(
          'El registro automático requiere un gasto fijo, cuenta, frecuencia y fecha, sin plan de cuotas.',
        );
      }
    }
    final templateId = id ?? const Uuid().v4();
    final previous = id == null ? null : await read(id);
    if (previous != null && reconcilePreparedSchedule) {
      final oldSchedule = previous.fields['schedule'] as Map? ?? const {};
      final newSchedule = fields['schedule'] as Map? ?? const {};
      final calendarChanged = [
        'nextDate',
        'frequency',
        'anchorDay',
        'anchorMonth',
      ].any((key) => oldSchedule[key] != newSchedule[key]);
      if (calendarChanged) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        for (final p in await PendingPaymentService(database).list()) {
          if (!(p.sourceReference ?? '').startsWith('scheduled:$templateId:') ||
              p.cancelled ||
              p.payments.isNotEmpty ||
              p.dueDate.isBefore(today)) {
            continue;
          }
          p.data.addAll({
            'cancelled': true,
            'supersededBySchedule': true,
            'revision': p.revision + 1,
          });
          await database
              .into(database.appSettings)
              .insertOnConflictUpdate(
                AppSettingsCompanion.insert(
                  key: '${PendingPaymentService.prefix}${p.id}',
                  value: jsonEncode(p.data),
                  updatedAt: DateTime.now().toUtc(),
                ),
              );
        }
      }
    }
    final oldEconomic = Map<String, dynamic>.from(previous?.fields ?? {})
      ..remove('schedule');
    final newEconomic = Map<String, dynamic>.from(fields)..remove('schedule');
    if (previous != null &&
        (previous.name != name.trim() ||
            jsonEncode(oldEconomic) != jsonEncode(newEconomic))) {
      final service = PendingPaymentService(database);
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);
      final future = (await service.list())
          .where(
            (p) =>
                (p.sourceReference ?? '').startsWith(
                  'scheduled:$templateId:',
                ) &&
                !p.cancelled &&
                p.paidMinor == 0 &&
                !p.dueDate.isBefore(day),
          )
          .toList();
      if (future.isNotEmpty) {
        final splits = fields['splitEnabled'] == true
            ? [
                for (final part in fields['splits'] as List? ?? [])
                  SplitDraft(
                    categoryId: part['category'] as String,
                    amountMinor: part['amountMinor'] as int,
                  ),
              ]
            : fields['category'] != null
            ? [
                SplitDraft(
                  categoryId: fields['category'] as String,
                  amountMinor: fields['amountMinor'] as int,
                ),
              ]
            : <SplitDraft>[];
        final reminders = fields['reminders'] is Map
            ? PaymentReminderSettings.fromJson(fields['reminders'] as Map)
            : const PaymentReminderSettings();
        final channel = PaymentChannel.values.byName(
          fields['channel'] as String? ?? 'other',
        );
        if (fields['amountMinor'] is int &&
            (fields['amountMinor'] as int) > 0) {
          await service.validateDraft(
            amountMinor: fields['amountMinor'] as int,
            accountId: fields['from'] as String,
            merchantId: fields['merchantId'] as String?,
            paymentChannel: channel,
            splits: splits,
            reminders: reminders,
            allowCredit: true,
          );
          for (final p in future) {
            p.data.addAll({
              'description': name.trim(),
              'note': fields['note'] as String? ?? '',
              'revision': p.revision + 1,
              'amountMinor': fields['amountMinor'],
              'accountId': fields['from'],
              'merchantId': fields['merchantId'],
              'paymentChannel': channel.name,
              'reminders': reminders.toJson(),
              'splits': [
                for (final split in splits)
                  {
                    'categoryId': split.categoryId,
                    'amountMinor': split.amountMinor,
                  },
              ],
            });
            await database
                .into(database.appSettings)
                .insertOnConflictUpdate(
                  AppSettingsCompanion.insert(
                    key: '${PendingPaymentService.prefix}${p.id}',
                    value: jsonEncode(p.data),
                    updatedAt: DateTime.now().toUtc(),
                  ),
                );
          }
        }
      }
    }
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: '$prefix$templateId',
            value: jsonEncode({'name': name.trim(), 'fields': fields}),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
    return templateId;
  });

  Future<void> delete(String id) async {
    await (database.delete(
      database.appSettings,
    )..where((t) => t.key.equals('$prefix$id'))).go();
  }
}

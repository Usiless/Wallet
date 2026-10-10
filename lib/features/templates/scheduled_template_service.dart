import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import '../../core/errors/user_message.dart';
import '../../core/text/normalization.dart';
import '../merchants/merchant_service.dart';
import '../transactions/domain/ledger_models.dart';
import 'manual_template_service.dart';
import '../payments/domain/pending_payment_service.dart';

String scheduledDate(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
DateTime parseScheduledDate(String value) {
  final date = DateTime.parse(value);
  if (scheduledDate(date) != value) {
    throw const FormatException('Fecha de vencimiento inválida.');
  }
  return DateTime(date.year, date.month, date.day);
}

DateTime nextScheduledDate(DateTime due, Map<String, dynamic> schedule) {
  final yearly = schedule['frequency'] == 'yearly';
  final year = due.year + (yearly ? 1 : (due.month == 12 ? 1 : 0));
  final month = yearly
      ? (schedule['anchorMonth'] as int? ?? due.month)
      : due.month % 12 + 1;
  final last = DateTime(year, month + 1, 0).day;
  final day = schedule['anchorDay'] as int? ?? due.day;
  return DateTime(year, month, day > last ? last : day);
}

final class ScheduledProcessResult {
  final List<String> registered = [];
  final List<String> pending = [];
}

final class ScheduledTemplateService {
  ScheduledTemplateService(this.database);
  final AppDatabase database;
  ManualTemplateService get templates => ManualTemplateService(database);

  Future<void> pause(String id) => database.transaction(() async {
    final template = await templates.read(id);
    if (template == null) return;
    final fields = Map<String, dynamic>.from(template.fields);
    final schedule = Map<String, dynamic>.from(
      fields['schedule'] as Map? ?? {},
    );
    schedule['enabled'] = false;
    schedule['paused'] = true;
    fields['schedule'] = schedule;
    await templates.save(
      template.name,
      fields,
      id: id,
      reconcilePreparedSchedule: false,
    );
  });

  Future<void> skipPending(String id) => database.transaction(() async {
    final template = await templates.read(id);
    if (template == null) return;
    final fields = Map<String, dynamic>.from(template.fields);
    final schedule = Map<String, dynamic>.from(
      fields['schedule'] as Map? ?? {},
    );
    if (schedule['pendingReason'] == null) return;
    final due = parseScheduledDate(schedule['nextDate'] as String);
    schedule['nextDate'] = scheduledDate(nextScheduledDate(due, schedule));
    schedule.remove('pendingReason');
    fields['schedule'] = schedule;
    await templates.save(
      template.name,
      fields,
      id: id,
      reconcilePreparedSchedule: false,
    );
  });

  Future<ScheduledProcessResult> processDue({DateTime? now}) async {
    final today = parseScheduledDate(scheduledDate(now ?? DateTime.now()));
    final result = ScheduledProcessResult();
    for (final initial in await templates.list()) {
      for (var count = 0; count < 120; count++) {
        final outcome = await database.transaction(() async {
          final template = await templates.read(initial.id);
          if (template == null) return 'stop';
          final fields = Map<String, dynamic>.from(template.fields);
          final schedule = Map<String, dynamic>.from(
            fields['schedule'] as Map? ?? {},
          );
          if (schedule['enabled'] != true ||
              schedule['pendingReason'] != null) {
            return 'stop';
          }
          try {
            final due = parseScheduledDate(schedule['nextDate'] as String);
            if (due.isAfter(DateTime(today.year, today.month + 2, 0))) {
              return 'stop';
            }
            if (!['monthly', 'yearly'].contains(schedule['frequency'])) {
              throw StateError('Revisá la frecuencia.');
            }
            final fingerprint =
                'scheduled:${template.id}:${scheduledDate(due)}';
            final previous = await (database.select(
              database.ledgerTransactions,
            )..where((t) => t.externalFingerprint.equals(fingerprint))).get();
            if (previous.isEmpty) {
              if (fields['type'] != 'expense' ||
                  fields['installments'] == true) {
                throw StateError(
                  'Revisá el tipo de gasto y el plan de cuotas.',
                );
              }
              final amount = fields['amountMinor'] as int?;
              if (amount == null || amount <= 0) {
                throw StateError('Hace falta un importe fijo.');
              }
              final accountId = fields['from'] as String?;
              final account = accountId == null
                  ? null
                  : await (database.select(
                      database.accounts,
                    )..where((t) => t.id.equals(accountId))).getSingleOrNull();
              if (account == null || account.isArchived) {
                throw StateError('Elegí una cuenta activa.');
              }
              final occurredAt = DateTime(
                due.year,
                due.month,
                due.day,
                12,
              ).toUtc();
              if (account.currencyCode != 'PYG') {
                throw StateError('La programación admite PYG por ahora.');
              }
              String? merchantId = fields['merchantId'] as String?;
              if (merchantId != null) {
                final merchant = await (database.select(
                  database.merchants,
                )..where((t) => t.id.equals(merchantId!))).getSingleOrNull();
                if (merchant == null || merchant.isArchived) {
                  throw StateError('Revisá el comercio.');
                }
              } else if ((fields['merchant'] as String? ?? '')
                  .trim()
                  .isNotEmpty) {
                final matches = await MerchantService(database)
                    .matches(fields['merchant'] as String);
                if (matches.length > 1) {
                  throw StateError('El comercio es ambiguo.');
                }
                // Creating a new merchant happens only inside the successful ledger transaction.
                merchantId = matches.isEmpty ? null : matches.single.id;
              }
              final notifications =
                  await (database.select(database.paymentCandidates)..where(
                        (t) =>
                            t.status.equals('pending') &
                            t.amountMinor.equals(amount) &
                            t.occurredAt.isBetweenValues(
                              occurredAt.subtract(const Duration(days: 3)),
                              occurredAt.add(const Duration(days: 3)),
                            ),
                      ))
                      .get();
              for (final notification in notifications) {
                final notificationAccount =
                    notification.suggestedAccountId ??
                    notification.suggestedFromAccountId;
                final merchants = await MerchantService(database)
                    .matches(notification.rawMerchant ?? '');
                if (notificationAccount == accountId &&
                    ((merchantId != null &&
                            merchants.any((m) => m.id == merchantId)) ||
                        (normalizeForMatching(
                              fields['merchant'] as String? ?? '',
                            ).isNotEmpty &&
                            normalizeForMatching(
                                  notification.rawMerchant ?? '',
                                ) ==
                                normalizeForMatching(
                                  fields['merchant'] as String? ?? '',
                                )))) {
                  throw StateError(
                    'Hay una notificación pendiente de esta compra.',
                  );
                }
              }
              if (merchantId != null) {
                final duplicates =
                    await (database.select(database.ledgerTransactions)..where(
                          (t) =>
                              t.fromAccountId.equals(accountId!) &
                              t.merchantId.equals(merchantId!) &
                              t.amountMinor.equals(amount) &
                              t.status.equals('deleted').not() &
                              t.occurredAt.isBetweenValues(
                                occurredAt.subtract(const Duration(days: 3)),
                                occurredAt.add(const Duration(days: 3)),
                              ),
                        ))
                        .get();
                if (duplicates.isNotEmpty) {
                  throw StateError(
                    'Posible duplicado: revisá el movimiento existente.',
                  );
                }
              }
              final splits = <SplitDraft>[];
              if (fields['splitEnabled'] == true) {
                for (final split in fields['splits'] as List? ?? []) {
                  splits.add(
                    SplitDraft(
                      categoryId: split['category'] as String,
                      amountMinor: split['amountMinor'] as int,
                    ),
                  );
                }
              } else if (fields['category'] != null) {
                splits.add(
                  SplitDraft(
                    categoryId: fields['category'] as String,
                    amountMinor: amount,
                  ),
                );
              }
              for (final split in splits) {
                final category =
                    await (database.select(database.categories)
                          ..where((t) => t.id.equals(split.categoryId)))
                        .getSingleOrNull();
                if (category == null ||
                    category.isArchived ||
                    category.kind == 'income') {
                  throw StateError('Revisá la categoría.');
                }
              }
              await database.transaction(() async {
                merchantId ??=
                    (fields['merchant'] as String? ?? '').trim().isEmpty
                    ? null
                    : await MerchantService(database)
                          .findOrCreate(fields['merchant'] as String);
                final existing = (await PendingPaymentService(database).list())
                    .where(
                      (p) =>
                          p.sourceReference == fingerprint &&
                          p.data['supersededBySchedule'] != true,
                    );
                if (existing.isEmpty) {
                  result.registered.add(template.name);
                  await PendingPaymentService(database).createPlan(
                    amountMinor: amount,
                    installmentCount: 1,
                    firstDueDate: due,
                    accountId: account.id,
                    merchantId: merchantId,
                    description: template.name,
                    note: fields['note'] as String? ?? '',
                    paymentChannel: PaymentChannel.values.byName(
                      fields['channel'] as String? ?? 'other',
                    ),
                    splits: splits,
                    reminders: fields['reminders'] is Map
                        ? PaymentReminderSettings.fromJson(
                            fields['reminders'] as Map,
                          )
                        : const PaymentReminderSettings(),
                    sourceReference: fingerprint,
                  );
                }
              });
            }
            schedule['nextDate'] = scheduledDate(
              nextScheduledDate(due, schedule),
            );
            fields['schedule'] = schedule;
            await templates.save(
              template.name,
              fields,
              id: template.id,
              reconcilePreparedSchedule: false,
            );
            return 'next';
          } catch (error) {
            schedule['pendingReason'] = userMessage(error);
            fields['schedule'] = schedule;
            await templates.save(
              template.name,
              fields,
              id: template.id,
              reconcilePreparedSchedule: false,
            );
            result.pending.add(template.name);
            return 'stop';
          }
        });
        if (outcome == 'stop') break;
      }
    }
    return result;
  }
}

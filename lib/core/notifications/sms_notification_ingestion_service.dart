import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../features/accounts/data/accounts_service.dart';
import '../database/app_database.dart';
import '../config/feature_flags.dart';
import '../settings/settings_repository.dart';
import '../text/normalization.dart';
import 'notification_envelope.dart';
import 'sudameris_parser.dart';

final class SmsNotificationIngestionService {
  SmsNotificationIngestionService(
    this.database,
    this.accounts,
    this.settings, {
    Uuid? uuid,
    SudamerisNotificationParser? parser,
  }) : uuid = uuid ?? const Uuid(),
       parser = parser ?? const SudamerisNotificationParser();

  static const googleMessagesPackage = 'com.google.android.apps.messaging';

  final AppDatabase database;
  final AccountsService accounts;
  final SettingsRepository settings;
  final Uuid uuid;
  final SudamerisNotificationParser parser;

  Future<PaymentCandidateRecord?> ingest(NotificationEnvelope envelope) async {
    if (envelope.packageName != googleMessagesPackage ||
        !await settings.readBool('sms_notifications_enabled')) {
      return null;
    }
    final raw = envelope.combinedText;
    if (!normalizeForMatching(raw).contains('SUDAMERIS')) return null;
    final parsed = parser.parse(raw);
    if (parsed == null || parsed.type == SudamerisEventType.ignored) {
      return null;
    }

    final ownAccount = parsed.accountAlias == null
        ? null
        : await accounts.findByNameOrAlias(parsed.accountAlias!);
    if (parsed.type == SudamerisEventType.minimumPaymentNotice) {
      final card = parsed.cardAlias == null
          ? null
          : await accounts.findByNameOrAlias(parsed.cardAlias!);
      if (card != null && parsed.amountMinor != null) {
        await (database.update(
          database.creditCardProfiles,
        )..where((table) => table.accountId.equals(card.id))).write(
          CreditCardProfilesCompanion(
            minimumPaymentMinor: Value(parsed.amountMinor),
            minimumPaymentDueDate: Value(parsed.minimumDueDate),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
      }
      return null;
    }
    if (parsed.amountMinor == null) return null;

    final transactionType = switch (parsed.type) {
      SudamerisEventType.salary => 'income',
      SudamerisEventType.cardPayment ||
      SudamerisEventType.incomingTransfer ||
      SudamerisEventType.outgoingTransfer => 'transfer',
      _ => 'expense',
    };
    final card = parsed.type == SudamerisEventType.cardPayment
        ? await _firstCreditCard()
        : null;
    final fromAccountId = switch (parsed.type) {
      SudamerisEventType.salary || SudamerisEventType.incomingTransfer => null,
      _ => ownAccount?.id,
    };
    final toAccountId = switch (parsed.type) {
      SudamerisEventType.salary ||
      SudamerisEventType.incomingTransfer => ownAccount?.id,
      SudamerisEventType.cardPayment => card?.id,
      _ => null,
    };
    final requiresCounterparty =
        transactionType == 'transfer' &&
        (fromAccountId == null || toAccountId == null);
    final occurredAt = parsed.occurredAt ?? envelope.postTime;
    final fingerprintMaterial = [
      'sudameris-v1',
      parsed.type.name,
      normalizeForMatching(parsed.description ?? ''),
      ownAccount?.id ?? parsed.accountAlias ?? '',
      parsed.amountMinor,
      occurredAt.toUtc().toIso8601String(),
    ].join('|');
    final fingerprint = sha256
        .convert(utf8.encode(fingerprintMaterial))
        .toString();

    final existing =
        await (database.select(database.paymentCandidates)
              ..where((table) => table.fingerprint.equals(fingerprint)))
            .getSingleOrNull();
    if (existing != null) return null;

    final now = DateTime.now().toUtc();
    final eventId = uuid.v4();
    final retainRaw =
        developerToolsEnabled && await settings.readBool('diagnostic_mode');
    await database.transaction(() async {
      await database
          .into(database.notificationEvents)
          .insert(
            NotificationEventsCompanion.insert(
              id: eventId,
              envelopeVersion: Value(envelope.version),
              packageName: envelope.packageName,
              notificationKey: envelope.notificationKey,
              notificationId: envelope.id,
              tag: Value(envelope.tag),
              postedAt: envelope.postTime,
              title: Value(retainRaw ? envelope.title : null),
              notificationText: Value(retainRaw ? envelope.text : null),
              bigText: Value(retainRaw ? envelope.bigText : null),
              subText: Value(retainRaw ? envelope.subText : null),
              summaryText: Value(retainRaw ? envelope.summaryText : null),
              textLinesJson: Value(
                retainRaw ? jsonEncode(envelope.textLines) : '[]',
              ),
              isUpdate: Value(envelope.isUpdate),
              contentHash: sha256.convert(utf8.encode(raw)).toString(),
              expiresAt: now.add(const Duration(hours: 24)),
              createdAt: now,
            ),
          );
      await database
          .into(database.paymentCandidates)
          .insert(
            PaymentCandidatesCompanion.insert(
              id: uuid.v4(),
              eventId: eventId,
              transactionType: Value(transactionType),
              amountMinor: Value(parsed.amountMinor),
              currencyCode: const Value('PYG'),
              rawMerchant: Value(parsed.description),
              normalizedMerchant: Value(
                parsed.description == null
                    ? null
                    : normalizeForMatching(parsed.description!),
              ),
              suggestedAccountId: Value(ownAccount?.id),
              suggestedFromAccountId: Value(fromAccountId),
              suggestedToAccountId: Value(toAccountId),
              requiresCounterparty: Value(requiresCounterparty),
              detectedAlias: Value(parsed.accountAlias),
              occurredAt: occurredAt,
              source: 'smsNotification',
              amountConfidence: const Value(1),
              accountConfidence: Value(ownAccount == null ? 0 : 1),
              overallConfidence: Value(ownAccount == null ? 0.65 : 0.9),
              suggestionReason: Value(
                requiresCounterparty
                    ? 'Sudameris detectó una transferencia; completá la contraparte.'
                    : 'Tipo, importe y cuenta detectados en una alerta de Sudameris.',
              ),
              fingerprintVersion: const Value('sudameris-v1'),
              fingerprint: fingerprint,
              createdAt: now,
              updatedAt: now,
            ),
          );
    });
    return (database.select(
      database.paymentCandidates,
    )..where((table) => table.eventId.equals(eventId))).getSingle();
  }

  Future<AccountRecord?> _firstCreditCard() {
    return (database.select(database.accounts)
          ..where(
            (table) =>
                table.type.equals('creditCard') &
                table.isArchived.equals(false),
          )
          ..limit(1))
        .getSingleOrNull();
  }
}

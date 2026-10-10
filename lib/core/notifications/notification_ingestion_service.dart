import '../../features/payments/domain/pending_payment_service.dart';

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../features/pending_inbox/domain/payment_candidate.dart';
import '../../features/transactions/data/ledger_service.dart';
import '../../features/merchants/merchant_service.dart';
import '../../features/transactions/domain/ledger_models.dart';
import '../database/app_database.dart';
import '../config/feature_flags.dart';
import '../money/money.dart';
import '../settings/settings_repository.dart';
import '../text/normalization.dart';
import 'google_wallet_extractor.dart';
import 'notification_envelope.dart';

final class NotificationIngestionService {
  NotificationIngestionService(
    this.database,
    this.ledger, {
    required this.settings,
    Uuid? uuid,
    GoogleWalletExtractor? extractor,
    NotificationDeduplicator? deduplicator,
  }) : uuid = uuid ?? const Uuid(),
       extractor = extractor ?? const GoogleWalletExtractor(),
       deduplicator = deduplicator ?? const NotificationDeduplicator();

  final AppDatabase database;
  final LedgerService ledger;
  final SettingsRepository settings;
  final Uuid uuid;
  final GoogleWalletExtractor extractor;
  final NotificationDeduplicator deduplicator;

  Future<PaymentCandidateRecord?> ingest(NotificationEnvelope envelope) {
    if (envelope.isTest && !developerToolsEnabled) return Future.value(null);
    return database.transaction(() => _ingest(envelope));
  }

  Future<PaymentCandidateRecord?> _ingest(NotificationEnvelope envelope) async {
    final contentHash = sha256
        .convert(utf8.encode(envelope.combinedText))
        .toString();
    // A replay can match an older version, not only the latest update.
    final exactEvent =
        await (database.select(database.notificationEvents)..where(
              (table) =>
                  table.packageName.equals(envelope.packageName) &
                  table.notificationKey.equals(envelope.notificationKey) &
                  table.contentHash.equals(contentHash),
            ))
            .getSingleOrNull();
    final existingEvent =
        exactEvent ??
        await (database.select(database.notificationEvents)
              ..where(
                (table) =>
                    table.packageName.equals(envelope.packageName) &
                    table.notificationKey.equals(envelope.notificationKey),
              )
              ..orderBy([(table) => OrderingTerm.desc(table.createdAt)])
              ..limit(1))
            .getSingleOrNull();
    final decision = deduplicator.decide(
      incoming: envelope,
      incomingContentHash: contentHash,
      existingNotificationKey: existingEvent?.notificationKey,
      existingContentHash: existingEvent?.contentHash,
    );
    if (decision.action == DedupAction.exactDuplicate) {
      await _recordDecision(existingEvent!.id, null, decision);
      return null;
    }

    final eventId = uuid.v4();
    final now = DateTime.now().toUtc();
    final retainRaw =
        developerToolsEnabled && await settings.readBool('diagnostic_mode');
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
            postedAt: envelope.postTime.toUtc(),
            title: Value(retainRaw ? envelope.title : null),
            notificationText: Value(retainRaw ? envelope.text : null),
            bigText: Value(retainRaw ? envelope.bigText : null),
            subText: Value(retainRaw ? envelope.subText : null),
            summaryText: Value(retainRaw ? envelope.summaryText : null),
            textLinesJson: Value(
              retainRaw ? jsonEncode(envelope.textLines) : '[]',
            ),
            isUpdate: Value(envelope.isUpdate),
            contentHash: contentHash,
            expiresAt: now.add(const Duration(hours: 24)),
            createdAt: now,
          ),
        );

    final candidate = await preview(envelope);
    if (candidate == null) {
      await _recordDecision(
        eventId,
        null,
        const DedupResult(
          DedupAction.create,
          'La notificación no contiene una compra compatible.',
        ),
      );
      return null;
    }

    final existingCandidate = existingEvent == null
        ? null
        : await (database.select(database.paymentCandidates)
                ..where((table) => table.eventId.equals(existingEvent.id)))
              .getSingleOrNull();
    final candidateId = existingCandidate?.id ?? uuid.v4();
    final companion = PaymentCandidatesCompanion(
      id: Value(candidateId),
      eventId: Value(eventId),
      status: Value(existingCandidate?.status ?? 'pending'),
      transactionType: Value(candidate.transactionType),
      amountMinor: Value(candidate.amountMinor),
      currencyCode: Value(candidate.currencyCode),
      rawMerchant: Value(candidate.rawMerchant),
      normalizedMerchant: Value(candidate.normalizedMerchant),
      suggestedAccountId: Value(candidate.suggestedAccountId),
      suggestedFromAccountId: Value(
        candidate.suggestedFromAccountId ?? candidate.suggestedAccountId,
      ),
      suggestedToAccountId: Value(candidate.suggestedToAccountId),
      requiresCounterparty: Value(candidate.requiresCounterparty),
      detectedAlias: Value(candidate.detectedAlias),
      occurredAt: Value(candidate.occurredAt.toUtc()),
      source: Value(candidate.source),
      amountConfidence: Value(candidate.amountConfidence),
      merchantConfidence: Value(candidate.merchantConfidence),
      accountConfidence: Value(candidate.accountConfidence),
      overallConfidence: Value(candidate.overallConfidence),
      suggestionReason: Value(candidate.reason),
      fingerprintVersion: const Value('v1'),
      fingerprint: Value(candidate.fingerprint),
      createdAt: Value(existingCandidate?.createdAt ?? now),
      updatedAt: Value(now),
    );
    if (existingCandidate == null) {
      await database.into(database.paymentCandidates).insert(companion);
    } else {
      await (database.update(
        database.paymentCandidates,
      )..where((table) => table.id.equals(candidateId))).write(companion);
    }
    await _recordDecision(eventId, candidateId, decision);
    return (database.select(
      database.paymentCandidates,
    )..where((table) => table.id.equals(candidateId))).getSingle();
  }

  Stream<List<PaymentCandidateRecord>> watchPending() {
    return (database.select(database.paymentCandidates)
          ..where((table) => table.status.equals('pending'))
          ..orderBy([(table) => OrderingTerm.desc(table.occurredAt)]))
        .watch();
  }

  /// Interpreta sin guardar eventos ni modificar saldos.
  Future<PaymentCandidate?> preview(NotificationEnvelope envelope) async {
    final accounts = await (database.select(
      database.accounts,
    )..where((table) => table.isArchived.equals(false))).get();
    final activeIds = accounts.map((account) => account.id).toSet();
    final aliases = await database.select(database.accountAliases).get();
    final matches = <String, Set<String>>{};
    for (final alias in aliases) {
      if (!activeIds.contains(alias.accountId)) continue;
      matches
          .putIfAbsent(normalizeMaskedAlias(alias.normalizedAlias), () => {})
          .add(alias.accountId);
    }
    return extractor.extract(
      envelope,
      accountIdByAlias: {
        for (final entry in matches.entries)
          if (entry.value.length == 1) entry.key: entry.value.single,
      },
    );
  }

  Future<PaymentCandidateRecord?> process(NotificationEnvelope envelope) async {
    var candidate = await ingest(envelope);
    if (candidate != null &&
        candidate.status == 'pending' &&
        candidate.suggestedAccountId != null &&
        candidate.amountMinor != null) {
      final merchants = await MerchantService(database)
          .matches(candidate.rawMerchant ?? '');
      if (merchants.length == 1) {
        final scheduled =
            await (database.select(database.ledgerTransactions)..where(
                  (t) =>
                      (t.source.equals('recurring') |
                          t.externalFingerprint.like('scheduled:%') |
                          t.sourceReference.like('scheduled:%') |
                          t.externalFingerprint.like('pending:%')) &
                      t.fromAccountId.equals(candidate.suggestedAccountId!) &
                      t.merchantId.equals(merchants.single.id) &
                      t.amountMinor.equals(candidate.amountMinor!) &
                      t.status.equals('deleted').not() &
                      t.occurredAt.isBetweenValues(
                        candidate.occurredAt.subtract(const Duration(days: 3)),
                        candidate.occurredAt.add(const Duration(days: 3)),
                      ),
                ))
                .get();
        final pendingDues = (await PendingPaymentService(database).list())
            .where(
              (p) =>
                  !p.cancelled &&
                  p.remainingMinor > 0 &&
                  p.accountId == candidate.suggestedAccountId &&
                  p.merchantId == merchants.single.id &&
                  (p.amountMinor == candidate.amountMinor ||
                      p.remainingMinor == candidate.amountMinor) &&
                  p.dueDate.difference(candidate.occurredAt).inDays.abs() <= 3,
            );
        if (scheduled.isNotEmpty || pendingDues.isNotEmpty) {
          const reason =
              'Posible coincidencia con un registro programado; revisá antes de registrar.';
          await (database.update(
            database.paymentCandidates,
          )..where((t) => t.id.equals(candidate.id))).write(
            const PaymentCandidatesCompanion(suggestionReason: Value(reason)),
          );
          return candidate.copyWith(suggestionReason: reason);
        }
      }
    }
    if (candidate == null ||
        candidate.status != 'pending' ||
        !await settings.readBool('wallet_auto_register') ||
        (!envelope.isTest &&
            !await settings.readBool('notification_listener_enabled')) ||
        envelope.isUpdate ||
        RegExp(
              r'\bPYG\s*[0-9]',
              caseSensitive: false,
            ).allMatches(envelope.combinedText).length !=
            1 ||
        candidate.amountMinor == null ||
        candidate.amountMinor! <= 0 ||
        candidate.suggestedAccountId == null ||
        candidate.rawMerchant == null ||
        envelope.title == null ||
        normalizeForMatching(envelope.title!) !=
            normalizeForMatching(candidate.rawMerchant!)) {
      return candidate;
    }
    final merchants = await MerchantService(database)
        .matches(candidate.rawMerchant!);
    if (merchants.length != 1) return candidate;
    final previous =
        await (database.select(database.ledgerTransactions)..where(
              (table) =>
                  table.fromAccountId.equals(candidate.suggestedAccountId!) &
                  table.merchantId.equals(merchants.single.id) &
                  table.amountMinor.equals(candidate.amountMinor!) &
                  table.status.equals('deleted').not() &
                  table.occurredAt.isBetweenValues(
                    candidate.occurredAt.subtract(const Duration(minutes: 2)),
                    candidate.occurredAt.add(const Duration(minutes: 2)),
                  ),
            ))
            .get();
    if (previous.isNotEmpty) return candidate;
    try {
      await confirm(
        candidate,
        fromAccountId: candidate.suggestedAccountId,
        merchantId: merchants.single.id,
        automatic: true,
      );
    } catch (_) {
      // Keep the proposal pending when any validation or association fails.
    }
    return (database.select(
      database.paymentCandidates,
    )..where((table) => table.id.equals(candidate.id))).getSingle();
  }

  Future<String> confirm(
    PaymentCandidateRecord candidate, {
    String? accountId,
    String? fromAccountId,
    String? toAccountId,
    String? merchantId,
    String? merchantName,
    bool automatic = false,
    Money? revisedAmount,
    String? categoryId,
    bool rememberCategory = false,
    List<SplitDraft> splits = const [],
  }) => database.transaction(() async {
    final current = await (database.select(
      database.paymentCandidates,
    )..where((table) => table.id.equals(candidate.id))).getSingle();
    if (current.status != 'pending') {
      throw StateError('La propuesta ya fue confirmada o ignorada.');
    }
    if (revisedAmount != null &&
        (automatic ||
            revisedAmount.minorUnits <= 0 ||
            revisedAmount.currencyCode != current.currencyCode)) {
      throw StateError('El importe revisado no es válido para esta propuesta.');
    }
    candidate = current.copyWith(
      amountMinor: Value(revisedAmount?.minorUnits ?? current.amountMinor),
    );
    final active =
        await (database.select(database.ledgerTransactions)..where(
              (table) =>
                  table.externalFingerprint.equals(candidate.fingerprint) &
                  table.status.equals('deleted').not(),
            ))
            .get();
    if (active.isNotEmpty) {
      throw StateError('Esta compra ya tiene un movimiento activo.');
    }
    if (candidate.amountMinor == null || candidate.currencyCode == null) {
      throw StateError('El candidato no tiene un importe válido.');
    }
    final type = TransactionType.values.byName(candidate.transactionType);
    final resolvedFrom =
        fromAccountId ??
        candidate.suggestedFromAccountId ??
        (type == TransactionType.expense ? accountId : null);
    final resolvedTo =
        toAccountId ??
        candidate.suggestedToAccountId ??
        (type == TransactionType.income || type == TransactionType.refund
            ? accountId
            : null);
    if (automatic) {
      if (!await settings.readBool('wallet_auto_register') ||
          resolvedFrom == null ||
          merchantId == null) {
        throw StateError(
          'El registro automático no está habilitado o faltan asociaciones.',
        );
      }
      final merchants = await MerchantService(database)
          .matches(candidate.rawMerchant ?? '');
      final accounts = await preview(
        NotificationEnvelope(
          version: 1,
          packageName: 'com.google.android.apps.walletnfcrel',
          notificationKey: 'validation',
          id: 0,
          postTime: candidate.occurredAt,
          title: candidate.rawMerchant,
          text: 'PYG ${candidate.amountMinor} · ••${candidate.detectedAlias}',
        ),
      );
      if (merchants.length != 1 ||
          merchants.single.id != merchantId ||
          accounts?.suggestedAccountId != resolvedFrom) {
        throw StateError('Las asociaciones cambiaron; revisá la propuesta.');
      }
      final recent =
          await (database.select(database.ledgerTransactions)..where(
                (table) =>
                    table.fromAccountId.equals(resolvedFrom) &
                    table.merchantId.equals(merchantId) &
                    table.amountMinor.equals(candidate.amountMinor!) &
                    table.status.equals('deleted').not() &
                    (table.occurredAt.isBetweenValues(
                          candidate.occurredAt.subtract(
                            const Duration(minutes: 2),
                          ),
                          candidate.occurredAt.add(const Duration(minutes: 2)),
                        ) |
                        ((table.source.equals('recurring') |
                                table.externalFingerprint.like('scheduled:%') |
                                table.sourceReference.like('scheduled:%') |
                                table.externalFingerprint.like('pending:%')) &
                            table.occurredAt.isBetweenValues(
                              candidate.occurredAt.subtract(
                                const Duration(days: 3),
                              ),
                              candidate.occurredAt.add(const Duration(days: 3)),
                            ))),
              ))
              .get();
      final dues = (await PendingPaymentService(database).list()).where(
        (p) =>
            !p.cancelled &&
            p.remainingMinor > 0 &&
            p.accountId == resolvedFrom &&
            p.merchantId == merchantId &&
            (p.amountMinor == candidate.amountMinor ||
                p.remainingMinor == candidate.amountMinor) &&
            p.dueDate.difference(candidate.occurredAt).inDays.abs() <= 3,
      );
      if (recent.isNotEmpty || dues.isNotEmpty) {
        throw StateError('Posible compra duplicada; requiere revisión.');
      }
    }
    final merchantService = MerchantService(database);
    String? resolvedMerchant = merchantId;
    String? resolvedMerchantName;
    if (candidate.source != 'smsNotification') {
      final raw = candidate.rawMerchant?.trim() ?? '';
      if (resolvedMerchant == null && raw.isNotEmpty) {
        resolvedMerchant = await merchantService.findOrCreate(
          merchantName?.trim().isNotEmpty == true ? merchantName!.trim() : raw,
          source: candidate.source,
        );
      }
      if (resolvedMerchant != null) {
        final merchant = await (database.select(
          database.merchants,
        )..where((table) => table.id.equals(resolvedMerchant!))).getSingle();
        if (merchant.isArchived) {
          throw StateError('El comercio está archivado.');
        }
        resolvedMerchantName = merchant.name;
        if (raw.isNotEmpty) {
          await merchantService.learnAlias(resolvedMerchant, raw);
        }
      }
    }
    if (rememberCategory &&
        resolvedMerchant != null &&
        type == TransactionType.expense) {
      await merchantService.rememberCategory(resolvedMerchant, categoryId);
    }
    final resolvedCategory = automatic && resolvedMerchant != null
        ? await merchantService.defaultCategory(resolvedMerchant)
        : categoryId;
    final transactionId = await ledger.create(
      TransactionDraft(
        type: type,
        amount: Money(
          candidate.amountMinor!,
          currencyCode: candidate.currencyCode!,
        ),
        occurredAt: candidate.occurredAt,
        source: candidate.source == 'developerTest'
            ? TransactionSource.developerTest
            : candidate.source == 'smsNotification'
            ? TransactionSource.smsNotification
            : TransactionSource.googleWalletNotification,
        fromAccountId: resolvedFrom,
        toAccountId: resolvedTo,
        merchantId: resolvedMerchant,
        note: automatic ? 'Registrado automáticamente' : '',
        description:
            (candidate.source == 'developerTest' ? '[PRUEBA] ' : '') +
            (resolvedMerchantName ??
                candidate.normalizedMerchant ??
                candidate.rawMerchant ??
                'Compra detectada'),
        paymentChannel: candidate.source == 'smsNotification'
            ? PaymentChannel.other
            : PaymentChannel.googleWalletContactless,
        splits: splits.isNotEmpty
            ? splits
            : [
                if (resolvedCategory != null && type == TransactionType.expense)
                  SplitDraft(
                    categoryId: resolvedCategory,
                    amountMinor: candidate.amountMinor!,
                  ),
              ],
        externalFingerprint: candidate.fingerprint,
        sourceReference: candidate.eventId,
      ),
    );
    await (database.update(
      database.paymentCandidates,
    )..where((table) => table.id.equals(candidate.id))).write(
      PaymentCandidatesCompanion(
        status: const Value('confirmed'),
        amountMinor: Value(candidate.amountMinor),
        transactionId: Value(transactionId),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    if ((candidate.source == 'googleWalletNotification' ||
            candidate.source == 'developerTest') &&
        type == TransactionType.expense &&
        resolvedFrom != null &&
        candidate.detectedAlias != null) {
      final normalized = normalizeMaskedAlias(candidate.detectedAlias!);
      final existing = await (database.select(
        database.accountAliases,
      )..where((table) => table.accountId.equals(resolvedFrom))).get();
      if (normalized.isNotEmpty &&
          !existing.any(
            (alias) =>
                normalizeMaskedAlias(alias.normalizedAlias) == normalized,
          )) {
        await database
            .into(database.accountAliases)
            .insert(
              AccountAliasesCompanion.insert(
                id: uuid.v4(),
                accountId: resolvedFrom,
                alias: candidate.detectedAlias!,
                normalizedAlias: normalized,
                source: 'googleWalletNotification',
                createdAt: DateTime.now().toUtc(),
              ),
            );
      }
    }
    return transactionId;
  });

  Future<void> ignore(String candidateId) async {
    final changed =
        await (database.update(database.paymentCandidates)..where(
              (table) =>
                  table.id.equals(candidateId) & table.status.equals('pending'),
            ))
            .write(
              PaymentCandidatesCompanion(
                status: const Value('ignored'),
                updatedAt: Value(DateTime.now().toUtc()),
              ),
            );
    if (changed != 1) throw StateError('Esta propuesta ya no está pendiente.');
  }

  Future<int> purgeExpiredRawEvents() {
    final now = DateTime.now().toUtc();
    // Keep event identity for candidates and deduplication; only raw diagnostic
    // content expires. Deleting referenced events violates foreign keys.
    return (database.update(database.notificationEvents)..where(
          (table) =>
              table.expiresAt.isSmallerThanValue(now) &
              (table.title.isNotNull() |
                  table.notificationText.isNotNull() |
                  table.bigText.isNotNull() |
                  table.subText.isNotNull() |
                  table.summaryText.isNotNull() |
                  table.textLinesJson.isNotValue('[]')),
        ))
        .write(
          const NotificationEventsCompanion(
            title: Value(null),
            notificationText: Value(null),
            bigText: Value(null),
            subText: Value(null),
            summaryText: Value(null),
            textLinesJson: Value('[]'),
          ),
        );
  }

  Future<void> _recordDecision(
    String eventId,
    String? candidateId,
    DedupResult decision,
  ) {
    return database
        .into(database.dedupDecisions)
        .insert(
          DedupDecisionsCompanion.insert(
            id: uuid.v4(),
            eventId: eventId,
            candidateId: Value(candidateId),
            decision: decision.action.name,
            reason: decision.reason,
            createdAt: DateTime.now().toUtc(),
          ),
        );
  }
}

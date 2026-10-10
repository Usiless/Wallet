import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../features/pending_inbox/domain/payment_candidate.dart';
import '../money/money.dart';
import '../text/normalization.dart';
import 'notification_envelope.dart';
import '../config/feature_flags.dart';

final class GoogleWalletExtractor {
  const GoogleWalletExtractor();

  static const supportedPackages = {
    'com.google.android.gms',
    'com.google.android.apps.walletnfcrel',
  };

  PaymentCandidate? extract(
    NotificationEnvelope envelope, {
    Set<String> allowedPackages = supportedPackages,
    Map<String, String> accountIdByAlias = const {},
  }) {
    if (envelope.isTest && !developerToolsEnabled) return null;
    if (!allowedPackages.contains(envelope.packageName)) return null;
    final body = envelope.combinedText;
    final amountMatch = RegExp(
      r'\b(PYG)\s*([0-9](?:[0-9.,]*[0-9])?)',
      caseSensitive: false,
    ).firstMatch(body);
    if (amountMatch == null) return null;

    int? amount;
    try {
      amount = Money.parse(
        amountMatch.group(2)!,
        currencyCode: amountMatch.group(1)!.toUpperCase(),
      ).minorUnits;
    } on FormatException {
      return null;
    }

    final aliasMatch = RegExp(r'(?:[•*]{2,}\s*)(\d{4,6})').firstMatch(body);
    final alias = aliasMatch?.group(1);
    final accountId = alias == null
        ? null
        : accountIdByAlias[normalizeMaskedAlias(alias)];
    final merchant = _merchant(envelope, amountMatch.group(0)!);
    final normalizedMerchant = merchant == null
        ? null
        : normalizeMerchant(merchant);
    final amountConfidence = 1.0;
    final merchantConfidence = merchant == null ? 0.0 : 0.65;
    final accountConfidence = accountId == null ? 0.0 : 1.0;
    final overall =
        (amountConfidence * 0.5) +
        (merchantConfidence * 0.25) +
        (accountConfidence * 0.25);
    final fingerprintMaterial = [
      'wallet-v1',
      envelope.packageName,
      envelope.notificationKey,
      amount.toString(),
      normalizedMerchant ?? '',
      envelope.postTime.toUtc().toIso8601String(),
    ].join('|');

    return PaymentCandidate(
      amountMinor: amount,
      currencyCode: 'PYG',
      rawMerchant: merchant,
      normalizedMerchant: normalizedMerchant,
      suggestedAccountId: accountId,
      detectedAlias: alias,
      occurredAt: envelope.postTime,
      source: envelope.isTest ? 'developerTest' : 'googleWalletNotification',
      amountConfidence: amountConfidence,
      merchantConfidence: merchantConfidence,
      accountConfidence: accountConfidence,
      overallConfidence: overall,
      reason: accountId == null
          ? 'Importe detectado; revisá la tarjeta y el comercio.'
          : 'Importe y alias de tarjeta detectados en la notificación.',
      fingerprint: sha256.convert(utf8.encode(fingerprintMaterial)).toString(),
    );
  }

  String? _merchant(NotificationEnvelope envelope, String amountToken) {
    final title = envelope.title?.trim();
    if (title != null &&
        title.isNotEmpty &&
        !RegExp(
          r'^(compra|pago|google wallet)$',
          caseSensitive: false,
        ).hasMatch(title) &&
        !RegExp(r'\bPYG\s*\d', caseSensitive: false).hasMatch(title)) {
      return title.replaceAll(RegExp(r'\s+'), ' ');
    }
    final candidates = [envelope.title, envelope.text, envelope.bigText]
        .whereType<String>()
        .map((value) => value.replaceAll(amountToken, '').trim())
        .where((value) => value.isNotEmpty)
        .where(
          (value) => !RegExp(
            r'^(compra|pago|google wallet)$',
            caseSensitive: false,
          ).hasMatch(value),
        )
        .toList();
    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => a.length.compareTo(b.length));
    return candidates.first.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}

String normalizeMerchant(String value) {
  var normalized = normalizeForMatching(value);
  normalized = normalized.replaceAll(
    RegExp(r'\bSPOTIFY\s+P[A-Z0-9]+\s+S\b'),
    'SPOTIFY',
  );
  return normalized;
}

final class NotificationDeduplicator {
  const NotificationDeduplicator();

  DedupResult decide({
    required NotificationEnvelope incoming,
    required String incomingContentHash,
    String? existingNotificationKey,
    String? existingContentHash,
  }) {
    if (existingNotificationKey == null) {
      return const DedupResult(DedupAction.create, 'Clave nueva.');
    }
    if (existingNotificationKey != incoming.notificationKey) {
      return const DedupResult(
        DedupAction.create,
        'Evento independiente: la clave de notificación es distinta.',
      );
    }
    if (existingContentHash == incomingContentHash) {
      return const DedupResult(
        DedupAction.exactDuplicate,
        'Misma fuente, clave y contenido.',
      );
    }
    return const DedupResult(
      DedupAction.updateExisting,
      'La misma notificación recibió contenido actualizado.',
    );
  }
}

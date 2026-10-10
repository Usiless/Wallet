import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:finanzas_locales/core/notifications/google_wallet_extractor.dart';
import 'package:finanzas_locales/core/notifications/notification_envelope.dart';
import 'package:finanzas_locales/features/pending_inbox/domain/payment_candidate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const extractor = GoogleWalletExtractor();
  const deduplicator = NotificationDeduplicator();

  NotificationEnvelope envelope({
    String key = 'key-1',
    String? title = 'ECOP OBLIGADO',
    String? text = 'PYG145,500 · SUDAM_GOOGLE ••5962',
    bool update = false,
  }) => NotificationEnvelope(
    version: 1,
    packageName: 'com.google.android.gms',
    notificationKey: key,
    id: 1,
    postTime: DateTime.utc(2026, 7, 18, 18),
    title: title,
    text: text,
    isUpdate: update,
  );

  test('extrae PYG sin espacio y resuelve alias 5962', () {
    final candidate = extractor.extract(
      NotificationEnvelope.fromMap(
        jsonDecode(
          File('test/fixtures/google_wallet_notification.json')
              .readAsStringSync(),
        ) as Map<String, dynamic>,
      ),
      accountIdByAlias: const {'5962': 'card-id'},
    );
    expect(candidate, isNotNull);
    expect(candidate!.amountMinor, 145500);
    expect(candidate.currencyCode, 'PYG');
    expect(candidate.suggestedAccountId, 'card-id');
    expect(candidate.normalizedMerchant, 'ECOP OBLIGADO');
  });

  test('ignora paquete no permitido y campos insuficientes', () {
    final foreign = NotificationEnvelope(
      version: 1,
      packageName: 'example.other',
      notificationKey: 'a',
      id: 1,
      postTime: DateTime.utc(2026),
      text: 'PYG 10,000',
    );
    expect(extractor.extract(foreign), isNull);
    expect(extractor.extract(envelope(text: null)), isNull);
  });

  test('misma clave y contenido es duplicado; actualización reemplaza', () {
    final event = envelope();
    final hash = sha256.convert(event.combinedText.codeUnits).toString();
    expect(
      deduplicator
          .decide(
            incoming: event,
            incomingContentHash: hash,
            existingNotificationKey: event.notificationKey,
            existingContentHash: hash,
          )
          .action,
      DedupAction.exactDuplicate,
    );
    expect(
      deduplicator
          .decide(
            incoming: envelope(update: true, text: 'PYG150,000 · ••5962'),
            incomingContentHash: 'new',
            existingNotificationKey: event.notificationKey,
            existingContentHash: hash,
          )
          .action,
      DedupAction.updateExisting,
    );
  });

  test('dos compras legítimas con claves distintas se conservan', () {
    final first = extractor.extract(envelope(key: 'one'))!;
    final second = extractor.extract(envelope(key: 'two'))!;
    expect(first.fingerprint, isNot(second.fingerprint));
    expect(
      deduplicator
          .decide(
            incoming: envelope(key: 'two'),
            incomingContentHash: 'same-content',
            existingNotificationKey: 'one',
            existingContentHash: 'same-content',
          )
          .action,
      DedupAction.create,
    );
  });

  test('normaliza sufijos variables de Spotify sin regla amplia', () {
    expect(normalizeMerchant('Spotify P44819C280 S'), 'SPOTIFY');
    expect(normalizeMerchant('Spotify Premium'), 'SPOTIFY PREMIUM');
  });
}

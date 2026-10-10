import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/notifications/notification_envelope.dart';
import 'package:finanzas_locales/core/notifications/notification_ingestion_service.dart';
import 'package:finanzas_locales/core/settings/settings_repository.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late NotificationIngestionService service;
  late String cardId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    final settings = SettingsRepository(database);
    await settings.write('diagnostic_mode', 'false');
    cardId = await AccountsService(database).createAccount(
      const CreateAccountDraft(
        name: 'Tarjeta',
        type: AccountType.creditCard,
        aliases: ['5962'],
        creditLimitMinor: 1000000,
        includeInAvailableMoney: false,
      ),
    );
    service = NotificationIngestionService(
      database,
      LedgerService(database),
      settings: settings,
    );
  });

  tearDown(() => database.close());

  test(
    'ignorar conserva propuesta y evento sin crear movimiento ni reproponerla',
    () async {
      final captured = event();
      final candidate = (await service.ingest(captured))!;
      await service.ignore(candidate.id);
      expect(await service.watchPending().first, isEmpty);
      expect(
        (await database.select(database.paymentCandidates).get()).single.status,
        'ignored',
      );
      expect(
        await database.select(database.notificationEvents).get(),
        hasLength(1),
      );
      expect(await database.select(database.ledgerTransactions).get(), isEmpty);
      await service.ingest(captured);
      expect(await service.watchPending().first, isEmpty);
    },
  );

  test(
    'limpieza de diagnóstico conserva propuestas y claves foráneas',
    () async {
      await SettingsRepository(database).write('diagnostic_mode', 'true');
      final candidate = (await service.ingest(event()))!;
      await (database.update(
        database.notificationEvents,
      )..where((row) => row.id.equals(candidate.eventId))).write(
        NotificationEventsCompanion(
          title: const Value('Diagnóstico retenido'),
          notificationText: const Value('Contenido de prueba'),
          expiresAt: Value(
            DateTime.now().toUtc().subtract(const Duration(days: 1)),
          ),
        ),
      );
      expect(await service.purgeExpiredRawEvents(), 1);
      final retained =
          (await database.select(database.notificationEvents).get()).single;
      expect(retained.notificationText, isNull);
      expect(retained.title, isNull);
      expect(await service.watchPending().first, hasLength(1));
      expect(await service.purgeExpiredRawEvents(), 0);
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );

  test(
    'confirmar aprende el alias en la cuenta elegida una sola vez',
    () async {
      final candidate = (await service.ingest(
        event(text: 'PYG 15000 · ••9999'),
      ))!;
      expect(candidate.suggestedAccountId, isNull);
      await service.confirm(candidate, fromAccountId: cardId);
      final next = event(key: 'another-purchase', text: 'PYG 16000 · ••9999');
      expect((await service.preview(next))!.suggestedAccountId, cardId);
      await service.confirm(
        (await service.ingest(next))!,
        fromAccountId: cardId,
      );
      final aliases = await database.select(database.accountAliases).get();
      expect(aliases.where((a) => a.normalizedAlias == '9999'), hasLength(1));
      await expectLater(
        service.confirm(candidate, fromAccountId: cardId),
        throwsStateError,
      );
      expect(
        await database.select(database.ledgerTransactions).get(),
        hasLength(2),
      );
    },
  );

  test(
    'alias manual equivalente no se vuelve a insertar al confirmar',
    () async {
      await service.confirm(
        (await service.ingest(event()))!,
        fromAccountId: cardId,
      );
      expect(
        await database.select(database.accountAliases).get(),
        hasLength(1),
      );
    },
  );

  test('confirmación fallida no guarda alias', () async {
    final candidate = (await service.ingest(
      event(text: 'PYG 15000 · ••9999'),
    ))!;
    await expectLater(
      service.confirm(candidate, fromAccountId: 'missing'),
      throwsA(anything),
    );
    expect(await database.select(database.accountAliases).get(), hasLength(1));
    expect(await database.select(database.ledgerTransactions).get(), isEmpty);
  });

  test(
    'crea pendiente, no duplica evento idéntico y no retiene crudo por defecto',
    () async {
      final first = await service.ingest(event());
      final duplicate = await service.ingest(event());
      expect(first, isNotNull);
      expect(duplicate, isNull);
      expect(
        await database.select(database.paymentCandidates).get(),
        hasLength(1),
      );
      final storedEvent = await database
          .select(database.notificationEvents)
          .getSingle();
      expect(storedEvent.notificationText, isNull);
      expect(storedEvent.title, isNull);
      expect(
        await database.select(database.dedupDecisions).get(),
        hasLength(2),
      );
    },
  );

  test(
    'confirmar candidato crea gasto de tarjeta exactamente una vez',
    () async {
      final candidate = await service.ingest(event()) as PaymentCandidateRecord;
      await service.confirm(candidate, accountId: cardId);
      final transactions = await database
          .select(database.ledgerTransactions)
          .get();
      expect(transactions, hasLength(1));
      expect(transactions.single.type, 'expense');
      expect(transactions.single.paymentChannel, 'googleWalletContactless');
      final posting = await database
          .select(database.accountPostings)
          .getSingle();
      expect(posting.deltaMinor, 145500);
      final savedCandidate = await database
          .select(database.paymentCandidates)
          .getSingle();
      expect(savedCandidate.status, 'confirmed');
    },
  );

  test(
    'inspección sin escrituras y coincidencia solo con cuenta activa única',
    () async {
      expect((await service.preview(event()))!.suggestedAccountId, cardId);
      expect(await database.select(database.notificationEvents).get(), isEmpty);
      expect(await database.select(database.paymentCandidates).get(), isEmpty);
      expect(await database.select(database.ledgerTransactions).get(), isEmpty);
      await AccountsService(database).createAccount(
        const CreateAccountDraft(
          name: 'Otra tarjeta',
          type: AccountType.creditCard,
          aliases: ['5962'],
          creditLimitMinor: 1000000,
        ),
      );
      expect((await service.preview(event()))!.suggestedAccountId, isNull);
      await database.customStatement('UPDATE accounts SET is_archived = 1');
      expect((await service.preview(event()))!.suggestedAccountId, isNull);
    },
  );

  test('sin coincidencia exige cuenta y no elige la primera tarjeta', () async {
    final candidate = (await service.ingest(
      event(text: 'PYG 15000 · ••9999'),
    ))!;
    expect(candidate.suggestedAccountId, isNull);
    await expectLater(service.confirm(candidate), throwsA(anything));
    expect(await database.select(database.ledgerTransactions).get(), isEmpty);
    await service.confirm(candidate, fromAccountId: cardId);
    expect(
      await database.select(database.ledgerTransactions).get(),
      hasLength(1),
    );
  });

  test('releer una actualización conserva una sola propuesta', () async {
    final first = (await service.ingest(event()))!;
    final updated = (await service.ingest(event(text: 'PYG 150000 · ••5962')))!;
    expect(updated.id, first.id);
    expect(await service.ingest(event(text: 'PYG 150000 · ••5962')), isNull);
    expect(
      await database.select(database.paymentCandidates).get(),
      hasLength(1),
    );
    expect(await database.select(database.ledgerTransactions).get(), isEmpty);
  });

  test(
    'releer contenido anterior no falla ni modifica la propuesta actual',
    () async {
      final first = (await service.ingest(event()))!;
      final updated = (await service.ingest(
        event(text: 'PYG 150000 · ••5962'),
      ))!;
      await service.ignore(updated.id);

      expect(await service.ingest(event()), isNull);

      final retained = await database
          .select(database.paymentCandidates)
          .getSingle();
      expect(retained.id, first.id);
      expect(retained.eventId, updated.eventId);
      expect(retained.amountMinor, updated.amountMinor);
      expect(retained.status, 'ignored');
      expect(
        await database.select(database.notificationEvents).get(),
        hasLength(2),
      );
      expect(await database.select(database.ledgerTransactions).get(), isEmpty);
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );

  test('consulta manual y cola simultáneas no crean dos propuestas', () async {
    await Future.wait([service.ingest(event()), service.ingest(event())]);
    expect(
      await database.select(database.paymentCandidates).get(),
      hasLength(1),
    );
  });
}

NotificationEnvelope event({
  String key = 'wallet-key',
  String text = 'PYG145,500 · ••5962',
}) => NotificationEnvelope(
  version: 1,
  packageName: 'com.google.android.gms',
  notificationKey: key,
  id: 42,
  postTime: DateTime.utc(2026, 7, 18, 12),
  title: 'ECOP OBLIGADO',
  text: text,
);

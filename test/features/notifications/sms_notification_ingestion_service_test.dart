import 'package:drift/native.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/notifications/notification_envelope.dart';
import 'package:finanzas_locales/core/notifications/notification_ingestion_service.dart';
import 'package:finanzas_locales/core/notifications/sms_notification_ingestion_service.dart';
import 'package:finanzas_locales/core/settings/settings_repository.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late SettingsRepository settings;
  late SmsNotificationIngestionService sms;
  late NotificationIngestionService candidates;
  late String bankId;
  late String cardId;

  setUp(() async {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    settings = SettingsRepository(database);
    await settings.write('sms_notifications_enabled', 'true');
    await settings.write('diagnostic_mode', 'false');
    final accounts = AccountsService(database);
    bankId = await accounts.createAccount(
      const CreateAccountDraft(
        name: 'Sudameris principal',
        type: AccountType.bank,
        aliases: ['9647', '647000'],
      ),
    );
    cardId = await accounts.createAccount(
      const CreateAccountDraft(
        name: 'Tarjeta Sudameris',
        type: AccountType.creditCard,
        aliases: ['5962'],
        creditLimitMinor: 5000000,
      ),
    );
    final ledger = LedgerService(database);
    sms = SmsNotificationIngestionService(database, accounts, settings);
    candidates = NotificationIngestionService(
      database,
      ledger,
      settings: settings,
    );
  });

  tearDown(() => database.close());

  NotificationEnvelope message(String text, {String key = 'sms-1'}) =>
      NotificationEnvelope(
        version: 1,
        packageName: SmsNotificationIngestionService.googleMessagesPackage,
        notificationKey: key,
        id: 1,
        postTime: DateTime.utc(2026, 7, 6, 11, 16, 34),
        title: 'SUDAMERIS',
        text: text,
      );

  test('salario crea ingreso pendiente y se confirma en la cuenta resuelta', () async {
    final candidate = await sms.ingest(
      message(
        'Movimiento de Crédito, Salario s/instrucion, Caja de Ahorros ***9647, '
        'PYG 3,688,653.00, 06/07/26 11:16:34',
      ),
    );
    expect(candidate, isNotNull);
    expect(candidate!.transactionType, 'income');
    expect(candidate.suggestedToAccountId, bankId);
    await candidates.confirm(candidate);
    final transaction = await database
        .select(database.ledgerTransactions)
        .getSingle();
    expect(transaction.type, 'income');
    expect(transaction.toAccountId, bankId);
    expect(transaction.source, 'smsNotification');
  });

  test(
    'pago mínimo actualiza perfil y no crea candidato ni movimiento',
    () async {
      final candidate = await sms.ingest(
        message(
          'el Pago Minimo de su MASTERCARD CLASICA ****5962 es de '
          'PYG 1,603,000.00 con vto. de pago el: 03/02/26',
        ),
      );
      expect(candidate, isNull);
      final profile = await (database.select(
        database.creditCardProfiles,
      )..where((table) => table.accountId.equals(cardId))).getSingle();
      expect(profile.minimumPaymentMinor, 1603000);
      expect(await database.select(database.ledgerTransactions).get(), isEmpty);
    },
  );

  test('transferencia sin contraparte queda pendiente de completar', () async {
    final candidate = await sms.ingest(
      message(
        'SUDAMERIS Informa: Transferencia SPI Saliente, Caja de Ahorros ***9647, '
        'PYG 190,000, 06/07/26 11:16:34',
      ),
    );
    expect(candidate!.transactionType, 'transfer');
    expect(candidate.suggestedFromAccountId, bankId);
    expect(candidate.suggestedToAccountId, isNull);
    expect(candidate.requiresCounterparty, isTrue);
  });

  test('OTP no deja evento ni candidato', () async {
    expect(
      await sms.ingest(message('Tu código OTP es 123456. No compartas.')),
      isNull,
    );
    expect(await database.select(database.notificationEvents).get(), isEmpty);
    expect(await database.select(database.paymentCandidates).get(), isEmpty);
  });
}

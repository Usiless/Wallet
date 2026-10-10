import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../security/device_crypto.dart';
import 'encrypted_storage.dart';

part 'app_database.g.dart';

@DataClassName('AccountRecord')
class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 120)();
  TextColumn get type => text()();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();
  IntColumn get initialBalanceMinor =>
      integer().withDefault(const Constant(0))();
  IntColumn get color => integer().withDefault(const Constant(0xFF175C4C))();
  TextColumn get icon =>
      text().withDefault(const Constant('account_balance'))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  BoolColumn get includeInNetWorth =>
      boolean().withDefault(const Constant(true))();
  BoolColumn get includeInAvailableMoney =>
      boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AccountAliasRecord')
class AccountAliases extends Table {
  TextColumn get id => text()();
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get alias => text().withLength(min: 1, max: 120)();
  TextColumn get normalizedAlias => text().withLength(min: 1, max: 120)();
  TextColumn get source => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {accountId, normalizedAlias, source},
  ];
}

@DataClassName('CreditCardProfileRecord')
class CreditCardProfiles extends Table {
  TextColumn get accountId =>
      text().references(Accounts, #id, onDelete: KeyAction.cascade)();
  IntColumn get creditLimitMinor => integer()();
  IntColumn get closingDay => integer()();
  IntColumn get dueDay => integer()();
  IntColumn get minimumPaymentMinor => integer().nullable()();
  DateTimeColumn get minimumPaymentDueDate => dateTime().nullable()();
  IntColumn get lastStatementAmountMinor => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {accountId};
}

@DataClassName('CategoryRecord')
class Categories extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get parentId => text().nullable().references(Categories, #id)();
  TextColumn get kind => text()();
  TextColumn get icon => text().withDefault(const Constant('category'))();
  IntColumn get color => integer().withDefault(const Constant(0xFF39796B))();
  BoolColumn get isSystem => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('MerchantRecord')
class Merchants extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 160)();
  TextColumn get normalizedName => text().unique()();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('MerchantAliasRecord')
class MerchantAliases extends Table {
  TextColumn get id => text()();
  TextColumn get merchantId =>
      text().references(Merchants, #id, onDelete: KeyAction.cascade)();
  TextColumn get alias => text()();
  TextColumn get normalizedAlias => text().unique()();
  TextColumn get source => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TransactionRecord')
class LedgerTransactions extends Table {
  @override
  String get tableName => 'transactions';

  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get status => text()();
  TextColumn get source => text()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get occurredTimeZone =>
      text().withDefault(const Constant('America/Asuncion'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();
  IntColumn get amountMinor => integer()();
  @ReferenceName('transactionsFromAccount')
  TextColumn get fromAccountId => text().nullable().references(Accounts, #id)();
  @ReferenceName('transactionsToAccount')
  TextColumn get toAccountId => text().nullable().references(Accounts, #id)();
  TextColumn get merchantId => text().nullable().references(Merchants, #id)();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get note => text().withDefault(const Constant(''))();
  TextColumn get paymentChannel =>
      text().withDefault(const Constant('other'))();
  TextColumn get externalFingerprint => text().nullable()();
  TextColumn get sourceReference => text().nullable()();
  TextColumn get importBatchId =>
      text().nullable().references(ImportBatches, #id)();
  TextColumn get parentTransactionId =>
      text().nullable().references(LedgerTransactions, #id)();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AccountPostingRecord')
class AccountPostings extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId =>
      text().references(LedgerTransactions, #id, onDelete: KeyAction.cascade)();
  TextColumn get accountId => text().references(Accounts, #id)();
  IntColumn get deltaMinor => integer()();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();
  DateTimeColumn get occurredAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {transactionId, accountId},
  ];
}

@DataClassName('TransactionSplitRecord')
class TransactionSplits extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId =>
      text().references(LedgerTransactions, #id, onDelete: KeyAction.cascade)();
  TextColumn get categoryId => text().references(Categories, #id)();
  IntColumn get amountMinor => integer()();
  TextColumn get note => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('CategorizationRuleRecord')
class CategorizationRules extends Table {
  TextColumn get id => text()();
  IntColumn get priority => integer().withDefault(const Constant(100))();
  TextColumn get source => text().nullable()();
  TextColumn get accountId => text().nullable().references(Accounts, #id)();
  TextColumn get merchantId => text().nullable().references(Merchants, #id)();
  TextColumn get keyword => text().nullable()();
  TextColumn get transactionType => text().nullable()();
  TextColumn get categoryId => text().references(Categories, #id)();
  RealColumn get confidence => real().withDefault(const Constant(0.5))();
  BoolColumn get canAutoConfirm =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  IntColumn get confirmationCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('BudgetRecord')
class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get periodStart => dateTime()();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  IntColumn get targetMinor => integer()();
  TextColumn get currencyCode => text().withLength(min: 3, max: 3)();
  TextColumn get thresholds =>
      text().withDefault(const Constant('50,80,100'))();
  BoolColumn get rollover => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('InstallmentPlanRecord')
class InstallmentPlans extends Table {
  TextColumn get id => text()();
  TextColumn get transactionId => text().unique().references(
    LedgerTransactions,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get totalCommittedMinor => integer()();
  IntColumn get installmentCount => integer()();
  DateTimeColumn get firstPeriod => dateTime()();
  TextColumn get status => text().withDefault(const Constant('active'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('InstallmentEntryRecord')
class InstallmentEntries extends Table {
  TextColumn get id => text()();
  TextColumn get planId =>
      text().references(InstallmentPlans, #id, onDelete: KeyAction.cascade)();
  IntColumn get installmentNumber => integer()();
  DateTimeColumn get periodStart => dateTime()();
  IntColumn get amountMinor => integer()();
  TextColumn get status => text().withDefault(const Constant('scheduled'))();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {planId, installmentNumber},
  ];
}

@DataClassName('NotificationEventRecord')
class NotificationEvents extends Table {
  TextColumn get id => text()();
  IntColumn get envelopeVersion => integer().withDefault(const Constant(1))();
  TextColumn get packageName => text()();
  TextColumn get notificationKey => text()();
  IntColumn get notificationId => integer()();
  TextColumn get tag => text().nullable()();
  DateTimeColumn get postedAt => dateTime()();
  TextColumn get title => text().nullable()();
  TextColumn get notificationText => text().named('text').nullable()();
  TextColumn get bigText => text().nullable()();
  TextColumn get subText => text().nullable()();
  TextColumn get summaryText => text().nullable()();
  TextColumn get textLinesJson => text().withDefault(const Constant('[]'))();
  BoolColumn get isUpdate => boolean().withDefault(const Constant(false))();
  TextColumn get contentHash => text()();
  DateTimeColumn get expiresAt => dateTime()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {packageName, notificationKey, contentHash},
  ];
}

@DataClassName('PaymentCandidateRecord')
class PaymentCandidates extends Table {
  TextColumn get id => text()();
  TextColumn get eventId => text().references(NotificationEvents, #id)();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get transactionType =>
      text().withDefault(const Constant('expense'))();
  IntColumn get amountMinor => integer().nullable()();
  TextColumn get currencyCode => text().nullable()();
  TextColumn get rawMerchant => text().nullable()();
  TextColumn get normalizedMerchant => text().nullable()();
  TextColumn get suggestedAccountId =>
      text().nullable().references(Accounts, #id)();
  @ReferenceName('candidateFromAccount')
  TextColumn get suggestedFromAccountId =>
      text().nullable().references(Accounts, #id)();
  @ReferenceName('candidateToAccount')
  TextColumn get suggestedToAccountId =>
      text().nullable().references(Accounts, #id)();
  BoolColumn get requiresCounterparty =>
      boolean().withDefault(const Constant(false))();
  TextColumn get detectedAlias => text().nullable()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get source => text()();
  RealColumn get amountConfidence => real().withDefault(const Constant(0))();
  RealColumn get merchantConfidence => real().withDefault(const Constant(0))();
  RealColumn get accountConfidence => real().withDefault(const Constant(0))();
  RealColumn get overallConfidence => real().withDefault(const Constant(0))();
  TextColumn get suggestionReason => text().withDefault(const Constant(''))();
  TextColumn get fingerprintVersion =>
      text().withDefault(const Constant('v1'))();
  TextColumn get fingerprint => text().unique()();
  TextColumn get transactionId =>
      text().nullable().references(LedgerTransactions, #id)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('DedupDecisionRecord')
class DedupDecisions extends Table {
  TextColumn get id => text()();
  TextColumn get eventId => text().references(NotificationEvents, #id)();
  TextColumn get candidateId =>
      text().nullable().references(PaymentCandidates, #id)();
  TextColumn get decision => text()();
  TextColumn get reason => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ImportBatchRecord')
class ImportBatches extends Table {
  TextColumn get id => text()();
  TextColumn get fileName => text()();
  TextColumn get delimiter => text().withDefault(const Constant(';'))();
  TextColumn get status => text()();
  IntColumn get validRows => integer().withDefault(const Constant(0))();
  IntColumn get invalidRows => integer().withDefault(const Constant(0))();
  IntColumn get duplicateRows => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get importedAt => dateTime().nullable()();
  DateTimeColumn get revertedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ImportRowRecord')
class ImportRows extends Table {
  TextColumn get id => text()();
  TextColumn get batchId =>
      text().references(ImportBatches, #id, onDelete: KeyAction.cascade)();
  IntColumn get rowNumber => integer()();
  TextColumn get originalJson => text()();
  TextColumn get status => text()();
  TextColumn get errorsJson => text().withDefault(const Constant('[]'))();
  TextColumn get fingerprint => text().nullable()();
  TextColumn get transactionId =>
      text().nullable().references(LedgerTransactions, #id)();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {batchId, rowNumber},
  ];
}

@DataClassName('RecurringTemplateRecord')
class RecurringTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get transactionType => text()();
  IntColumn get amountMinor => integer().nullable()();
  @ReferenceName('templatesFromAccount')
  TextColumn get fromAccountId => text().nullable().references(Accounts, #id)();
  @ReferenceName('templatesToAccount')
  TextColumn get toAccountId => text().nullable().references(Accounts, #id)();
  TextColumn get categoryId => text().nullable().references(Categories, #id)();
  TextColumn get schedule => text().nullable()();
  DateTimeColumn get nextDueAt => dateTime().nullable()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('AuditLogRecord')
class AuditLogs extends Table {
  TextColumn get id => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get action => text()();
  TextColumn get changesJson => text().withDefault(const Constant('{}'))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('SettingRecord')
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Accounts,
    AccountAliases,
    CreditCardProfiles,
    Categories,
    Merchants,
    MerchantAliases,
    LedgerTransactions,
    AccountPostings,
    TransactionSplits,
    CategorizationRules,
    Budgets,
    InstallmentPlans,
    InstallmentEntries,
    NotificationEvents,
    PaymentCandidates,
    DedupDecisions,
    ImportBatches,
    ImportRows,
    RecurringTemplates,
    AuditLogs,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  AppDatabase.forTesting(super.executor);

  // Session epoch: stale forms cannot write into a replaced book. An aborted
  // restore conservatively invalidates forms too, without changing persisted data.
  int restoreGeneration = 0;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _createIndexes();
    },
    onUpgrade: (migrator, from, to) async {
      // Schema v1 is the first published schema. Future upgrades belong
      // here as explicit, forward-only migrations. Never delete the DB.
      if (from < 1) {
        await migrator.createAll();
        await _createIndexes();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  Future<void> _createIndexes() async {
    const statements = [
      'CREATE INDEX IF NOT EXISTS idx_transactions_occurred_at ON transactions(occurred_at)',
      'CREATE INDEX IF NOT EXISTS idx_transactions_status ON transactions(status)',
      'CREATE INDEX IF NOT EXISTS idx_transactions_source_reference ON transactions(source_reference)',
      'CREATE INDEX IF NOT EXISTS idx_postings_account_time ON account_postings(account_id, occurred_at)',
      'CREATE INDEX IF NOT EXISTS idx_splits_category ON transaction_splits(category_id)',
      'CREATE INDEX IF NOT EXISTS idx_candidates_status ON payment_candidates(status)',
      'CREATE INDEX IF NOT EXISTS idx_import_rows_batch ON import_rows(batch_id)',
      'CREATE INDEX IF NOT EXISTS idx_audit_entity ON audit_logs(entity_type, entity_id)',
    ];
    for (final statement in statements) {
      await customStatement(statement);
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final databaseFile = await activeDatabaseFile();
    final key = await DeviceCrypto.databaseKey();
    return NativeDatabase.createInBackground(
      databaseFile,
      isolateSetup: () {
        migratePlaintextDatabase(databaseFile.path, key);
        final legacyPattern = RegExp(
          r'^(.*\.before-restore-\d+)(?:\.migration-(?:original|encrypted))?$',
        );
        final paths = <String>{};
        for (final entry in databaseFile.parent.listSync(followLinks: false)) {
          if (entry is File &&
              entry.path.startsWith('${databaseFile.path}.before-restore-')) {
            final match = legacyPattern.firstMatch(entry.path);
            if (match != null) paths.add(match.group(1)!);
          }
        }
        for (final path in paths) {
          migratePlaintextDatabase(path, key);
        }
      },
      setup: (database) {
        requireCipher(database);
        database.execute("PRAGMA key = '${sqlString(key)}'");
        database.execute('PRAGMA journal_mode = WAL');
        database.execute('PRAGMA foreign_keys = ON');
        database.execute('PRAGMA busy_timeout = 5000');
      },
    );
  });
}

Future<File> activeDatabaseFile() async {
  final directory = await getApplicationSupportDirectory();
  return File(p.join(directory.path, 'finanzas_locales.sqlite'));
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/backup/backup_service.dart';
import '../core/database/app_database.dart';
import '../core/notifications/native_notification_bridge.dart';
import '../core/notifications/payment_reminder_bridge.dart';
import '../features/payments/domain/pending_payment_service.dart';
import '../core/notifications/notification_ingestion_service.dart';
import '../core/notifications/sms_notification_ingestion_service.dart';
import '../core/settings/settings_repository.dart';
import '../features/accounts/data/accounts_service.dart';
import '../features/budgets/domain/budget_service.dart';
import '../features/installments/domain/installment_service.dart';
import '../features/merchants/merchant_service.dart';
import '../features/templates/manual_template_service.dart';
import '../features/templates/scheduled_template_service.dart';
import '../features/onboarding/data/onboarding_service.dart';
import '../features/transactions/data/category_service.dart';
import '../features/transactions/data/ledger_repository.dart';
import '../features/transactions/data/ledger_service.dart';
import '../features/transactions/data/transaction_form_service.dart';
import '../features/transactions/domain/ledger_models.dart';
import '../features/updater/data/apk_installer.dart';
import '../features/updater/data/update_service.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  throw StateError('databaseProvider debe configurarse en main().');
});

final pendingPaymentServiceProvider = Provider(
  (ref) => PendingPaymentService(ref.watch(databaseProvider)),
);
final pendingPaymentsProvider = StreamProvider<List<PendingPayment>>(
  (ref) => ref.watch(pendingPaymentServiceProvider).watch(),
);
final paymentReminderBridgeProvider = Provider(
  (ref) => const PaymentReminderBridge(),
);

final settingsProvider = Provider(
  (ref) => SettingsRepository(ref.watch(databaseProvider)),
);
final manualTemplateServiceProvider = Provider(
  (ref) => ManualTemplateService(ref.watch(databaseProvider)),
);
final scheduledTemplateServiceProvider = Provider(
  (ref) => ScheduledTemplateService(ref.watch(databaseProvider)),
);
final manualTemplatesProvider = StreamProvider(
  (ref) => ref.watch(manualTemplateServiceProvider).watch(),
);
final accountsServiceProvider = Provider(
  (ref) => AccountsService(ref.watch(databaseProvider)),
);
final categoryServiceProvider = Provider(
  (ref) => CategoryService(ref.watch(databaseProvider)),
);
final merchantServiceProvider = Provider(
  (ref) => MerchantService(ref.watch(databaseProvider)),
);
final merchantsProvider = StreamProvider<List<MerchantRecord>>(
  (ref) => ref.watch(merchantServiceProvider).watchMerchants(),
);
final merchantAliasesProvider = StreamProvider<List<MerchantAliasRecord>>(
  (ref) => ref.watch(merchantServiceProvider).watchAliases(),
);
final ledgerServiceProvider = Provider(
  (ref) => LedgerService(ref.watch(databaseProvider)),
);
final ledgerRepositoryProvider = Provider(
  (ref) => LedgerRepository(ref.watch(databaseProvider)),
);
final transactionFormServiceProvider = Provider(
  (ref) => TransactionFormService(
    database: ref.watch(databaseProvider),
    ledger: ref.watch(ledgerServiceProvider),
    installmentService: ref.watch(installmentServiceProvider),
    merchants: ref.watch(merchantServiceProvider),
    categories: ref.watch(categoryServiceProvider),
    pendingPayments: ref.watch(pendingPaymentServiceProvider),
    templates: ref.watch(manualTemplateServiceProvider),
    scheduledTemplates: ref.watch(scheduledTemplateServiceProvider),
    settings: ref.watch(settingsProvider),
  ),
);
final installmentServiceProvider = Provider(
  (ref) => InstallmentService(ref.watch(databaseProvider)),
);
final budgetServiceProvider = Provider(
  (ref) => BudgetService(ref.watch(databaseProvider)),
);
final onboardingServiceProvider = Provider(
  (ref) => OnboardingService(
    ref.watch(databaseProvider),
    ref.watch(accountsServiceProvider),
    ref.watch(settingsProvider),
  ),
);
final backupServiceProvider = Provider(
  (ref) => BackupService(ref.watch(databaseProvider)),
);
final updateServiceProvider = Provider((ref) {
  final service = UpdateService(settings: ref.watch(settingsProvider));
  ref.onDispose(service.close);
  return service;
});
final apkInstallerProvider = Provider((ref) => const ApkInstaller());
final nativeNotificationBridgeProvider = Provider(
  (ref) => const NativeNotificationBridge(),
);
final notificationIngestionProvider = Provider(
  (ref) => NotificationIngestionService(
    ref.watch(databaseProvider),
    ref.watch(ledgerServiceProvider),
    settings: ref.watch(settingsProvider),
  ),
);
final smsNotificationIngestionProvider = Provider(
  (ref) => SmsNotificationIngestionService(
    ref.watch(databaseProvider),
    ref.watch(accountsServiceProvider),
    ref.watch(settingsProvider),
  ),
);

final onboardingCompleteProvider = StreamProvider<bool>((ref) {
  return ref
      .watch(settingsProvider)
      .watch('onboarding_complete')
      .map((value) => value == 'true');
});
final accountsProvider = StreamProvider<List<AccountRecord>>((ref) {
  return ref.watch(accountsServiceProvider).watchAccounts();
});
final categoriesProvider = StreamProvider<List<CategoryRecord>>((ref) {
  return ref.watch(categoryServiceProvider).watchCategories();
});
final accountBalancesProvider = StreamProvider<List<AccountBalance>>((ref) {
  return ref.watch(ledgerRepositoryProvider).watchAccountBalances();
});
final pendingCandidatesProvider = StreamProvider<List<PaymentCandidateRecord>>((
  ref,
) {
  return ref.watch(notificationIngestionProvider).watchPending();
});

final creditCardProfileProvider = StreamProvider.autoDispose
    .family<CreditCardProfileRecord?, String>(
      (ref, accountId) =>
          ref.watch(accountsServiceProvider).watchCreditCardProfile(accountId),
    );

final accountAliasesProvider = StreamProvider.autoDispose
    .family<List<AccountAliasRecord>, String>(
      (ref, accountId) =>
          ref.watch(accountsServiceProvider).watchAliasesOf(accountId),
    );

final allAccountsProvider = StreamProvider<List<AccountRecord>>(
  (ref) =>
      ref.watch(accountsServiceProvider).watchAccounts(includeArchived: true),
);

final allCategoriesProvider = StreamProvider<List<CategoryRecord>>(
  (ref) =>
      ref.watch(categoryServiceProvider).watchCategories(includeArchived: true),
);

final movementHistoryProvider = StreamProvider.autoDispose
    .family<
      List<MovementRow>,
      ({
        HistoryFilter filter,
        int limit,
        bool unclassified,
        bool reportOnly,
        bool withoutMerchant,
      })
    >(
      (ref, r) => ref
          .watch(ledgerRepositoryProvider)
          .watchMovements(
            filter: r.filter,
            limit: r.limit,
            unclassifiedOnly: r.unclassified,
            reportOnly: r.reportOnly,
            withoutMerchant: r.withoutMerchant,
          ),
    );

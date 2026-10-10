import '../../accounts/data/accounts_service.dart';

final class OnboardingConfig {
  const OnboardingConfig({
    this.currencyCode = 'PYG',
    this.accounts = const [],
    this.enableAppLock = false,
  });

  final String currencyCode;
  final List<CreateAccountDraft> accounts;
  final bool enableAppLock;
}

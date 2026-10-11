import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/accounts/presentation/accounts_screen.dart';
import '../features/reports/presentation/analysis_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/pending_inbox/presentation/pending_inbox_screen.dart';
import '../features/payments/presentation/payments_screen.dart';
import '../features/payments/presentation/payment_detail_screen.dart';
import '../features/developer_tools/presentation/developer_tools_screen.dart';
import '../features/developer_tools/presentation/active_notifications_screen.dart';
import '../features/developer_tools/presentation/notification_diagnostics_screen.dart';
import '../core/config/feature_flags.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/settings/presentation/wallet_settings_screen.dart';
import '../features/developer_tools/presentation/notification_simulator_screen.dart';
import '../features/transactions/domain/ledger_models.dart';
import '../features/transactions/presentation/transaction_form_screen.dart';
import '../features/transactions/presentation/transactions_screen.dart';
import '../features/templates/templates_screen.dart';
import '../features/catalog/catalog_screen.dart';
import '../shared/widgets/async_value_view.dart';
import '../shared/widgets/pending_count_badge.dart';
import 'providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/start',
    redirect: (context, state) =>
        state.uri.scheme == 'cabal-reminder' ? '/start' : null,
    routes: [
      GoRoute(
        path: '/start',
        builder: (context, state) => const _StartScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/transactions', builder: transactionsRouteBuilder),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/accounts',
                builder: (context, state) => AccountsScreen(
                  accountId: state.uri.queryParameters['account'],
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/analysis',
                builder: (context, state) => AnalysisScreen(
                  reports: state.uri.queryParameters['view'] == 'reports',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/budgets', redirect: (context, state) => '/analysis'),
      GoRoute(
        path: '/payments',
        builder: (context, state) => const PaymentsScreen(),
      ),
      GoRoute(
        path: '/payments/:id',
        builder: (context, state) =>
            PaymentDetailScreen(paymentId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: '/transactions/new',
        builder: (context, state) => TransactionFormScreen(
          initialType: _parseType(state.uri.queryParameters['type']),
          template: state.uri.queryParameters['template'],
          cloneId: state.uri.queryParameters['clone'],
          editId: state.uri.queryParameters['edit'],
          toAccountId: state.uri.queryParameters['to'],
          savedTemplateId: state.uri.queryParameters['savedTemplate'],
          editTemplate: state.uri.queryParameters['editTemplate'] == 'true',
        ),
      ),
      GoRoute(
        path: '/backups',
        builder: (context, state) => const SettingsScreen(backups: true),
      ),
      GoRoute(
        path: '/wallet-settings',
        builder: (context, state) => const WalletSettingsScreen(),
      ),
      GoRoute(
        path: '/catalog',
        builder: (context, state) => const CatalogScreen(),
      ),
      GoRoute(
        path: '/templates',
        builder: (context, state) => TemplatesScreen(
          scheduledOnly: state.uri.queryParameters['scheduled'] == 'true',
        ),
      ),
      GoRoute(
        path: '/inbox',
        builder: (context, state) => const PendingInboxScreen(),
      ),
      GoRoute(
        path: '/reports',
        redirect: (context, state) => '/analysis?view=reports',
      ),
      if (developerToolsEnabled) ...[
        GoRoute(
          path: '/developer-tools/simulator',
          builder: (context, state) => const NotificationSimulatorScreen(),
        ),
        GoRoute(
          path: '/developer-tools/active-notifications',
          builder: (context, state) => const ActiveNotificationsScreen(),
        ),
        GoRoute(
          path: '/developer-tools',
          builder: (context, state) => const DeveloperToolsScreen(),
        ),
        GoRoute(
          path: '/developer-tools/notifications',
          builder: (context, state) => const NotificationDiagnosticsScreen(),
        ),
      ],
    ],
  );
});

TransactionType _parseType(String? value) {
  if (value == null) return TransactionType.expense;
  return TransactionType.values
          .where((type) => type.name == value)
          .firstOrNull ??
      TransactionType.expense;
}

final class _StartScreen extends ConsumerWidget {
  const _StartScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncValueView(
      value: ref.watch(onboardingCompleteProvider),
      data: (complete) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            context.go(complete ? '/dashboard' : '/onboarding');
          }
        });
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}

final class _AppShell extends StatelessWidget {
  const _AppShell({required this.shell});
  final StatefulNavigationShell shell;
  static const destinations = [
    NavigationDestination(
      icon: PendingCountBadge(
        showCount: false,
        child: Icon(Icons.home_outlined),
      ),
      label: 'Inicio',
    ),
    NavigationDestination(
      icon: Icon(Icons.receipt_long_outlined),
      label: 'Movimientos',
    ),
    NavigationDestination(
      icon: Icon(Icons.account_balance_wallet_outlined),
      label: 'Cuentas',
    ),
    NavigationDestination(
      icon: Icon(Icons.bar_chart_outlined),
      label: 'Análisis',
    ),
    NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Más'),
  ];
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      if (c.maxWidth >= 840) {
        return Scaffold(
          body: SafeArea(
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: shell.currentIndex,
                  onDestinationSelected: (i) => shell.goBranch(i),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    for (final d in destinations)
                      NavigationRailDestination(
                        icon: d.icon,
                        label: Text(d.label),
                      ),
                  ],
                ),
                Expanded(child: shell),
              ],
            ),
          ),
        );
      }
      return Scaffold(
        body: SafeArea(bottom: false, child: shell),
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) => shell.goBranch(i),
          destinations: destinations,
        ),
      );
    },
  );
}

/// Movimientos filtrados por la URL. `link` (ver `openHistory`) es la clave:
/// cada atajo crea una pantalla nueva con sus filtros.
Widget transactionsRouteBuilder(BuildContext context, GoRouterState state) {
  final query = state.uri.queryParameters;
  return TransactionsScreen(
    key: ValueKey(query['link']),
    account: query['account'],
    merchant: query['merchant'],
    category: query['category'],
    type: query['type'],
    reportOnly: query['report'] == 'true',
    withoutMerchant: query['withoutMerchant'] == 'true',
    start: DateTime.tryParse(query['start'] ?? ''),
    end: DateTime.tryParse(query['end'] ?? ''),
    quotaPeriod: query['quotaPeriod'] == 'true',
    unclassified: query['unclassified'] == 'true',
  );
}

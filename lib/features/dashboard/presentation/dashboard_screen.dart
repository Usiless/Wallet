import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../shared/widgets/movement_fab.dart';
import '../../../shared/widgets/pending_count_badge.dart';
import '../../transactions/domain/ledger_models.dart';
import '../../payments/domain/pending_payment_models.dart';
import '../../../shared/widgets/inline_progress.dart';

final class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balances = ref.watch(accountBalancesProvider);
    final pendingCount =
        ref.watch(pendingCandidatesProvider).value?.length ?? 0;
    return Scaffold(
      floatingActionButton: const MovementFab(),
      body: SafeArea(
        child: AsyncValueView(
          value: balances,
          onRetry: () => ref.invalidate(accountBalancesProvider),
          data: (items) {
            final netWorth = items
                .where((item) => item.includeInNetWorth)
                .fold<int>(
                  0,
                  (sum, item) =>
                      sum +
                      (item.type == AccountType.creditCard
                          ? -item.balanceMinor
                          : item.balanceMinor),
                );
            final available = items
                .where(
                  (item) =>
                      item.includeInAvailableMoney &&
                      item.type != AccountType.creditCard,
                )
                .fold<int>(0, (sum, item) => sum + item.balanceMinor);
            final payments = ref.watch(pendingPaymentsProvider);
            final hasPaymentData = payments.hasValue;
            final stackPayments =
                MediaQuery.sizeOf(context).width < 360 ||
                MediaQuery.textScalerOf(context).scale(16) > 22;
            final open = <PendingPayment>[...payments.value ?? []]
              ..removeWhere((p) => p.cancelled || p.remainingMinor <= 0);
            open.sort((a, b) => a.dueDate.compareTo(b.dueDate));
            final now = DateTime.now();
            final monthPending = open
                .where(
                  (p) =>
                      p.dueDate.year == now.year &&
                      p.dueDate.month == now.month,
                )
                .fold<int>(0, (sum, p) => sum + p.remainingMinor);
            final totalPending = open.fold<int>(
              0,
              (sum, p) => sum + p.remainingMinor,
            );
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              children: [
                _HeroBalance(
                  available: available,
                  inbox: IconButton(
                    tooltip: pendingCount > 0
                        ? 'Movimientos pendientes ($pendingCount)'
                        : 'Movimientos pendientes',
                    onPressed: () => context.push('/inbox'),
                    color: Colors.white,
                    icon: const PendingCountBadge(
                      child: Icon(Icons.inbox_outlined),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pendiente del mes'),
                  subtitle: _PaymentFigure(
                    payments: payments,
                    amount: hasPaymentData ? monthPending : null,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/payments'),
                ),
                ListTile(
                  key: const ValueKey('overview-net-worth'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Patrimonio total'),
                  subtitle: _PaymentFigure(
                    payments: payments,
                    amount: hasPaymentData ? netWorth - totalPending : null,
                  ),
                ),
                const SizedBox(height: 24),
                if (stackPayments)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Próximos pagos',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => context.push('/payments'),
                          child: const Text('Ver todos'),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Próximos pagos',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.push('/payments'),
                        child: const Text('Ver todos'),
                      ),
                    ],
                  ),
                if (payments.hasError)
                  const Text('No se pudieron cargar los pagos.'),
                if (payments.isLoading) const LinearProgressIndicator(),
                if (!payments.isLoading && !payments.hasError && open.isEmpty)
                  const Text('Sin pagos pendientes.'),
                for (final payment in open.take(2))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      payment.description.isEmpty
                          ? 'Pago'
                          : payment.description,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          MaterialLocalizations.of(context)
                              .formatShortDate(payment.dueDate),
                        ),
                        if (stackPayments) MoneyText(payment.remainingMinor),
                      ],
                    ),
                    trailing: stackPayments
                        ? null
                        : MoneyText(payment.remainingMinor),
                    onTap: () => context.push('/payments/${payment.id}'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Importe que depende de los pagos: indicador mientras carga, reintento si falla.
final class _PaymentFigure extends ConsumerWidget {
  const _PaymentFigure({required this.payments, required this.amount});

  final AsyncValue<List<PendingPayment>> payments;
  final int? amount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (payments.hasError) {
      return Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('No se pudo cargar.'),
          TextButton(
            onPressed: () => ref.invalidate(pendingPaymentsProvider),
            child: const Text('Reintentar'),
          ),
        ],
      );
    }
    final value = amount;
    if (value == null) {
      return const InlineProgress();
    }
    return MoneyText(value);
  }
}

final class _HeroBalance extends StatelessWidget {
  const _HeroBalance({required this.available, required this.inbox});
  final int available;
  final Widget inbox;
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('overview-available'),
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: const Color(0xFF143F35),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Stack(
      children: [
        Positioned(
          right: -38,
          top: -46,
          child: ExcludeSemantics(
            child: Container(
              width: 156,
              height: 156,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF214B40), width: 28),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Disponible',
                      style: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(color: const Color(0xFFB9D8CB)),
                    ),
                  ),
                  inbox,
                ],
              ),
              const SizedBox(height: 16),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: MoneyText(
                  available,
                  currencySymbol: '₲',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

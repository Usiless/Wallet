import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/money_text.dart';
import '../../transactions/domain/ledger_models.dart';
import '../domain/credit_card_cycle.dart';

final class CreditCardsScreen extends ConsumerWidget {
  const CreditCardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);
    final balances =
        ref.watch(accountBalancesProvider).value ?? const <AccountBalance>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Tarjetas de crédito')),
      body: AsyncValueView(
        value: accounts,
        data: (rows) {
          final cards = rows
              .where((row) => row.type == AccountType.creditCard.name)
              .toList();
          if (cards.isEmpty) {
            return const Center(
              child: Text('No hay tarjetas de crédito configuradas.'),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final card in cards)
                FutureBuilder<CreditCardProfileRecord?>(
                  future:
                      (ref
                              .read(databaseProvider)
                              .select(
                                ref.read(databaseProvider).creditCardProfiles,
                              )
                            ..where((table) => table.accountId.equals(card.id)))
                          .getSingleOrNull(),
                  builder: (context, snapshot) {
                    final profile = snapshot.data;
                    final debt =
                        balances
                            .where((item) => item.id == card.id)
                            .firstOrNull
                            ?.balanceMinor ??
                        0;
                    if (profile == null) return const LinearProgressIndicator();
                    final dates = const CreditCardCycleCalculator().nextDates(
                      localDate: DateTime.now(),
                      closingDay: profile.closingDay,
                      dueDay: profile.dueDay,
                    );
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.credit_card),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    card.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Text('Deuda registrada'),
                            MoneyText(
                              debt,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _Metric(
                                    label: 'Límite',
                                    value: profile.creditLimitMinor,
                                  ),
                                ),
                                Expanded(
                                  child: _Metric(
                                    label: 'Disponible',
                                    value: const CreditCardCycleCalculator()
                                        .availableCredit(
                                          creditLimitMinor:
                                              profile.creditLimitMinor,
                                          debtMinor: debt,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 32),
                            Text(
                              'Próximo cierre: ${dates.nextClosing.day}/${dates.nextClosing.month}',
                            ),
                            Text(
                              'Vencimiento estimado: ${dates.nextDue.day}/${dates.nextDue.month}',
                            ),
                            if (profile.minimumPaymentMinor != null) ...[
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Text('Pago mínimo: '),
                                  MoneyText(profile.minimumPaymentMinor!),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => context.push(
                                Uri(
                                  path: '/transactions/new',
                                  queryParameters: {
                                    'template': 'cardPayment',
                                    'to': card.id,
                                  },
                                ).toString(),
                              ),
                              icon: const Icon(Icons.payments_outlined),
                              label: const Text('Pagar tarjeta'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

final class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      MoneyText(value, style: Theme.of(context).textTheme.titleMedium),
    ],
  );
}

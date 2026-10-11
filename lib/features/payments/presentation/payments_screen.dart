import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../shared/widgets/async_value_view.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});
  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  String _filter = 'pending';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pagos pendientes')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(
            spacing: 8,
            children: [
              for (final entry in const {
                'pending': 'Pendientes',
                'paid': 'Con pagos',
                'all': 'Todos',
              }.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _filter == entry.key,
                  onSelected: (_) => setState(() => _filter = entry.key),
                ),
            ],
          ),
        ),
        Expanded(
          child: AsyncValueView(
            value: ref.watch(pendingPaymentsProvider),
            onRetry: () => ref.invalidate(pendingPaymentsProvider),
            data: (rows) {
              final payments = rows
                  .where(
                    (p) =>
                        _filter == 'all' ||
                        (_filter == 'paid'
                            ? p.paidMinor > 0
                            : !p.cancelled && p.remainingMinor > 0),
                  )
                  .toList();
              if (payments.isEmpty) {
                return Center(
                  child: Text(
                    _filter == 'pending'
                        ? 'Sin pagos pendientes'
                        : 'Sin pagos en esta vista',
                  ),
                );
              }
              return ListView.builder(
                itemCount: payments.length,
                itemBuilder: (context, i) {
                  final p = payments[i];
                  return ListTile(
                    title: Text(
                      p.description.isEmpty ? 'Pago pendiente' : p.description,
                    ),
                    subtitle: Text(
                      '${MaterialLocalizations.of(context).formatShortDate(p.dueDate)} · ${p.installmentNumber}/${p.installmentCount}\n${p.cancelled
                          ? 'Cancelado'
                          : p.remainingMinor <= 0
                          ? 'Pagado'
                          : Money(p.remainingMinor, currencyCode: 'PYG').format()}',
                    ),
                    onTap: () => context.push('/payments/${p.id}'),
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}

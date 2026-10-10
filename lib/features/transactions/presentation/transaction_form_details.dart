import 'package:flutter/material.dart';

import '../../../core/database/app_database.dart';
import '../../payments/presentation/payment_reminder_fields.dart';
import '../domain/ledger_models.dart';
import 'transaction_form_notifier.dart';
import 'transaction_form_state.dart';

/// «Más detalles»: cuándo se paga, cuotas, repetición, fecha, canal y nota.
final class TransactionFormDetails extends StatelessWidget {
  const TransactionFormDetails({
    required this.state,
    required this.accounts,
    required this.channels,
    required this.viewModel,
    required this.note,
    required this.onPickDate,
    super.key,
  });

  final TransactionFormState state;
  final List<AccountRecord> accounts;
  final List<PaymentChannel> channels;
  final TransactionFormNotifier viewModel;
  final TextEditingController note;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final open = state.advanced || state.payLater || state.installments;
    final credit = state.isCreditExpense(accounts);
    final installmentsOn = state.installmentsOn(accounts);
    final pendingOn = state.pendingOn(accounts);
    final when = state.installments
        ? 'installments'
        : state.payLater
        ? 'later'
        : 'now';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextButton.icon(
          onPressed: state.payLater || state.installments
              ? null
              : viewModel.toggleAdvanced,
          icon: Icon(open ? Icons.expand_less : Icons.tune),
          label: Text(open ? 'Ocultar detalles' : 'Más detalles'),
        ),
        if (open) ...[
          if (state.type == TransactionType.expense &&
              (!state.isEdit || credit))
            DropdownButtonFormField<String>(
              key: ValueKey(('when', credit, when)),
              isExpanded: true,
              initialValue: when,
              decoration: const InputDecoration(labelText: 'Cuándo'),
              items: [
                const DropdownMenuItem(value: 'now', child: Text('Ahora')),
                if (!credit)
                  const DropdownMenuItem(
                    value: 'later',
                    child: Text('Pagar después'),
                  ),
                const DropdownMenuItem(
                  value: 'installments',
                  child: Text('En cuotas'),
                ),
              ],
              onChanged: (value) => viewModel.setWhen(value ?? 'now'),
            ),
          if (installmentsOn)
            DropdownButtonFormField<int>(
              isExpanded: true,
              initialValue: state.installmentCount,
              decoration: const InputDecoration(
                labelText: 'Cantidad de cuotas',
              ),
              items: [
                for (var count = 2; count <= 120; count++)
                  DropdownMenuItem(
                    value: count,
                    child: Text(
                      '$count cuotas',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) => viewModel.setInstallmentCount(value ?? 2),
            ),
          if (pendingOn && !state.installments)
            DropdownButtonFormField<String?>(
              key: ValueKey(state.repeat),
              initialValue: state.repeat,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Repetir'),
              items: const [
                DropdownMenuItem(value: null, child: Text('No repetir')),
                DropdownMenuItem(value: 'monthly', child: Text('Mensual')),
                DropdownMenuItem(value: 'yearly', child: Text('Anual')),
              ],
              onChanged: viewModel.setRepeat,
            ),
          if ((installmentsOn || pendingOn) && !state.isTemplateEdit)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(installmentsOn ? 'Primera cuota' : 'Fecha de pago'),
              subtitle: Text(
                MaterialLocalizations.of(context).formatShortDate(
                  state.firstInstallmentDate ?? state.occurredAt,
                ),
              ),
              trailing: const Icon(Icons.calendar_month_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: state.firstInstallmentDate ?? state.occurredAt,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null && context.mounted) {
                  viewModel.setFirstInstallmentDate(picked);
                }
              },
            ),
          if (pendingOn)
            PaymentReminderFields(
              value: state.reminders,
              onChanged: viewModel.setReminders,
            ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today),
            title: const Text('Fecha'),
            subtitle: Text(
              '${state.occurredAt.day}/${state.occurredAt.month}/${state.occurredAt.year}',
            ),
            onTap: onPickDate,
          ),
          DropdownButtonFormField<PaymentChannel>(
            key: ValueKey(state.channel),
            initialValue: state.channel,
            decoration: const InputDecoration(labelText: 'Canal'),
            items: [
              for (final channel in channels)
                DropdownMenuItem(
                  value: channel,
                  child: Text(_channelLabel(channel)),
                ),
            ],
            onChanged: (value) => viewModel.setChannel(value ?? state.channel),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: note,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Nota'),
          ),
        ],
      ],
    );
  }

  String _channelLabel(PaymentChannel channel) => switch (channel) {
    PaymentChannel.cash => 'Efectivo',
    PaymentChannel.physicalCard => 'Tarjeta física',
    PaymentChannel.debitCard => 'Tarjeta de débito',
    PaymentChannel.physicalCreditCard => 'Tarjeta de crédito física',
    PaymentChannel.googleWalletContactless => 'Google Wallet',
    PaymentChannel.onlineCard => 'Pago online',
    PaymentChannel.bankTransfer => 'Transferencia',
    PaymentChannel.other => 'Otro',
  };
}

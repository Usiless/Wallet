import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/money/money.dart';
import '../../../core/money/pyg_input_formatter.dart';
import '../domain/pending_payment_models.dart';
import 'payment_reminder_fields.dart';

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
          child: ref
              .watch(pendingPaymentsProvider)
              .when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('$e')),
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
                          p.description.isEmpty
                              ? 'Pago pendiente'
                              : p.description,
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

class PaymentDetailScreen extends ConsumerStatefulWidget {
  const PaymentDetailScreen({required this.paymentId, super.key});
  final String paymentId;
  @override
  ConsumerState<PaymentDetailScreen> createState() =>
      _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends ConsumerState<PaymentDetailScreen> {
  final _amount = TextEditingController();
  late final int _bookGeneration;
  int? _loadedRevision;
  String? _account;
  DateTime _paidAt = DateTime.now();
  bool _carry = false, _busy = false, _userSelectedAccount = false;
  @override
  void initState() {
    super.initState();
    _bookGeneration = ref.read(databaseProvider).restoreGeneration;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _message(Object error) {
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$error')));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _message(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _money(int value) => Money(value, currencyCode: 'PYG').format();
  String _date(DateTime value) =>
      MaterialLocalizations.of(context).formatShortDate(value);
  Future<DateTime?> _pickDate(DateTime value) => showDatePicker(
    context: context,
    initialDate: value,
    firstDate: DateTime(2000),
    lastDate: DateTime(2100),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Detalle de pago')),
    body: ref
        .watch(pendingPaymentsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('$e')),
          data: (rows) {
            final matches = rows.where((p) => p.id == widget.paymentId);
            if (matches.isEmpty)
              return const Center(child: Text('Pago no disponible'));
            final p = matches.first;
            if (_loadedRevision != p.revision) {
              _loadedRevision = p.revision;
              _amount.text = p.remainingMinor > 0
                  ? Money(p.remainingMinor).format(withCode: false).trim()
                  : '';
              _account = null;
              _userSelectedAccount = false;
              _carry = false;
            }
            final hasNext = rows.any(
              (q) =>
                  q.planId == p.planId &&
                  q.installmentNumber > p.installmentNumber &&
                  !q.cancelled &&
                  q.remainingMinor > 0,
            );
            final payable = !p.cancelled && p.remainingMinor > 0;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  p.description.isEmpty ? 'Pago pendiente' : p.description,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Cuota ${p.installmentNumber}/${p.installmentCount}',
                  ),
                  subtitle: Text(_date(p.dueDate)),
                ),
                Text('Previsto: ${_money(p.amountMinor)}'),
                Text('Pagado: ${_money(p.paidMinor)}'),
                Text(
                  p.cancelled
                      ? 'Cancelado'
                      : 'Pendiente: ${_money(p.remainingMinor)}',
                ),
                if (p.data['carriedTo'] != null)
                  TextButton(
                    onPressed: () =>
                        context.push('/payments/${p.data['carriedTo']}'),
                    child: const Text('Ver cuota con resto trasladado'),
                  ),
                for (final payment in p.effectivePayments ?? p.payments)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(_money(payment['amountMinor'] as int)),
                    subtitle: Text(
                      _date(DateTime.parse(payment['paidAt'] as String)),
                    ),
                    onTap: () => context.push(
                      '/transactions/new?edit=${payment['transactionId']}',
                    ),
                  ),
                if (payable) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('paid-amount'),
                    controller: _amount,
                    keyboardType: TextInputType.number,
                    inputFormatters: [PygInputFormatter()],
                    decoration: const InputDecoration(
                      labelText: 'Importe pagado',
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fecha de pago'),
                    subtitle: Text(_date(_paidAt)),
                    onTap: _busy
                        ? null
                        : () async {
                            final date = await _pickDate(_paidAt);
                            if (date != null && mounted)
                              setState(() => _paidAt = date);
                          },
                  ),
                  ref
                      .watch(accountsProvider)
                      .when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('$e'),
                        data: (all) {
                          final accounts = all
                              .where(
                                (a) =>
                                    !a.isArchived &&
                                    a.type != 'creditCard' &&
                                    a.currencyCode == 'PYG',
                              )
                              .toList();
                          String? suggested = p.accountId;
                          DateTime? latestPaidAt;
                          for (final installment in rows.where(
                            (q) => q.planId == p.planId,
                          )) {
                            for (final payment
                                in installment.effectivePayments ??
                                    installment.payments) {
                              final date = DateTime.parse(
                                payment['paidAt'] as String,
                              );
                              if (latestPaidAt == null ||
                                  !date.isBefore(latestPaidAt)) {
                                latestPaidAt = date;
                                suggested = payment['accountId'] as String?;
                              }
                            }
                          }
                          final candidate = _userSelectedAccount
                              ? _account
                              : suggested;
                          final selected =
                              accounts.any((a) => a.id == candidate)
                              ? candidate
                              : !_userSelectedAccount &&
                                    accounts.any((a) => a.id == p.accountId)
                              ? p.accountId
                              : null;
                          _account = selected;
                          return DropdownButtonFormField<String>(
                            key: ValueKey('account-$selected'),
                            initialValue: selected,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Cuenta',
                            ),
                            items: [
                              for (final a in accounts)
                                DropdownMenuItem(
                                  value: a.id,
                                  child: Text(a.name),
                                ),
                            ],
                            onChanged: _busy
                                ? null
                                : (v) => setState(() {
                                    _account = v;
                                    _userSelectedAccount = true;
                                  }),
                          );
                        },
                      ),
                  if (hasNext)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Trasladar resto a la siguiente cuota'),
                      value: _carry,
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _carry = v ?? false),
                    ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                            if (_account == null)
                              throw StateError('Elegí una cuenta.');
                            await ref
                                .read(pendingPaymentServiceProvider)
                                .pay(
                                  id: p.id,
                                  expectedRevision: p.revision,
                                  amountMinor: Money.parse(_amount.text)
                                      .minorUnits,
                                  paidAt: _paidAt,
                                  accountId: _account!,
                                  carryRemainder: hasNext && _carry,
                                  expectedBookGeneration: _bookGeneration,
                                );
                          }),
                    child: const Text('Confirmar pago'),
                  ),
                  if (p.paidMinor == 0)
                    TextButton(
                      onPressed: _busy ? null : () => _edit(p),
                      child: const Text('Editar pendiente'),
                    ),
                  TextButton(
                    onPressed: _busy ? null : () => _reminders(p),
                    child: const Text('Recordatorios'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _cancel(p),
                    child: const Text('Cancelar pendiente'),
                  ),
                ],
              ],
            );
          },
        ),
  );
  Future<void> _cancel(PendingPayment p) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar pendiente'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar cancelación'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) {
      await _run(
        () => ref
            .read(pendingPaymentServiceProvider)
            .cancel(
              p.id,
              expectedRevision: p.revision,
              expectedBookGeneration: _bookGeneration,
            ),
      );
    }
  }

  Future<void> _edit(PendingPayment p) async {
    final amount = TextEditingController(
      text: Money(p.amountMinor).format(withCode: false).trim(),
    );
    var due = p.dueDate, following = false;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Editar pendiente'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [PygInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Importe previsto',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Vencimiento'),
                  subtitle: Text(_date(due)),
                  onTap: () async {
                    final date = await _pickDate(due);
                    if (date != null && context.mounted)
                      update(() => due = date);
                  },
                ),
                if (p.installmentNumber < p.installmentCount)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Esta cuota y las siguientes'),
                    value: following,
                    onChanged: (v) => update(() => following = v ?? false),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && mounted) {
      await _run(
        () => ref
            .read(pendingPaymentServiceProvider)
            .edit(
              id: p.id,
              expectedRevision: p.revision,
              amountMinor: Money.parse(amount.text).minorUnits,
              dueDate: due,
              following: following,
              expectedBookGeneration: _bookGeneration,
            ),
      );
    }
    // The dialog route may still be animating when its future completes.
    WidgetsBinding.instance.addPostFrameCallback((_) => amount.dispose());
  }

  Future<void> _reminders(PendingPayment p) async {
    var settings = p.reminders, following = true;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('Recordatorios'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PaymentReminderFields(
                  value: settings,
                  onChanged: (v) => update(() => settings = v),
                ),
                if (p.installmentNumber < p.installmentCount)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Esta cuota y las siguientes'),
                    value: following,
                    onChanged: (v) => update(() => following = v ?? false),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && mounted) {
      await _run(() async {
        await ref
            .read(pendingPaymentServiceProvider)
            .updateReminders(
              p.id,
              expectedRevision: p.revision,
              settings: settings,
              following: following,
              expectedBookGeneration: _bookGeneration,
            );
        if (settings.enabled) {
          try {
            if (!await ref
                .read(paymentReminderBridgeProvider)
                .requestPermission()) {
              _message('Guardado. Recordatorios sin permiso.');
            }
          } catch (_) {
            _message('Guardado. Recordatorios no disponibles.');
          }
        }
      });
    }
  }
}

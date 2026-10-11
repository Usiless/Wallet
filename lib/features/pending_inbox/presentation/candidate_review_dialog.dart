import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/money/pyg_input_formatter.dart';
import '../../accounts/presentation/create_account_dialog.dart';
import '../../../shared/widgets/app_snack.dart';
import '../../../core/money/amount_validator.dart';

typedef CandidateReview = ({
  Money amount,
  String? merchantId,
  String merchantName,
  String? categoryId,
  String? fromAccountId,
  String? toAccountId,
});

final class CandidateReviewDialog extends ConsumerStatefulWidget {
  const CandidateReviewDialog({
    required this.candidate,
    required this.accounts,
    required this.merchants,
    required this.categories,
    required this.defaults,
    required this.initialMerchant,
    this.fromAccountId,
    this.toAccountId,
    super.key,
  });
  final PaymentCandidateRecord candidate;
  final List<AccountRecord> accounts;
  final List<MerchantRecord> merchants;
  final List<CategoryRecord> categories;
  final Map<String, String?> defaults;
  final String initialMerchant;
  final String? fromAccountId;
  final String? toAccountId;
  @override
  ConsumerState<CandidateReviewDialog> createState() =>
      _CandidateReviewDialogState();
}

class _CandidateReviewDialogState extends ConsumerState<CandidateReviewDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController amount;
  late final TextEditingController merchantName;
  late List<AccountRecord> available;
  late String selectedMerchant;
  String? categoryId;
  String? from;
  String? to;
  PaymentCandidateRecord get row => widget.candidate;
  String get currency => row.currencyCode ?? 'PYG';
  bool get walletPurchase =>
      row.source == 'googleWalletNotification' || row.source == 'developerTest';
  List<MerchantRecord> get merchants => widget.merchants;
  List<CategoryRecord> get expenseCategories => widget.categories;
  Map<String, String?> get defaults => widget.defaults;

  @override
  void initState() {
    super.initState();
    available = widget.accounts;
    from = widget.fromAccountId;
    to = widget.toAccountId;
    selectedMerchant = widget.initialMerchant;
    categoryId = defaults[selectedMerchant];
    amount = TextEditingController(
      text: row.amountMinor == null
          ? ''
          : Money(
              row.amountMinor!,
              currencyCode: currency,
            ).format(withCode: false).trim(),
    );
    merchantName = TextEditingController(text: row.rawMerchant ?? '');
  }

  @override
  void dispose() {
    amount.dispose();
    merchantName.dispose();
    super.dispose();
  }

  String _typeLabel(String type) => switch (type) {
    'income' => 'ingreso',
    'transfer' => 'transferencia',
    'refund' => 'reembolso',
    _ => 'gasto',
  };
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Revisar ${_typeLabel(row.transactionType).toLowerCase()}'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: amount,
              keyboardType: TextInputType.numberWithOptions(
                decimal: currency != 'PYG',
              ),
              inputFormatters: [if (currency == 'PYG') PygInputFormatter()],
              decoration: InputDecoration(
                labelText: 'Importe',
                prefixText: '$currency ',
              ),
              validator: (value) =>
                  validateAmount(value, currencyCode: currency),
            ),
            const SizedBox(height: 16),
            if (walletPurchase) ...[
              DropdownButtonFormField<String>(
                initialValue: selectedMerchant,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Comercio'),
                items: [
                  const DropdownMenuItem(
                    value: '__new__',
                    child: Text('Crear comercio'),
                  ),
                  for (final merchant in merchants)
                    DropdownMenuItem(
                      value: merchant.id,
                      child: Text(
                        merchant.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(() {
                  selectedMerchant = value!;
                  categoryId = defaults[value];
                }),
              ),
              if (selectedMerchant == '__new__') ...[
                const SizedBox(height: 16),
                TextField(
                  controller: merchantName,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del comercio',
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: ValueKey(
                  'merchant-category-$selectedMerchant-$categoryId',
                ),
                initialValue: categoryId ?? '__none__',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Categoría'),
                items: [
                  const DropdownMenuItem(
                    value: '__none__',
                    child: Text('Sin categoría'),
                  ),
                  for (final category in expenseCategories)
                    DropdownMenuItem(
                      value: category.id,
                      child: Text(
                        category.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (value) => setState(
                  () => categoryId = value == '__none__' ? null : value,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (row.transactionType == 'expense' ||
                row.transactionType == 'transfer')
              DropdownButtonFormField<String>(
                key: ValueKey('from-$from-$to-${available.length}'),
                initialValue: from,
                decoration: const InputDecoration(
                  labelText: 'Cuenta de origen',
                ),
                items: [
                  for (final account in available.where(
                    (item) => item.id != to,
                  ))
                    DropdownMenuItem(
                      value: account.id,
                      child: Text(account.name),
                    ),
                ],
                onChanged: (value) => setState(() => from = value),
              ),
            if (row.transactionType == 'transfer') const SizedBox(height: 12),
            if (row.transactionType != 'expense')
              DropdownButtonFormField<String>(
                key: ValueKey('to-$from-$to-${available.length}'),
                initialValue: to,
                decoration: const InputDecoration(
                  labelText: 'Cuenta de destino',
                ),
                items: [
                  for (final account in available.where(
                    (item) => item.id != from,
                  ))
                    DropdownMenuItem(
                      value: account.id,
                      child: Text(account.name),
                    ),
                ],
                onChanged: (value) => setState(() => to = value),
              ),
            TextButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Crear cuenta'),
              onPressed: () async {
                final draft = await showCreateAccountDialog(context);
                if (draft == null || !context.mounted) return;
                try {
                  await ref.read(accountsServiceProvider).createAccount(draft);
                  final refreshed = await ref
                      .read(accountsServiceProvider)
                      .getAccounts();
                  if (context.mounted) {
                    setState(() => available = refreshed);
                  }
                } catch (error) {
                  if (context.mounted) showError(context, error);
                }
              },
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed:
            (!walletPurchase ||
                    selectedMerchant != '__new__' ||
                    merchantName.text.trim().isNotEmpty) &&
                (row.transactionType == 'income' ||
                        row.transactionType == 'refund'
                    ? to != null
                    : row.transactionType == 'expense'
                    ? from != null
                    : from != null && to != null && from != to)
            ? () {
                if (!_form.currentState!.validate()) return;
                Navigator.pop(context, (
                  amount: Money.parse(amount.text, currencyCode: currency),
                  merchantId: walletPurchase && selectedMerchant != '__new__'
                      ? selectedMerchant
                      : null,
                  merchantName: merchantName.text.trim(),
                  categoryId: categoryId,
                  fromAccountId: from,
                  toAccountId: to,
                ));
              }
            : null,
        child: Text(
          row.transactionType == 'expense'
              ? 'Registrar gasto'
              : 'Registrar movimiento',
        ),
      ),
    ],
  );
}

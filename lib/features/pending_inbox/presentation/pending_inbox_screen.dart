import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/text/normalization.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/money_text.dart';
import '../../accounts/presentation/create_account_dialog.dart';
import 'candidate_review_dialog.dart';
import '../../../shared/widgets/app_snack.dart';

final class PendingInboxScreen extends ConsumerWidget {
  const PendingInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final candidates = ref.watch(pendingCandidatesProvider);
    final accounts =
        ref.watch(accountsProvider).value ?? const <AccountRecord>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Movimientos pendientes'),
        actions: [
          IconButton(
            tooltip: 'Actualizar notificaciones',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              try {
                final settings = ref.read(settingsProvider);
                final wallet = await settings.readBool(
                  'notification_listener_enabled',
                );
                final events = await ref
                    .read(nativeNotificationBridgeProvider)
                    .queuedEnvelopes();
                for (final event in events) {
                  if (event.packageName ==
                          'com.google.android.apps.messaging' &&
                      developerToolsEnabled) {
                    await ref
                        .read(smsNotificationIngestionProvider)
                        .ingest(event);
                  } else if (wallet ||
                      (event.isTest && developerToolsEnabled)) {
                    await ref
                        .read(notificationIngestionProvider)
                        .process(event);
                  }
                  await ref
                      .read(nativeNotificationBridgeProvider)
                      .acknowledge(event);
                }
              } catch (error) {
                if (context.mounted) showError(context, error);
              }
            },
          ),
        ],
      ),
      body: AsyncValueView(
        value: candidates,
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No hay compras pendientes. Las notificaciones compatibles aparecerán aquí antes de afectar tus saldos.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final row in rows)
                _CandidateCard(row: row, accounts: accounts),
            ],
          );
        },
      ),
    );
  }
}

final class _CandidateCard extends ConsumerWidget {
  const _CandidateCard({required this.row, required this.accounts});

  final PaymentCandidateRecord row;
  final List<AccountRecord> accounts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final merchants = ref.watch(merchantsProvider);
    final aliases = ref.watch(merchantAliasesProvider);
    final name = normalizeForMatching(row.rawMerchant ?? '');
    final aliasIds = (aliases.value ?? const <MerchantAliasRecord>[])
        .where((a) => normalizeForMatching(a.alias) == name)
        .map((a) => a.merchantId)
        .toSet();
    final matches = (merchants.value ?? const <MerchantRecord>[])
        .where(
          (m) =>
              name.isNotEmpty &&
              (normalizeForMatching(m.name) == name || aliasIds.contains(m.id)),
        )
        .length;
    final merchantStatus = merchants.isLoading || aliases.isLoading
        ? 'Revisando comercio'
        : merchants.hasError || aliases.hasError || name.isEmpty
        ? 'Comercio por revisar'
        : matches == 1
        ? 'Comercio reconocido'
        : matches > 1
        ? 'Comercio ambiguo'
        : 'Comercio nuevo';
    final accountId =
        row.suggestedAccountId ??
        row.suggestedFromAccountId ??
        row.suggestedToAccountId;
    final accountStatus =
        accounts.any((a) => a.id == accountId && !a.isArchived)
        ? 'Cuenta reconocida'
        : 'Cuenta por asociar';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.contactless)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.normalizedMerchant ??
                            row.rawMerchant ??
                            'Comercio por revisar',
                      ),
                      Text(
                        '${row.transactionType == 'expense' ? '' : '${_typeLabel(row.transactionType)} · '}$accountStatus · $merchantStatus',
                      ),
                    ],
                  ),
                ),
                if (row.amountMinor != null)
                  MoneyText(
                    row.amountMinor!,
                    currencyCode: row.currencyCode ?? 'PYG',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(row.suggestionReason),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _confirm(context, ref),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Revisar'),
                ),
                TextButton(
                  onPressed: () => _ignore(context, ref),
                  child: const Text('Descartar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref) async {
    var available = await ref.read(accountsServiceProvider).getAccounts();
    if (!context.mounted) return;
    if (available.isEmpty) {
      final draft = await showCreateAccountDialog(context);
      if (draft == null || !context.mounted) return;
      try {
        await ref.read(accountsServiceProvider).createAccount(draft);
        available = await ref.read(accountsServiceProvider).getAccounts();
      } catch (error) {
        if (context.mounted) showError(context, error);
        return;
      }
      if (!context.mounted) return;
    }
    String? activeId(String? id) =>
        available.any((a) => a.id == id) ? id : null;
    String? from = activeId(
      row.suggestedFromAccountId ??
          (row.transactionType == 'expense' ? row.suggestedAccountId : null),
    );
    String? to = activeId(
      row.suggestedToAccountId ??
          (row.transactionType == 'income' ? row.suggestedAccountId : null),
    );
    final walletPurchase =
        row.source == 'googleWalletNotification' ||
        row.source == 'developerTest';
    final merchants = await ref.read(merchantServiceProvider).listMerchants();
    final matches = await ref
        .read(merchantServiceProvider)
        .matches(row.rawMerchant ?? '');
    String selectedMerchant = matches.length == 1
        ? matches.single.id
        : '__new__';
    final categories = await ref.read(categoryServiceProvider).list();
    final expenseCategories = categories
        .where((c) => c.kind != 'income')
        .toList();
    final defaults = <String, String?>{};
    for (final merchant in merchants) {
      defaults[merchant.id] = await ref
          .read(merchantServiceProvider)
          .defaultCategory(merchant.id);
    }
    if (!context.mounted) return;
    final review = await showDialog<CandidateReview>(
      context: context,
      builder: (_) => CandidateReviewDialog(
        candidate: row,
        accounts: available,
        merchants: merchants,
        categories: expenseCategories,
        defaults: defaults,
        initialMerchant: selectedMerchant,
        fromAccountId: from,
        toAccountId: to,
      ),
    );
    if (review == null || !context.mounted) return;
    try {
      await ref
          .read(notificationIngestionProvider)
          .confirm(
            row,
            fromAccountId: review.fromAccountId,
            toAccountId: review.toAccountId,
            merchantId: review.merchantId,
            merchantName: review.merchantName,
            revisedAmount: review.amount,
            categoryId: walletPurchase ? review.categoryId : null,
            rememberCategory: walletPurchase,
          );
      if (context.mounted) showMessage(context, 'Compra confirmada.');
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  String _typeLabel(String type) => switch (type) {
    'income' => 'Ingreso',
    'transfer' => 'Transferencia',
    'refund' => 'Reembolso',
    _ => 'Gasto',
  };

  Future<void> _ignore(BuildContext context, WidgetRef ref) async {
    final service = ref.read(notificationIngestionProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await service.ignore(row.id);
      if (messenger.mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Propuesta descartada. No se registró ningún movimiento.',
            ),
          ),
        );
      }
    } catch (error) {
      if (messenger.mounted) {
        messenger.showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}

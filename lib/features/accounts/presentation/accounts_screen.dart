import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../data/accounts_service.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/money_text.dart';
import '../../../core/money/money.dart';
import '../../transactions/domain/ledger_models.dart';
import 'create_account_dialog.dart';
import '../../transactions/presentation/ledger_actions.dart';
import '../../transactions/presentation/transactions_screen.dart';
import '../../credit_cards/domain/credit_card_cycle.dart';
import '../../../shared/widgets/app_fab.dart';

final class AccountsScreen extends ConsumerStatefulWidget {
  const AccountsScreen({this.accountId, super.key});
  final String? accountId;

  @override
  ConsumerState<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends ConsumerState<AccountsScreen> {
  bool _showArchived = false;
  String? _type;
  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(
      _showArchived || widget.accountId != null
          ? allAccountsProvider
          : accountsProvider,
    );
    final balances =
        ref.watch(accountBalancesProvider).value ?? const <AccountBalance>[];
    final selected = accounts.value
        ?.where((a) => a.id == widget.accountId)
        .firstOrNull;
    return Scaffold(
      appBar: widget.accountId == null
          ? null
          : AppBar(title: Text(selected?.name ?? 'Cuenta')),
      body: AsyncValueView(
        value: accounts,
        data: (rows) {
          if (widget.accountId != null) {
            if (selected == null) {
              return const Center(child: Text('Cuenta no disponible.'));
            }
            final balance =
                balances
                    .where((b) => b.id == selected.id)
                    .firstOrNull
                    ?.balanceMinor ??
                selected.initialBalanceMinor;
            return _detail(selected, balance);
          }
          final filtered = rows
              .where((a) => _type == null || a.type == _type)
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final item in <(String?, String)>[
                      (null, 'Todas'),
                      ('bank', 'Bancarias'),
                      ('cash', 'Efectivo'),
                      ('savings', 'Ahorro'),
                      ('creditCard', 'Crédito'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(item.$2),
                          selected: _type == item.$1,
                          onSelected: (_) => setState(() => _type = item.$1),
                        ),
                      ),
                  ],
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Mostrar también archivadas'),
                value: _showArchived,
                onChanged: (v) => setState(() => _showArchived = v ?? false),
              ),
              if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: Text('Sin cuentas para mostrar.')),
                ),
              LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final account in filtered)
                      SizedBox(
                        width:
                            constraints.maxWidth < 340 ||
                                MediaQuery.textScalerOf(context).scale(16) > 22
                            ? constraints.maxWidth
                            : (constraints.maxWidth - 12) / 2,
                        child: Card(
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () =>
                                context.push('/accounts?account=${account.id}'),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    account.type == 'creditCard'
                                        ? Icons.credit_card_outlined
                                        : account.type == 'cash'
                                        ? Icons.payments_outlined
                                        : account.type == 'savings'
                                        ? Icons.savings_outlined
                                        : Icons.account_balance_outlined,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    account.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall,
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: MoneyText(
                                      balances
                                              .where((b) => b.id == account.id)
                                              .firstOrNull
                                              ?.balanceMinor ??
                                          account.initialBalanceMinor,
                                      currencyCode: account.currencyCode,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium,
                                    ),
                                  ),
                                  if (account.isArchived)
                                    const Text('Archivada'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: widget.accountId == null
          ? AppFab(
              tooltip: 'Agregar cuenta',
              onPressed: () => _showCreate(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _detail(AccountRecord account, int balance) {
    final movements = ref
        .watch(ledgerRepositoryProvider)
        .watchMovements(
          filter: (
            search: '',
            account: account.id,
            merchant: null,
            category: null,
            type: null,
            start: null,
            end: null,
          ),
          limit: 4,
        );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.type == 'creditCard'
                      ? 'Deuda registrada'
                      : 'Saldo registrado',
                ),
                Text(
                  Money(balance, currencyCode: account.currencyCode).format(),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (account.isArchived) const Text('Archivada'),
              ],
            ),
          ),
        ),
        if (account.type == 'creditCard')
          FutureBuilder<CreditCardProfileRecord?>(
            future:
                (ref
                        .read(databaseProvider)
                        .select(ref.read(databaseProvider).creditCardProfiles)
                      ..where((p) => p.accountId.equals(account.id)))
                    .getSingleOrNull(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text('No se pudo cargar la tarjeta: ${snapshot.error}');
              }
              final profile = snapshot.data;
              if (profile == null) return const LinearProgressIndicator();
              final dates = const CreditCardCycleCalculator().nextDates(
                localDate: DateTime.now(),
                closingDay: profile.closingDay,
                dueDay: profile.dueDay,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ListTile(
                    title: const Text('Límite'),
                    subtitle: MoneyText(profile.creditLimitMinor),
                  ),
                  ListTile(
                    title: const Text('Crédito disponible'),
                    subtitle: MoneyText(
                      const CreditCardCycleCalculator().availableCredit(
                        creditLimitMinor: profile.creditLimitMinor,
                        debtMinor: balance,
                      ),
                    ),
                  ),
                  Text(
                    'Próximo cierre: ${MaterialLocalizations.of(context).formatShortDate(dates.nextClosing)}',
                  ),
                  Text(
                    'Vencimiento estimado: ${MaterialLocalizations.of(context).formatShortDate(dates.nextDue)}',
                  ),
                  if (profile.minimumPaymentMinor != null)
                    ListTile(
                      title: const Text('Mínimo registrado manualmente'),
                      subtitle: MoneyText(profile.minimumPaymentMinor!),
                    ),
                  if (!account.isArchived)
                    FilledButton.icon(
                      onPressed: () => context.push(
                        '/transactions/new?template=cardPayment&to=${account.id}',
                      ),
                      icon: const Icon(Icons.payments_outlined),
                      label: const Text('Pagar esta tarjeta'),
                    ),
                ],
              );
            },
          ),
        if (account.type == 'savings')
          SwitchListTile(
            title: const Text('Incluir en dinero disponible'),
            value: account.includeInAvailableMoney,
            onChanged: (value) async {
              try {
                await ref
                    .read(accountsServiceProvider)
                    .setSavingsIncludedInAvailableMoney(account.id, value);
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('$error')));
                }
              }
            },
          ),
        FutureBuilder<List<AccountAliasRecord>>(
          future:
              (ref
                      .read(databaseProvider)
                      .select(ref.read(databaseProvider).accountAliases)
                    ..where((a) => a.accountId.equals(account.id)))
                  .get(),
          builder: (context, snapshot) => ListTile(
            title: const Text('Alias'),
            subtitle: Text(
              snapshot.hasError
                  ? 'No se pudieron cargar'
                  : snapshot.data?.map((a) => a.alias).join(', ') ?? '…',
            ),
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(
              onPressed: () =>
                  context.push('/transactions?account=${account.id}'),
              child: const Text('Ver movimientos'),
            ),
            OutlinedButton(
              onPressed: () => _edit(context, account),
              child: const Text('Editar'),
            ),
            if (!account.isArchived)
              OutlinedButton(
                onPressed: () => showReconcileDialog(context, ref, account),
                child: const Text('Conciliar saldo'),
              ),
            OutlinedButton(
              onPressed: () => _archive(context, account),
              child: Text(account.isArchived ? 'Reactivar' : 'Archivar'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Movimientos', style: Theme.of(context).textTheme.titleMedium),
        StreamBuilder(
          stream: movements,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text('No se pudieron cargar: ${snapshot.error}');
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            if (snapshot.data!.isEmpty) {
              return const Text('Sin movimientos todavía.');
            }
            return Column(
              children: [
                for (final row in snapshot.data!)
                  ListTile(
                    title: Text(
                      row.transaction.description.isEmpty
                          ? 'Movimiento'
                          : row.transaction.description,
                    ),
                    subtitle: Text(
                      '${MaterialLocalizations.of(context).formatShortDate(row.occurredAt)}${row.isQuota ? ' · Cuota ${row.number}/${row.count}' : ''}${row.planned ? ' · Prevista' : ''}',
                    ),
                    trailing: MoneyText(row.amountMinor),
                    onTap: () => showMovementDetail(context, ref, row),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _edit(BuildContext context, AccountRecord account) async {
    try {
      final db = ref.read(databaseProvider);
      final aliases = await (db.select(
        db.accountAliases,
      )..where((t) => t.accountId.equals(account.id))).get();
      final card = await (db.select(
        db.creditCardProfiles,
      )..where((t) => t.accountId.equals(account.id))).getSingleOrNull();
      if (!context.mounted) return;
      final draft = await showCreateAccountDialog(
        context,
        initial: CreateAccountDraft(
          name: account.name,
          type: AccountType.values.byName(account.type),
          currencyCode: account.currencyCode,
          initialBalanceMinor: account.initialBalanceMinor,
          aliases: aliases.map((a) => a.alias).toList(),
          includeInAvailableMoney: account.includeInAvailableMoney,
          includeInNetWorth: account.includeInNetWorth,
          creditLimitMinor: card?.creditLimitMinor,
          closingDay: card?.closingDay,
          dueDay: card?.dueDay,
        ),
      );
      if (draft == null || !mounted) return;
      await ref.read(accountsServiceProvider).edit(account.id, draft);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _archive(BuildContext context, AccountRecord account) async {
    try {
      await ref
          .read(accountsServiceProvider)
          .setArchived(account.id, !account.isArchived);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }

  Future<void> _showCreate(BuildContext context, WidgetRef ref) async {
    final draft = await showCreateAccountDialog(context);
    if (draft == null || !context.mounted) return;
    try {
      await ref.read(accountsServiceProvider).createAccount(draft);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Cuenta creada.')));
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}

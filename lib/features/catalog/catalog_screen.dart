import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../core/database/app_database.dart';
import '../../shared/widgets/app_fab.dart';
import '../../shared/widgets/text_prompt_dialog.dart';

final catalogProvider = StreamProvider.autoDispose.family<List<Object>, String>(
  (ref, kind) {
    return switch (kind) {
      'merchants' =>
        ref
            .watch(merchantServiceProvider)
            .watchMerchants(includeArchived: true),
      'categories' =>
        ref
            .watch(categoryServiceProvider)
            .watchCategories(includeArchived: true),
      'accountAliases' => ref.watch(accountsServiceProvider).watchAliases(),
      _ => ref.watch(merchantServiceProvider).watchAliases(),
    };
  },
);

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({super.key});
  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  String _kind = 'merchants';
  bool _archived = false;
  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(catalogProvider(_kind));
    final accounts = ref.watch(allAccountsProvider).value ?? <AccountRecord>[];
    final merchants = ref.watch(merchantsProvider).value ?? <MerchantRecord>[];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrar datos'),
        actions: [
          IconButton(
            tooltip: 'Mostrar archivados',
            onPressed: () => setState(() => _archived = !_archived),
            icon: Icon(
              _archived ? Icons.inventory_2 : Icons.inventory_2_outlined,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<String>(
              initialValue: _kind,
              isExpanded: true,
              items: const [
                DropdownMenuItem(value: 'merchants', child: Text('Comercios')),
                DropdownMenuItem(
                  value: 'categories',
                  child: Text('Categorías'),
                ),
                DropdownMenuItem(
                  value: 'accountAliases',
                  child: Text('Alias de cuentas'),
                ),
                DropdownMenuItem(
                  value: 'merchantAliases',
                  child: Text('Alias de comercios'),
                ),
              ],
              onChanged: (v) => setState(() => _kind = v!),
            ),
          ),
          Expanded(
            child: rows.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (items) {
                final visible = items
                    .where(
                      (r) =>
                          _archived ||
                          switch (r) {
                            MerchantRecord m => !m.isArchived,
                            CategoryRecord c => !c.isArchived,
                            _ => true,
                          },
                    )
                    .toList();
                visible.sort(
                  (a, b) =>
                      _name(a).toLowerCase().compareTo(_name(b).toLowerCase()),
                );
                if (visible.isEmpty) {
                  return const Center(child: Text('Sin elementos.'));
                }
                return ListView(
                  children: [
                    for (final row in visible)
                      ListTile(
                        title: Text(_name(row)),
                        subtitle: Text(switch (row) {
                          MerchantRecord m =>
                            m.isArchived ? 'Archivado' : 'Comercio',
                          CategoryRecord c =>
                            '${c.kind == 'income'
                                ? 'Ingreso'
                                : c.kind == 'both'
                                ? 'Ingreso y gasto'
                                : 'Gasto'}${c.isArchived ? ' · Archivada' : ''}',
                          AccountAliasRecord a =>
                            '${accounts.where((r) => r.id == a.accountId).firstOrNull?.name ?? 'Cuenta'}${items.whereType<AccountAliasRecord>().where((b) => b.normalizedAlias == a.normalizedAlias && accounts.any((c) => c.id == b.accountId && !c.isArchived)).map((b) => b.accountId).toSet().length > 1 ? ' · Conflicto' : ''}',
                          MerchantAliasRecord a =>
                            merchants
                                    .where((r) => r.id == a.merchantId)
                                    .firstOrNull
                                    ?.name ??
                                'Comercio archivado',
                          _ => '',
                        }),
                        onTap: row is MerchantRecord
                            ? () => context.push(
                                '/transactions?merchant=${row.id}',
                              )
                            : null,
                        trailing: PopupMenuButton<String>(
                          onSelected: (action) => _action(row, action),
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text(
                                row is AccountAliasRecord ||
                                        row is MerchantAliasRecord
                                    ? 'Reasignar'
                                    : 'Renombrar',
                              ),
                            ),
                            if (row is MerchantRecord || row is CategoryRecord)
                              PopupMenuItem(
                                value: 'archive',
                                child: Text(
                                  (row is MerchantRecord && row.isArchived) ||
                                          (row is CategoryRecord &&
                                              row.isArchived)
                                      ? 'Reactivar'
                                      : 'Archivar',
                                ),
                              )
                            else
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Eliminar alias'),
                              ),
                          ],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: AppFab(
        onPressed: _add,
        tooltip: 'Agregar',
        child: const Icon(Icons.add),
      ),
    );
  }

  String _name(Object row) => switch (row) {
    MerchantRecord m => m.name,
    CategoryRecord c => c.name,
    AccountAliasRecord a => a.alias,
    MerchantAliasRecord a => a.alias,
    _ => '',
  };
  Future<String?> _text(String title, String initial) => showTextPrompt(
    context,
    title: title,
    label: 'Nombre',
    confirmLabel: 'Guardar',
    initial: initial,
  );

  Future<String?> _target(bool account) async {
    final choices = account
        ? await ref.read(accountsServiceProvider).getAccounts()
        : await ref.read(merchantServiceProvider).listMerchants();
    if (!mounted) return null;
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(account ? 'Asociar a cuenta' : 'Asociar a comercio'),
        children: [
          for (final row in choices)
            if (row is AccountRecord ||
                row is MerchantRecord && !row.isArchived)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(
                  context,
                  row is AccountRecord ? row.id : (row as MerchantRecord).id,
                ),
                child: Text(
                  row is AccountRecord
                      ? row.name
                      : (row as MerchantRecord).name,
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _action(Object row, String action) async {
    try {
      if (action == 'archive') {
        if (row is MerchantRecord) {
          await ref
              .read(merchantServiceProvider)
              .setArchived(row.id, !row.isArchived);
        }
        if (row is CategoryRecord) {
          await ref
              .read(categoryServiceProvider)
              .setArchived(row.id, !row.isArchived);
        }
      } else if (action == 'delete') {
        if (row is AccountAliasRecord) {
          await ref.read(accountsServiceProvider).removeAlias(row.id);
        }
        if (row is MerchantAliasRecord) {
          await ref.read(merchantServiceProvider).removeAlias(row.id);
        }
      } else if (row is AccountAliasRecord || row is MerchantAliasRecord) {
        final target = await _target(row is AccountAliasRecord);
        if (target == null || !mounted) return;
        if (row is AccountAliasRecord) {
          await ref
              .read(accountsServiceProvider)
              .assignAlias(row.alias, target, replaceExisting: true);
        }
        if (row is MerchantAliasRecord) {
          await ref
              .read(merchantServiceProvider)
              .assignAlias(row.alias, target, replaceExisting: true);
        }
      } else {
        final name = await _text('Renombrar', _name(row));
        if (name == null || !mounted) return;
        if (row is MerchantRecord) {
          await ref.read(merchantServiceProvider).rename(row.id, name);
        }
        if (row is CategoryRecord) {
          await ref.read(categoryServiceProvider).rename(row.id, name);
        }
      }
    } catch (e) {
      _error(e);
    }
  }

  Future<void> _add() async {
    try {
      final name = await _text(
        _kind.contains('Aliases') ? 'Nuevo alias' : 'Nuevo elemento',
        '',
      );
      if (name == null || !mounted) return;
      if (_kind == 'merchants') {
        await ref.read(merchantServiceProvider).findOrCreate(name);
      } else if (_kind == 'categories') {
        final kind = await showDialog<String>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('Tipo de categoría'),
            children: [
              for (final entry in {
                'expense': 'Gasto',
                'income': 'Ingreso',
                'both': 'Ambos',
              }.entries)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, entry.key),
                  child: Text(entry.value),
                ),
            ],
          ),
        );
        if (kind != null && mounted) {
          await ref.read(categoryServiceProvider).create(name, kind: kind);
        }
      } else {
        final account = _kind == 'accountAliases';
        final target = await _target(account);
        if (target == null || !mounted) return;
        if (account) {
          await ref.read(accountsServiceProvider).assignAlias(name, target);
        } else {
          await ref.read(merchantServiceProvider).assignAlias(name, target);
        }
      }
    } catch (e) {
      _error(e);
    }
  }

  void _error(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/money/pyg_input_formatter.dart';
import '../../../shared/widgets/text_prompt_dialog.dart';
import '../../merchants/merchant_autocomplete.dart';
import '../../payments/presentation/payment_reminder_fields.dart';
import '../../templates/save_template_dialog.dart';
import '../../templates/template_picker_sheet.dart';
import '../data/transaction_form_service.dart';
import '../domain/ledger_models.dart';
import '../domain/payment_channel_policy.dart';
import 'transaction_form_notifier.dart';
import 'transaction_form_state.dart';

final class TransactionFormScreen extends ConsumerStatefulWidget {
  const TransactionFormScreen({
    this.initialType = TransactionType.expense,
    this.template,
    this.cloneId,
    this.editId,
    this.toAccountId,
    this.savedTemplateId,
    this.editTemplate = false,
    super.key,
  });

  final TransactionType initialType;
  final String? template;
  final String? cloneId;
  final String? editId;
  final String? toAccountId;
  final String? savedTemplateId;
  final bool editTemplate;

  TransactionFormArgs get args => (
    initialType: initialType,
    template: template,
    cloneId: cloneId,
    editId: editId,
    toAccountId: toAccountId,
    savedTemplateId: savedTemplateId,
    editTemplate: editTemplate,
  );

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

/// Vista del formulario: dibuja el estado del ViewModel y le reenvía lo que
/// el usuario hace. Lo que depende del contexto (diálogos, selectores de
/// fecha, permiso de avisos, navegación) se resuelve aquí.
class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _merchant = TextEditingController();
  final _note = TextEditingController();
  bool _confirmingExit = false;

  late final TransactionFormArgs _args = widget.args;
  TransactionFormState get _state => ref.read(transactionFormProvider(_args));
  TransactionFormNotifier get _vm =>
      ref.read(transactionFormProvider(_args).notifier);

  @override
  void initState() {
    super.initState();
    _amount.addListener(() => _vm.setAmountText(_amount.text));
    _merchant.addListener(() => _vm.setMerchantText(_merchant.text));
    _note.addListener(() => _vm.setNoteText(_note.text));
    ref.listenManual(
      transactionFormProvider(_args).select((state) => state.textRevision),
      (_, _) => _copyTextsFromState(),
    );
  }

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _note.dispose();
    super.dispose();
  }

  /// El estado cambió los textos por su cuenta (carga o limpieza).
  void _copyTextsFromState() {
    final state = _state;
    if (_amount.text != state.amountText) _amount.text = state.amountText;
    if (_merchant.text != state.merchantText) {
      _merchant.text = state.merchantText;
    }
    if (_note.text != state.noteText) _note.text = state.noteText;
  }

  Future<void> _tryExit(bool didPop, Object? result) async {
    if (didPop || _confirmingExit || _state.saving) return;
    _confirmingExit = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('¿Descartar cambios?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('Seguir editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    _confirmingExit = false;
    if (discard != true || !mounted) return;
    _vm.markClean();
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionFormProvider(_args));
    final accountsAsync = ref.watch(accountsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editTemplate
              ? 'Editar plantilla'
              : widget.editId != null
              ? 'Editar movimiento'
              : 'Nuevo movimiento',
        ),
        actions: [
          if (!widget.editTemplate && widget.editId == null)
            IconButton(
              tooltip: 'Usar plantilla',
              onPressed: state.saving ? null : _useTemplate,
              icon: Icon(
                state.alsoSaveTemplate
                    ? Icons.bookmark_added
                    : Icons.bookmarks_outlined,
              ),
            ),
        ],
      ),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('$error')),
        data: (activeAccounts) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.loadError != null) {
            return Center(child: Text(state.loadError!));
          }
          final accounts = state.accountsFrom(activeAccounts);
          final categories = state.categoriesFrom(
            categoriesAsync.value ?? const <CategoryRecord>[],
          );
          final available = categories
              .where(state.categoryMatchesType)
              .toList();
          AccountType? typeOf(String? id) {
            final account = accounts.where((a) => a.id == id).firstOrNull;
            return account == null
                ? null
                : AccountType.values.byName(account.type);
          }

          final channels = PaymentChannelPolicy.allowed(
            state.type,
            from: typeOf(state.from),
            to: typeOf(state.to),
          );
          return Form(
            key: _formKey,
            canPop: !state.saving && !state.isDirty,
            onPopInvokedWithResult: _tryExit,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                _amountField(context),
                const SizedBox(height: 16),
                _typeSelector(state),
                const SizedBox(height: 16),
                if (state.needsFrom)
                  _AccountField(
                    label: 'Cuenta de origen',
                    value: state.from,
                    accounts: accounts,
                    onChanged: _vm.setFrom,
                  ),
                if (state.needsFrom && state.needsTo)
                  const SizedBox(height: 12),
                if (state.needsTo)
                  _AccountField(
                    label: 'Cuenta de destino',
                    value: state.to,
                    accounts: accounts,
                    excludedId: state.needsFrom ? state.from : null,
                    onChanged: _vm.setTo,
                  ),
                if (state.type != TransactionType.transfer) ...[
                  const SizedBox(height: 12),
                  if (!state.splitEnabled)
                    _CategoryDropdown(
                      identity: ('category', state.type, state.category),
                      categories: available,
                      value: state.category,
                      onCreate: _createCategory,
                      onChanged: _vm.setCategory,
                    ),
                  TextButton.icon(
                    onPressed: categories.isEmpty ? null : _vm.toggleSplits,
                    icon: const Icon(Icons.call_split),
                    label: Text(
                      state.splitEnabled
                          ? 'Usar una sola categoría'
                          : 'Dividir entre categorías',
                    ),
                  ),
                  if (state.splitEnabled) ...[
                    for (final split in state.splits)
                      _SplitRow(
                        key: ValueKey(split.id),
                        split: split,
                        type: state.type,
                        categories: available,
                        canRemove: state.splits.length > 2,
                        onCategory: (value) =>
                            _vm.setSplitCategory(split.id, value),
                        onAmount: (text) => _vm.setSplitAmount(split.id, text),
                        onRemove: () => _vm.removeSplit(split.id),
                      ),
                    TextButton.icon(
                      onPressed: _vm.addSplit,
                      icon: const Icon(Icons.add),
                      label: const Text('Otra categoría'),
                    ),
                  ],
                  const SizedBox(height: 4),
                  if (state.type == TransactionType.expense)
                    MerchantAutocomplete(
                      label: 'Descripción',
                      controller: _merchant,
                      onSelected: _vm.selectMerchant,
                    )
                  else
                    TextFormField(
                      controller: _merchant,
                      decoration: InputDecoration(
                        labelText: state.type == TransactionType.income
                            ? 'Pagador'
                            : 'Comercio',
                      ),
                    ),
                ],
                const SizedBox(height: 8),
                ..._details(context, state, accounts, channels),
                if (!widget.editTemplate && widget.editId == null)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: state.saveAnother,
                    onChanged: (value) => _vm.setSaveAnother(value ?? false),
                    title: const Text('Guardar y crear otro'),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: state.saving
                      ? null
                      : () => widget.editTemplate
                            ? _saveTemplate()
                            : _save(accounts),
                  icon: const Icon(Icons.check),
                  label: Text(
                    state.saving
                        ? 'Guardando…'
                        : widget.editTemplate
                        ? 'Guardar plantilla'
                        : widget.editId != null
                        ? 'Guardar cambios'
                        : 'Guardar movimiento',
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _amountField(BuildContext context) => TextFormField(
    controller: _amount,
    inputFormatters: [PygInputFormatter()],
    autofocus: widget.cloneId == null,
    keyboardType: TextInputType.number,
    textInputAction: TextInputAction.next,
    style: Theme.of(context).textTheme.headlineMedium,
    decoration: const InputDecoration(prefixText: 'PYG ', labelText: 'Importe'),
    validator: (value) {
      try {
        if (Money.parse(value ?? '').minorUnits <= 0) {
          return 'Debe ser mayor que cero';
        }
      } catch (_) {
        return 'Ingresá un importe válido';
      }
      return null;
    },
  );

  Widget _typeSelector(TransactionFormState state) {
    final onChange = widget.editId != null ? null : _vm.setType;
    if (MediaQuery.sizeOf(context).width < 420 &&
        MediaQuery.textScalerOf(context).scale(14) > 20) {
      return DropdownButtonFormField<TransactionType>(
        initialValue: state.type,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Tipo'),
        items: const [
          DropdownMenuItem(
            value: TransactionType.expense,
            child: Text('Gasto'),
          ),
          DropdownMenuItem(
            value: TransactionType.income,
            child: Text('Ingreso'),
          ),
          DropdownMenuItem(
            value: TransactionType.transfer,
            child: Text('Transferir'),
          ),
        ],
        onChanged: onChange == null
            ? null
            : (value) => onChange(value ?? state.type),
      );
    }
    return SegmentedButton<TransactionType>(
      segments: const [
        ButtonSegment(
          value: TransactionType.expense,
          label: Text('Gasto'),
          icon: Icon(Icons.south_west),
        ),
        ButtonSegment(
          value: TransactionType.income,
          label: Text('Ingreso'),
          icon: Icon(Icons.north_east),
        ),
        ButtonSegment(
          value: TransactionType.transfer,
          label: Text('Transferir'),
          icon: Icon(Icons.swap_horiz),
        ),
      ],
      selected: {state.type},
      onSelectionChanged: onChange == null
          ? null
          : (value) => onChange(value.first),
    );
  }

  /// «Más detalles»: cuándo se paga, cuotas, repetición, fecha, canal y nota.
  List<Widget> _details(
    BuildContext context,
    TransactionFormState state,
    List<AccountRecord> accounts,
    List<PaymentChannel> channels,
  ) {
    final open = state.advanced || state.payLater || state.installments;
    final credit = state.isCreditExpense(accounts);
    final installmentsOn = state.installmentsOn(accounts);
    final pendingOn = state.pendingOn(accounts);
    final when = state.installments
        ? 'installments'
        : state.payLater
        ? 'later'
        : 'now';
    return [
      TextButton.icon(
        onPressed: state.payLater || state.installments
            ? null
            : _vm.toggleAdvanced,
        icon: Icon(open ? Icons.expand_less : Icons.tune),
        label: Text(open ? 'Ocultar detalles' : 'Más detalles'),
      ),
      if (open) ...[
        if (state.type == TransactionType.expense &&
            (widget.editId == null || credit))
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
            onChanged: (value) => _vm.setWhen(value ?? 'now'),
          ),
        if (installmentsOn)
          DropdownButtonFormField<int>(
            isExpanded: true,
            initialValue: state.installmentCount,
            decoration: const InputDecoration(labelText: 'Cantidad de cuotas'),
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
            onChanged: (value) => _vm.setInstallmentCount(value ?? 2),
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
            onChanged: _vm.setRepeat,
          ),
        if ((installmentsOn || pendingOn) && !widget.editTemplate)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(installmentsOn ? 'Primera cuota' : 'Fecha de pago'),
            subtitle: Text(
              MaterialLocalizations.of(
                context,
              ).formatShortDate(state.firstInstallmentDate ?? state.occurredAt),
            ),
            trailing: const Icon(Icons.calendar_month_outlined),
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: state.firstInstallmentDate ?? state.occurredAt,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null && mounted) {
                _vm.setFirstInstallmentDate(picked);
              }
            },
          ),
        if (pendingOn)
          PaymentReminderFields(
            value: state.reminders,
            onChanged: _vm.setReminders,
          ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.calendar_today),
          title: const Text('Fecha'),
          subtitle: Text(
            '${state.occurredAt.day}/${state.occurredAt.month}/${state.occurredAt.year}',
          ),
          onTap: _pickDate,
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
          onChanged: (value) => _vm.setChannel(value ?? state.channel),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _note,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Nota'),
        ),
      ],
    ];
  }

  // --- acciones que necesitan el contexto ---

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _state.occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (value != null && mounted) _vm.setOccurredAt(value);
  }

  Future<void> _createCategory() async {
    final value = await showTextPrompt(
      context,
      title: 'Nueva categoría',
      label: 'Nombre',
      confirmLabel: 'Crear',
    );
    if (value == null || !mounted) return;
    try {
      await _vm.createCategory(value);
    } catch (error) {
      _message('$error');
    }
  }

  Future<void> _useTemplate() async {
    final templates = await _vm.templatesForPicker();
    if (!mounted) return;
    final state = _state;
    final selected = await showTemplatePicker(
      context,
      templates: templates,
      offerSave: !(state.payLater && state.type == TransactionType.expense),
      saving: state.alsoSaveTemplate,
    );
    if (selected == null || !mounted) return;
    switch (selected) {
      case ToggleSaveAsTemplate():
        _vm.setAlsoSaveTemplate(!state.alsoSaveTemplate);
      case ManageTemplates():
        context.push('/templates');
      case UseTemplate():
        await _vm.useTemplate(selected.id);
    }
  }

  /// Pregunta cómo guardar la plantilla; `null` si se cancela o no es válida.
  Future<TemplateToSave?> _collectTemplate({
    bool afterRegistration = false,
  }) async {
    final state = _state;
    final defaults = state.templateDefaults(
      afterRegistration: afterRegistration,
    );
    final choice = await showSaveTemplateDialog(
      context,
      name: state.templateName,
      includeAmount: defaults.includeAmount,
      automatic: defaults.automatic,
      frequency: defaults.frequency,
      nextDate: defaults.nextDate,
      reminders: state.reminders,
      nextDateForFrequency: defaults.nextDateForFrequency,
    );
    if (choice == null || !mounted) return null;
    try {
      return _state.templateFrom(
        choice,
        afterRegistration: afterRegistration,
        originalNextDate: defaults.nextDate,
        originalFrequency: defaults.frequency,
      );
    } catch (error) {
      _message('$error');
      return null;
    }
  }

  Future<void> _saveTemplate() async {
    _vm.setSaving(true);
    try {
      final template = await _collectTemplate();
      if (template == null || !mounted) return;
      await _vm.saveTemplate(template);
      if ((template.fields['schedule'] as Map?)?['enabled'] == true &&
          (template.fields['reminders'] as Map?)?['enabled'] == true) {
        await _requestReminderPermission();
      }
      if (mounted) {
        _message('Plantilla guardada.');
        _vm.finishSave();
        await WidgetsBinding.instance.endOfFrame;
        if (mounted && widget.editTemplate) context.pop();
      }
    } catch (error) {
      if (mounted) _message('$error');
    } finally {
      if (mounted) _vm.setSaving(false);
    }
  }

  Future<void> _save(List<AccountRecord> accounts) async {
    if (!_formKey.currentState!.validate()) return;
    final state = _state;
    if (state.needsFrom && state.from == null ||
        state.needsTo && state.to == null) {
      _message('Seleccioná las cuentas necesarias.');
      return;
    }
    try {
      _vm.setSaving(true);
      final pendingPlan = state.pendingOn(accounts);
      final template = state.alsoSaveTemplate && !pendingPlan
          ? await _collectTemplate(afterRegistration: true)
          : null;
      if (!mounted) return;
      if (state.alsoSaveTemplate && !pendingPlan && template == null) {
        _vm.setSaving(false);
        return;
      }
      final outcome = await _vm.submit(template);
      if (outcome.requestReminderPermission) await _requestReminderPermission();
      if (!mounted) return;
      await _vm.rememberLastAccounts();
      HapticFeedback.lightImpact();
      if (!mounted) return;
      if (_state.saveAnother) {
        _vm.resetForAnother();
        _message('Movimiento guardado.');
      } else {
        _vm.finishSave();
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) context.pop();
      }
    } catch (error) {
      _message('$error');
      if (mounted) _vm.setSaving(false);
    }
  }

  Future<void> _requestReminderPermission() async {
    try {
      final allowed = await ref
          .read(paymentReminderBridgeProvider)
          .requestPermission();
      if (!allowed && mounted) _message('Guardado. Recordatorios sin permiso.');
    } catch (_) {
      if (mounted) _message('Guardado. Recordatorios no disponibles.');
    }
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

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }
}

final class _AccountField extends StatelessWidget {
  const _AccountField({
    required this.label,
    required this.value,
    required this.accounts,
    required this.onChanged,
    this.excludedId,
  });

  final String label;
  final String? value;
  final List<AccountRecord> accounts;
  final ValueChanged<String?> onChanged;
  final String? excludedId;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    key: ValueKey((
      label,
      value,
      excludedId,
      accounts.map((row) => row.id).join(','),
    )),
    initialValue: accounts.any((row) => row.id == value && row.id != excludedId)
        ? value
        : null,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final account in accounts.where(
        (account) => account.id != excludedId,
      ))
        DropdownMenuItem(value: account.id, child: Text(account.name)),
    ],
    onChanged: onChanged,
  );
}

final class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.identity,
    required this.categories,
    required this.value,
    required this.onChanged,
    this.onCreate,
    this.expanded = false,
  });

  /// Cambia cuando debe reconstruirse el campo con otro valor inicial.
  final Object identity;
  final List<CategoryRecord> categories;
  final String? value;
  final ValueChanged<String?> onChanged;
  final VoidCallback? onCreate;
  final bool expanded;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    key: ValueKey((identity, categories.map((row) => row.id).join(','))),
    isExpanded: expanded,
    initialValue: categories.any((row) => row.id == value) ? value : null,
    decoration: InputDecoration(
      labelText: 'Categoría',
      suffixIcon: onCreate == null
          ? null
          : IconButton(
              tooltip: 'Crear categoría',
              onPressed: onCreate,
              icon: const Icon(Icons.add),
            ),
    ),
    items: [
      for (final category in categories)
        DropdownMenuItem(
          value: category.id,
          child: Text(category.name, overflow: TextOverflow.ellipsis),
        ),
    ],
    onChanged: onChanged,
  );
}

/// Una fila de la división: categoría e importe. El importe vive en su propio
/// campo y se copia al estado al escribir.
class _SplitRow extends StatefulWidget {
  const _SplitRow({
    required this.split,
    required this.type,
    required this.categories,
    required this.canRemove,
    required this.onCategory,
    required this.onAmount,
    required this.onRemove,
    super.key,
  });

  final SplitEntry split;
  final TransactionType type;
  final List<CategoryRecord> categories;
  final bool canRemove;
  final ValueChanged<String?> onCategory;
  final ValueChanged<String> onAmount;
  final VoidCallback onRemove;

  @override
  State<_SplitRow> createState() => _SplitRowState();
}

class _SplitRowState extends State<_SplitRow> {
  late final _amount = TextEditingController(text: widget.split.amountText);

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(
          child: _CategoryDropdown(
            identity: (widget.split.id, widget.type, widget.split.categoryId),
            categories: widget.categories,
            value: widget.split.categoryId,
            expanded: true,
            onChanged: widget.onCategory,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            controller: _amount,
            inputFormatters: [PygInputFormatter()],
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Importe'),
            onChanged: widget.onAmount,
          ),
        ),
        IconButton(
          tooltip: 'Quitar división',
          onPressed: widget.canRemove ? widget.onRemove : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
      ],
    ),
  );
}

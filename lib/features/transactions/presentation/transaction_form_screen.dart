import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/errors/user_message.dart';
import '../../../shared/widgets/async_value_view.dart';
import '../../../shared/widgets/text_prompt_dialog.dart';
import '../../merchants/merchant_autocomplete.dart';
import '../../templates/save_template_dialog.dart';
import '../../templates/template_picker_sheet.dart';
import '../data/transaction_form_service.dart';
import '../domain/ledger_models.dart';
import '../domain/payment_channel_policy.dart';
import 'amount_field.dart';
import 'transaction_form_details.dart';
import 'transaction_form_fields.dart';
import 'transaction_form_notifier.dart';
import 'transaction_form_state.dart';
import 'transaction_type_selector.dart';

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
      body: AsyncValueView(
        value: accountsAsync,
        onRetry: () => ref.invalidate(accountsProvider),
        data: (activeAccounts) {
          if (state.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.loadError != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.loadError!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _vm.retryLoad,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            );
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
                AmountField(
                  controller: _amount,
                  autofocus: widget.cloneId == null,
                ),
                const SizedBox(height: 16),
                TransactionTypeSelector(
                  type: state.type,
                  onChanged: widget.editId != null ? null : _vm.setType,
                ),
                const SizedBox(height: 16),
                if (state.needsFrom)
                  AccountField(
                    label: 'Cuenta de origen',
                    value: state.from,
                    accounts: accounts,
                    onChanged: _vm.setFrom,
                  ),
                if (state.needsFrom && state.needsTo)
                  const SizedBox(height: 12),
                if (state.needsTo)
                  AccountField(
                    label: 'Cuenta de destino',
                    value: state.to,
                    accounts: accounts,
                    excludedId: state.needsFrom ? state.from : null,
                    onChanged: _vm.setTo,
                  ),
                if (state.type != TransactionType.transfer) ...[
                  const SizedBox(height: 12),
                  if (!state.splitEnabled)
                    CategoryDropdown(
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
                      SplitRow(
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
                    if (state.splitRemainingMinor case final remaining?)
                      SplitRemaining(remainingMinor: remaining),
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
                TransactionFormDetails(
                  state: state,
                  accounts: accounts,
                  channels: channels,
                  viewModel: _vm,
                  note: _note,
                  onPickDate: _pickDate,
                ),
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
      _message(userMessage(error));
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
      _message(userMessage(error));
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
      if (mounted) _message(userMessage(error));
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
      _message(userMessage(error));
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

  void _message(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }
}

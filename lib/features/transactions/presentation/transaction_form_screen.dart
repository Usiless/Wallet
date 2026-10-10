import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../data/transaction_form_service.dart';
import '../../../core/money/pyg_input_formatter.dart';
import '../domain/ledger_models.dart';
import '../../payments/domain/pending_payment_models.dart';
import '../../payments/presentation/payment_reminder_fields.dart';
import '../domain/payment_channel_policy.dart';
import '../../merchants/merchant_autocomplete.dart';
import '../../templates/save_template_dialog.dart';
import '../../templates/template_picker_sheet.dart';
import '../../templates/scheduled_template_service.dart';
import '../../../shared/widgets/text_prompt_dialog.dart';

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

  @override
  ConsumerState<TransactionFormScreen> createState() =>
      _TransactionFormScreenState();
}

class _TransactionFormScreenState extends ConsumerState<TransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _baseline;
  bool _confirmingExit = false;
  String get _draftSnapshot => jsonEncode([
    _type.name,
    _amount.text,
    _merchant.text,
    _note.text,
    _from,
    _to,
    _category,
    _occurredAt.toIso8601String(),
    _channel.name,
    _payLater,
    _repeat,
    _installments,
    _installmentCount,
    _reminders.toJson(),
    _firstInstallmentDate?.toIso8601String(),
    _splitEnabled,
    [
      for (final split in _splits) [split.categoryId, split.amount.text],
    ],
    _alsoSaveTemplate,
    _templateName,
    _templateSchedule,
  ]);
  Future<void> _tryExit(bool didPop, Object? result) async {
    if (didPop || _confirmingExit || _saving) return;
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
    setState(() => _baseline = _draftSnapshot);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) context.pop();
  }

  final _amount = TextEditingController();
  final _merchant = TextEditingController();
  final _note = TextEditingController();
  late TransactionType _type;
  String? _from;
  String? _to;
  String? _category;
  MerchantRecord? _selectedMerchant;
  String? _awaitingCategory;
  DateTime _occurredAt = DateTime.now();
  PaymentChannel _channel = PaymentChannel.other;
  var _advanced = false;
  var _saveAnother = false;
  var _alsoSaveTemplate = false;
  var _payLater = false;
  String? _repeat;
  var _installments = false;
  var _installmentCount = 2;
  PaymentReminderSettings _reminders = const PaymentReminderSettings();
  DateTime? _firstInstallmentDate;
  late final int _bookGeneration;
  var _saving = false;
  var _templateApplied = false;
  var _loadingTemplate = false;
  String? _templateError;
  DateTime? _editingUpdatedAt;
  List<AccountRecord> _editingAccounts = [];
  List<CategoryRecord> _editingCategories = [];
  String? _originalMerchantId;
  String _templateName = '';
  Map<String, dynamic>? _templateSchedule;
  var _splitEnabled = false;
  final List<_SplitInput> _splits = [];

  @override
  void initState() {
    super.initState();
    _bookGeneration = ref.read(databaseProvider).restoreGeneration;
    _type = widget.initialType;
    _to = widget.toAccountId;
    if (widget.editId != null) _loadClone(widget.editId!);
    if (widget.cloneId != null) _loadClone(widget.cloneId!);
    if (widget.savedTemplateId != null) {
      _loadSavedTemplate(widget.savedTemplateId!);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _merchant.dispose();
    _note.dispose();
    for (final split in _splits) {
      split.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              onPressed: _saving ? null : _useTemplate,
              icon: Icon(
                _alsoSaveTemplate
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
          final accounts = [
            ...activeAccounts,
            if (widget.editId != null)
              ..._editingAccounts.where(
                (a) => !activeAccounts.any((r) => r.id == a.id),
              ),
          ];
          if (_loadingTemplate) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_templateError != null) {
            return Center(child: Text(_templateError!));
          }
          if (!_templateApplied && widget.template != null) {
            _templateApplied = true;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _applyTemplate(widget.template!, accounts),
            );
          }
          final activeCategories =
              categoriesAsync.value ?? const <CategoryRecord>[];
          final categories = [
            ...activeCategories,
            if (widget.editId != null)
              ..._editingCategories.where(
                (c) => !activeCategories.any((r) => r.id == c.id),
              ),
          ];
          final availableCategories = categories
              .where(_categoryMatchesType)
              .toList();
          if (availableCategories.any((row) => row.id == _awaitingCategory)) {
            _awaitingCategory = null;
          }
          if (!categoriesAsync.isLoading &&
              _category != _awaitingCategory &&
              !availableCategories.any((row) => row.id == _category)) {
            _category = null;
          }
          for (final split in _splits) {
            if (!categoriesAsync.isLoading &&
                !availableCategories.any((row) => row.id == split.categoryId)) {
              split.categoryId = null;
            }
          }
          if (!accounts.any((row) => row.id == _from)) _from = null;
          if (!accounts.any((row) => row.id == _to) ||
              (_type == TransactionType.transfer && _from == _to)) {
            _to = null;
          }

          final channels = PaymentChannelPolicy.allowed(
            _type,
            from: accounts.where((a) => a.id == _from).firstOrNull == null
                ? null
                : AccountType.values.byName(
                    accounts.firstWhere((a) => a.id == _from).type,
                  ),
            to: accounts.where((a) => a.id == _to).firstOrNull == null
                ? null
                : AccountType.values.byName(
                    accounts.firstWhere((a) => a.id == _to).type,
                  ),
          );
          _channel = PaymentChannelPolicy.canonical(_channel);
          if (!channels.contains(_channel)) _channel = channels.first;
          _baseline ??= _draftSnapshot;
          return Form(
            key: _formKey,
            canPop: !_saving && _baseline == _draftSnapshot,
            onPopInvokedWithResult: _tryExit,
            onChanged: () {
              if (mounted) setState(() {});
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                TextFormField(
                  controller: _amount,
                  inputFormatters: [PygInputFormatter()],
                  autofocus: widget.cloneId == null,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  style: Theme.of(context).textTheme.headlineMedium,
                  decoration: const InputDecoration(
                    prefixText: 'PYG ',
                    labelText: 'Importe',
                  ),
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
                ),
                const SizedBox(height: 16),
                if (MediaQuery.sizeOf(context).width < 420 &&
                    MediaQuery.textScalerOf(context).scale(14) > 20)
                  DropdownButtonFormField<TransactionType>(
                    initialValue: _type,
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
                    onChanged: widget.editId != null
                        ? null
                        : (value) => setState(() => _type = value ?? _type),
                  )
                else
                  SegmentedButton<TransactionType>(
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
                    selected: {_type},
                    onSelectionChanged: widget.editId != null
                        ? null
                        : (value) => setState(() {
                            _type = value.first;
                          }),
                  ),
                const SizedBox(height: 16),
                if (_needsFrom)
                  _AccountField(
                    label: 'Cuenta de origen',
                    value: _from,
                    accounts: accounts,
                    onChanged: (value) => setState(() {
                      _from = value;
                      final credit =
                          accounts
                              .where((account) => account.id == value)
                              .firstOrNull
                              ?.type ==
                          AccountType.creditCard.name;
                      if (credit) {
                        _payLater = false;
                        _repeat = null;
                      } else if (!_payLater) {
                        _installments = false;
                      }
                    }),
                  ),
                if (_needsFrom && _needsTo) const SizedBox(height: 12),
                if (_needsTo)
                  _AccountField(
                    label: 'Cuenta de destino',
                    value: _to,
                    accounts: accounts,
                    excludedId: _needsFrom ? _from : null,
                    onChanged: (value) => setState(() => _to = value),
                  ),
                if (_type != TransactionType.transfer) ...[
                  const SizedBox(height: 12),
                  if (!_splitEnabled)
                    _CategoryDropdown(
                      identity: ('category', _type, _category),
                      categories: availableCategories,
                      value: _category,
                      onCreate: _createCategory,
                      onChanged: (value) => setState(() => _category = value),
                    ),
                  TextButton.icon(
                    onPressed: categories.isEmpty
                        ? null
                        : () => _toggleSplits(categories),
                    icon: const Icon(Icons.call_split),
                    label: Text(
                      _splitEnabled
                          ? 'Usar una sola categoría'
                          : 'Dividir entre categorías',
                    ),
                  ),
                  if (_splitEnabled) ...[
                    for (var index = 0; index < _splits.length; index++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: _CategoryDropdown(
                                identity: (
                                  _splits[index],
                                  _type,
                                  _splits[index].categoryId,
                                ),
                                categories: availableCategories,
                                value: _splits[index].categoryId,
                                expanded: true,
                                onChanged: (value) =>
                                    _splits[index].categoryId = value,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                controller: _splits[index].amount,
                                inputFormatters: [PygInputFormatter()],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Importe',
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Quitar división',
                              onPressed: _splits.length <= 2
                                  ? null
                                  : () => setState(
                                      () => _splits.removeAt(index).dispose(),
                                    ),
                              icon: const Icon(Icons.remove_circle_outline),
                            ),
                          ],
                        ),
                      ),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _splits.add(_SplitInput())),
                      icon: const Icon(Icons.add),
                      label: const Text('Otra categoría'),
                    ),
                  ],
                  const SizedBox(height: 4),
                  if (_type == TransactionType.expense)
                    MerchantAutocomplete(
                      label: 'Descripción',
                      controller: _merchant,
                      onSelected: (merchant) async {
                        _selectedMerchant = merchant;
                        final previousCategory = _category;
                        final category = await ref
                            .read(merchantServiceProvider)
                            .defaultCategory(merchant.id);
                        if (mounted &&
                            _type == TransactionType.expense &&
                            _selectedMerchant?.id == merchant.id &&
                            _merchant.text == merchant.name &&
                            _category == previousCategory &&
                            !_splitEnabled) {
                          setState(() => _category = category);
                        }
                      },
                    )
                  else
                    TextFormField(
                      controller: _merchant,
                      decoration: InputDecoration(
                        labelText: _type == TransactionType.income
                            ? 'Pagador'
                            : 'Comercio',
                      ),
                    ),
                ],
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: _payLater || _installments
                      ? null
                      : () => setState(() => _advanced = !_advanced),
                  icon: Icon(
                    _advanced || _payLater || _installments
                        ? Icons.expand_less
                        : Icons.tune,
                  ),
                  label: Text(
                    _advanced || _payLater || _installments
                        ? 'Ocultar detalles'
                        : 'Más detalles',
                  ),
                ),
                if (_advanced || _payLater || _installments) ...[
                  if (_type == TransactionType.expense &&
                      (widget.editId == null || _isCreditExpense(accounts)))
                    DropdownButtonFormField<String>(
                      key: ValueKey((
                        'when',
                        _isCreditExpense(accounts),
                        _installments
                            ? 'installments'
                            : _payLater
                            ? 'later'
                            : 'now',
                      )),
                      isExpanded: true,
                      initialValue: _installments
                          ? 'installments'
                          : _payLater
                          ? 'later'
                          : 'now',
                      decoration: const InputDecoration(labelText: 'Cuándo'),
                      items: [
                        const DropdownMenuItem(
                          value: 'now',
                          child: Text('Ahora'),
                        ),
                        if (!_isCreditExpense(accounts))
                          const DropdownMenuItem(
                            value: 'later',
                            child: Text('Pagar después'),
                          ),
                        const DropdownMenuItem(
                          value: 'installments',
                          child: Text('En cuotas'),
                        ),
                      ],
                      onChanged: (value) => setState(() {
                        final credit = _isCreditExpense(accounts);
                        _installments = value == 'installments';
                        _payLater =
                            !credit && (value == 'later' || _installments);
                        _repeat = value == 'later' ? _repeat : null;
                      }),
                    ),
                  if (_installmentsOn(accounts))
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: _installmentCount,
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
                      onChanged: (value) =>
                          setState(() => _installmentCount = value ?? 2),
                    ),
                  if (_pendingOn(accounts) && !_installments)
                    DropdownButtonFormField<String?>(
                      key: ValueKey(_repeat),
                      initialValue: _repeat,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Repetir'),
                      items: const [
                        DropdownMenuItem(
                          value: null,
                          child: Text('No repetir'),
                        ),
                        DropdownMenuItem(
                          value: 'monthly',
                          child: Text('Mensual'),
                        ),
                        DropdownMenuItem(value: 'yearly', child: Text('Anual')),
                      ],
                      onChanged: (value) => setState(() => _repeat = value),
                    ),
                  if ((_installmentsOn(accounts) || _pendingOn(accounts)) &&
                      !widget.editTemplate)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        _installmentsOn(accounts)
                            ? 'Primera cuota'
                            : 'Fecha de pago',
                      ),
                      subtitle: Text(
                        MaterialLocalizations.of(
                          context,
                        ).formatShortDate(_firstInstallmentDate ?? _occurredAt),
                      ),
                      trailing: const Icon(Icons.calendar_month_outlined),
                      onTap: () async {
                        final first = _firstInstallmentDate ?? _occurredAt;
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: first,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null && mounted) {
                          setState(
                            () => _firstInstallmentDate = DateTime.utc(
                              picked.year,
                              picked.month,
                              picked.day,
                              12,
                            ),
                          );
                        }
                      },
                    ),
                  if (_pendingOn(accounts))
                    PaymentReminderFields(
                      value: _reminders,
                      onChanged: (v) => setState(() => _reminders = v),
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_today),
                    title: const Text('Fecha'),
                    subtitle: Text(
                      '${_occurredAt.day}/${_occurredAt.month}/${_occurredAt.year}',
                    ),
                    onTap: _pickDate,
                  ),
                  DropdownButtonFormField<PaymentChannel>(
                    key: ValueKey(_channel),
                    initialValue: _channel,
                    decoration: const InputDecoration(labelText: 'Canal'),
                    items: [
                      for (final channel in channels)
                        DropdownMenuItem(
                          value: channel,
                          child: Text(_channelLabel(channel)),
                        ),
                    ],
                    onChanged: (value) =>
                        setState(() => _channel = value ?? _channel),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _note,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Nota'),
                  ),
                ],
                if (!widget.editTemplate && widget.editId == null)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _saveAnother,
                    onChanged: (value) =>
                        setState(() => _saveAnother = value ?? false),
                    title: const Text('Guardar y crear otro'),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving
                      ? null
                      : () => widget.editTemplate
                            ? _saveTemplate()
                            : _save(accounts),
                  icon: const Icon(Icons.check),
                  label: Text(
                    _saving
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

  Future<void> _loadSavedTemplate(String id) async {
    _loadingTemplate = true;
    _templateError = null;
    try {
      final template = await ref.read(manualTemplateServiceProvider).read(id);
      if (template == null) throw StateError('La plantilla ya no existe.');
      if (!mounted) return;
      final f = template.fields;
      final merchantId = f['merchantId'] as String?;
      final linkedMerchant = merchantId == null
          ? null
          : await (ref
                    .read(databaseProvider)
                    .select(ref.read(databaseProvider).merchants)
                  ..where((t) => t.id.equals(merchantId)))
                .getSingleOrNull();
      if (!mounted) return;
      setState(() {
        _templateName = template.name;
        if (widget.editTemplate && f['schedule'] is Map) {
          _templateSchedule = Map<String, dynamic>.from(f['schedule'] as Map);
        }
        _type = TransactionType.values.byName(f['type'] as String);
        _amount.text = f['amountMinor'] == null
            ? ''
            : Money(f['amountMinor'] as int).format(withCode: false).trim();
        _from = f['from'] as String?;
        _to = f['to'] as String?;
        _category = f['category'] as String?;
        _selectedMerchant = linkedMerchant?.isArchived == false
            ? linkedMerchant
            : null;
        _merchant.text =
            _selectedMerchant?.name ?? f['merchant'] as String? ?? '';
        _note.text = f['note'] as String? ?? '';
        _channel = PaymentChannel.values.byName(
          f['channel'] as String? ?? 'other',
        );
        _payLater = f['payLater'] as bool? ?? false;
        _installments = f['installments'] as bool? ?? false;
        _installmentCount = f['installmentCount'] as int? ?? 2;
        _reminders = f['reminders'] is Map
            ? PaymentReminderSettings.fromJson(f['reminders'] as Map)
            : const PaymentReminderSettings();
        _splitEnabled = f['splitEnabled'] as bool? ?? false;
        for (final item in f['splits'] as List? ?? []) {
          _splits.add(
            _SplitInput(categoryId: item['category'] as String?)
              ..amount.text = item['amountMinor'] == null
                  ? ''
                  : Money(item['amountMinor'] as int)
                        .format(withCode: false)
                        .trim(),
          );
        }
        _advanced = _installments || _payLater || _note.text.isNotEmpty;
        if (widget.savedTemplateId != null) _baseline = _draftSnapshot;
      });
    } catch (error) {
      if (mounted) _templateError = '$error';
    } finally {
      if (mounted) setState(() => _loadingTemplate = false);
    }
  }

  Future<({String name, Map<String, dynamic> fields})?> _collectTemplate({
    bool afterRegistration = false,
  }) async {
    String name = _templateName;
    bool includeAmount = _amount.text.trim().isNotEmpty;
    bool automatic = _templateSchedule?['enabled'] == true;
    var reminderSettings = _reminders;
    String frequency = _templateSchedule?['frequency'] as String? ?? 'monthly';
    DateTime nextDate = _templateSchedule?['nextDate'] is String
        ? parseScheduledDate(_templateSchedule!['nextDate'] as String)
        : afterRegistration
        ? nextScheduledDate(_occurredAt, {
            'frequency': 'monthly',
            'anchorDay': _occurredAt.day,
          })
        : DateTime.now();
    final originalDate = scheduledDate(nextDate);
    final originalFrequency = frequency;
    final choice = await showSaveTemplateDialog(
      context,
      name: name,
      includeAmount: includeAmount,
      automatic: automatic,
      frequency: frequency,
      nextDate: nextDate,
      reminders: reminderSettings,
      nextDateForFrequency: afterRegistration && _templateSchedule == null
          ? (value) => nextScheduledDate(_occurredAt, {
              'frequency': value,
              'anchorDay': _occurredAt.day,
              'anchorMonth': _occurredAt.month,
            })
          : null,
    );
    if (choice == null || !mounted) return null;
    name = choice.name;
    includeAmount = choice.includeAmount;
    automatic = choice.automatic;
    frequency = choice.frequency;
    nextDate = choice.nextDate;
    reminderSettings = choice.reminders;
    final choseDate = choice.choseDate;
    try {
      final amount = includeAmount
          ? Money.parse(_amount.text).minorUnits
          : null;
      if (amount != null && amount <= 0) {
        throw const FormatException('El importe debe ser mayor que cero.');
      }
      return (
        name: name,
        fields: <String, dynamic>{
          'schedule': {
            'enabled': automatic,
            'paused':
                !automatic &&
                (_templateSchedule?['enabled'] == true ||
                    _templateSchedule?['paused'] == true),
            'frequency': frequency,
            'nextDate': scheduledDate(nextDate),
            'anchorDay':
                afterRegistration && _templateSchedule == null && !choseDate
                ? _occurredAt.day
                : originalDate == scheduledDate(nextDate) &&
                      originalFrequency == frequency
                ? (_templateSchedule?['anchorDay'] ?? nextDate.day)
                : nextDate.day,
            'anchorMonth':
                afterRegistration && _templateSchedule == null && !choseDate
                ? _occurredAt.month
                : originalDate == scheduledDate(nextDate) &&
                      originalFrequency == frequency
                ? (_templateSchedule?['anchorMonth'] ?? nextDate.month)
                : nextDate.month,
          },
          'type': _type.name,
          'amountMinor': amount,
          'from': _needsFrom ? _from : null,
          'to': _needsTo ? _to : null,
          'category': _category,
          'merchant': _merchant.text.trim(),
          'merchantId': _selectedMerchant?.name == _merchant.text
              ? _selectedMerchant?.id
              : null,
          'note': _note.text.trim(),
          'channel': _channel.name,
          'payLater': _payLater,
          'installments': _installments,
          'installmentCount': _installmentCount,
          'reminders': reminderSettings.toJson(),
          'splitEnabled': includeAmount && _splitEnabled,
          'splits': [
            if (includeAmount && _splitEnabled)
              for (final split in _splits)
                {
                  'category': split.categoryId,
                  'amountMinor': Money.parse(split.amount.text).minorUnits,
                },
          ],
        },
      );
    } catch (error) {
      if (mounted) _message('$error');
      return null;
    }
  }

  Future<void> _saveTemplate() async {
    setState(() => _saving = true);
    try {
      final template = await _collectTemplate();
      if (template == null || !mounted) return;
      await ref.read(databaseProvider).transaction(() async {
        if (_bookGeneration != ref.read(databaseProvider).restoreGeneration) {
          throw StateError(
            'La base cambió. Cerrá el formulario y volvé a abrirlo.',
          );
        }
        await ref
            .read(manualTemplateServiceProvider)
            .save(
              template.name,
              template.fields,
              id: widget.editTemplate ? widget.savedTemplateId : null,
            );
      });
      if ((template.fields['schedule'] as Map?)?['enabled'] == true &&
          (template.fields['reminders'] as Map?)?['enabled'] == true) {
        await _requestReminderPermission();
      }
      if (mounted) {
        _message('Plantilla guardada.');
        setState(() {
          _baseline = _draftSnapshot;
          _saving = false;
        });
        await WidgetsBinding.instance.endOfFrame;
        if (mounted && widget.editTemplate) context.pop();
      }
    } catch (error) {
      if (mounted) _message('$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _useTemplate() async {
    final templates = await ref.read(manualTemplateServiceProvider).list();
    if (!mounted) return;
    templates.sort((a, b) {
      final aMatches = a.fields['type'] == _type.name;
      final bMatches = b.fields['type'] == _type.name;
      if (aMatches != bMatches) return aMatches ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    final selected = await showTemplatePicker(
      context,
      templates: templates,
      offerSave: !(_payLater && _type == TransactionType.expense),
      saving: _alsoSaveTemplate,
    );
    if (selected == null || !mounted) return;
    switch (selected) {
      case ToggleSaveAsTemplate():
        setState(() => _alsoSaveTemplate = !_alsoSaveTemplate);
        return;
      case ManageTemplates():
        context.push('/templates');
        return;
      case UseTemplate():
        break;
    }
    for (final split in _splits) {
      split.dispose();
    }
    setState(() {
      _splits.clear();
      _selectedMerchant = null;
      _templateSchedule = null;
      _alsoSaveTemplate = false;
      _occurredAt = DateTime.now();
      _firstInstallmentDate = null;
    });
    await _loadSavedTemplate(selected.id);
  }

  bool get _needsFrom =>
      _type == TransactionType.expense || _type == TransactionType.transfer;
  bool get _needsTo =>
      _type == TransactionType.income || _type == TransactionType.transfer;

  bool _categoryMatchesType(CategoryRecord category) =>
      category.kind == 'both' ||
      (_type == TransactionType.income
          ? category.kind == 'income'
          : category.kind == 'expense');

  bool _pendingOn(List<AccountRecord> accounts) =>
      _payLater &&
      _type == TransactionType.expense &&
      !_isCreditExpense(accounts) &&
      widget.editId == null;

  bool _installmentsOn(List<AccountRecord> accounts) =>
      _installments &&
      _type == TransactionType.expense &&
      (_isCreditExpense(accounts) || _pendingOn(accounts));

  bool _isCreditExpense(List<AccountRecord> accounts) =>
      _type == TransactionType.expense &&
      accounts.where((account) => account.id == _from).firstOrNull?.type ==
          AccountType.creditCard.name;

  Future<void> _save(List<AccountRecord> accounts) async {
    if (!_formKey.currentState!.validate()) return;
    if (_needsFrom && _from == null || _needsTo && _to == null) {
      _message('Seleccioná las cuentas necesarias.');
      return;
    }
    try {
      setState(() => _saving = true);
      final pendingPlan = _pendingOn(accounts);
      final installments = _installmentsOn(accounts);
      final template = _alsoSaveTemplate && !pendingPlan
          ? await _collectTemplate(afterRegistration: true)
          : null;
      if (!mounted) return;
      if (_alsoSaveTemplate && !pendingPlan && template == null) {
        setState(() => _saving = false);
        return;
      }
      final service = ref.read(transactionFormServiceProvider);
      final outcome = await service.submit(
        TransactionFormValues(
          type: _type,
          amountText: _amount.text,
          occurredAt: _occurredAt,
          from: _from,
          to: _to,
          merchantText: _merchant.text,
          selectedMerchant: _selectedMerchant,
          originalMerchantId: _originalMerchantId,
          note: _note.text,
          channel: _channel,
          category: _category,
          splitEnabled: _splitEnabled,
          splits: [
            for (final split in _splits)
              (categoryId: split.categoryId, amountText: split.amount.text),
          ],
          pendingPlan: pendingPlan,
          installments: installments,
          installmentCount: _installmentCount,
          firstInstallmentDate: _firstInstallmentDate,
          repeat: _repeat,
          reminders: _reminders,
          editId: widget.editId,
          editingUpdatedAt: _editingUpdatedAt,
          bookGeneration: _bookGeneration,
          template: template,
        ),
      );
      if (outcome.requestReminderPermission) await _requestReminderPermission();
      if (!mounted) return;
      await service.rememberLastAccounts(type: _type, from: _from, to: _to);
      HapticFeedback.lightImpact();
      if (!mounted) return;
      if (_saveAnother) {
        _amount.clear();
        _merchant.clear();
        _selectedMerchant = null;
        _alsoSaveTemplate = false;
        _templateName = '';
        _note.clear();
        setState(() {
          _saving = false;
          _baseline = _draftSnapshot;
        });
        _message('Movimiento guardado.');
      } else {
        setState(() {
          _saving = false;
          _baseline = _draftSnapshot;
        });
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) context.pop();
      }
    } catch (error) {
      _message('$error');
      if (mounted) setState(() => _saving = false);
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

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (value != null && mounted) {
      setState(() {
        final old = _occurredAt;
        if (_firstInstallmentDate != null &&
            _firstInstallmentDate!.year == old.year &&
            _firstInstallmentDate!.month == old.month &&
            _firstInstallmentDate!.day == old.day) {
          _firstInstallmentDate = DateTime.utc(
            value.year,
            value.month,
            value.day,
            12,
          );
        }
        _occurredAt = DateTime(
          value.year,
          value.month,
          value.day,
          _occurredAt.hour,
          _occurredAt.minute,
        );
      });
    }
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
      final id = await ref
          .read(categoryServiceProvider)
          .create(
            value,
            kind: _type == TransactionType.income ? 'income' : 'expense',
          );
      if (mounted) {
        setState(() {
          _awaitingCategory = id;
          _category = id;
        });
      }
    } catch (error) {
      _message('$error');
    }
  }

  void _toggleSplits(List<CategoryRecord> categories) {
    setState(() {
      _splitEnabled = !_splitEnabled;
      if (_splitEnabled && _splits.isEmpty) {
        _splits.addAll([
          _SplitInput(
            categoryId:
                _category ??
                categories.where(_categoryMatchesType).firstOrNull?.id,
          ),
          _SplitInput(),
        ]);
      }
    });
  }

  void _applyTemplate(String template, List<AccountRecord> accounts) {
    if (!mounted) return;
    setState(() {
      if (template == 'cardPayment') {
        _type = TransactionType.transfer;
        _from = accounts
            .where((account) => account.type == AccountType.bank.name)
            .firstOrNull
            ?.id;
        _to ??= accounts
            .where((account) => account.type == AccountType.creditCard.name)
            .firstOrNull
            ?.id;
      }
      _baseline = _draftSnapshot;
    });
  }

  Future<void> _loadClone(String id) async {
    final database = ref.read(databaseProvider);
    setState(() => _loadingTemplate = true);
    try {
      final row = await (database.select(
        database.ledgerTransactions,
      )..where((t) => t.id.equals(id))).getSingleOrNull();
      if (row == null || row.status != 'confirmed') {
        throw StateError('El movimiento ya no está disponible.');
      }
      final splits = await (database.select(
        database.transactionSplits,
      )..where((t) => t.transactionId.equals(id))).get();
      final plan = await (database.select(
        database.installmentPlans,
      )..where((t) => t.transactionId.equals(id))).getSingleOrNull();
      final merchant = row.merchantId == null
          ? null
          : await (database.select(
              database.merchants,
            )..where((t) => t.id.equals(row.merchantId!))).getSingleOrNull();
      final oldAccounts =
          await (database.select(database.accounts)..where(
                (t) => t.id.isIn(
                  [row.fromAccountId, row.toAccountId].whereType<String>(),
                ),
              ))
              .get();
      final oldCategories = await (database.select(
        database.categories,
      )..where((t) => t.id.isIn(splits.map((s) => s.categoryId)))).get();
      if (!mounted) return;
      setState(() {
        _editingAccounts = oldAccounts;
        _editingCategories = oldCategories;
        _type = TransactionType.values.byName(row.type);
        _amount.text = Money(row.amountMinor).format(withCode: false).trim();
        _originalMerchantId = widget.editId != null ? row.merchantId : null;
        _selectedMerchant =
            widget.editId != null || merchant?.isArchived == false
            ? merchant
            : null;
        _merchant.text = _selectedMerchant?.name ?? row.description;
        _note.text = row.note;
        _from = row.fromAccountId;
        _to = row.toAccountId;
        _channel = PaymentChannel.values.byName(row.paymentChannel);
        _occurredAt = widget.editId != null
            ? row.occurredAt.toLocal()
            : DateTime.now();
        _editingUpdatedAt = row.updatedAt;
        _installments = plan != null;
        _installmentCount = plan?.installmentCount ?? 2;
        _firstInstallmentDate = widget.editId != null
            ? plan?.firstPeriod.toUtc()
            : null;
        _splitEnabled = splits.length > 1;
        _category = splits.length == 1 ? splits.single.categoryId : null;
        for (final split in splits.where((_) => _splitEnabled)) {
          _splits.add(
            _SplitInput(categoryId: split.categoryId)
              ..amount.text = Money(split.amountMinor)
                  .format(withCode: false)
                  .trim(),
          );
        }
        _advanced = true;
        _baseline = _draftSnapshot;
      });
    } catch (error) {
      if (mounted) _templateError = '$error';
    } finally {
      if (mounted) setState(() => _loadingTemplate = false);
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

final class _SplitInput {
  _SplitInput({this.categoryId}) : amount = TextEditingController();

  String? categoryId;
  final TextEditingController amount;

  void dispose() => amount.dispose();
}

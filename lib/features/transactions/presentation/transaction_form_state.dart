import 'dart:convert';

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../../payments/domain/pending_payment_models.dart';
import '../../templates/manual_template_service.dart';
import '../../templates/save_template_dialog.dart';
import '../../templates/scheduled_template_service.dart';
import '../data/ledger_repository.dart';
import '../data/transaction_form_service.dart';
import '../domain/ledger_models.dart';
import '../domain/payment_channel_policy.dart';

const _keep = Object();

/// División de un gasto entre categorías; [id] estable para identificar la fila.
typedef SplitEntry = ({int id, String? categoryId, String amountText});

String _plain(int minor) => Money(minor).format(withCode: false).trim();

/// Estado completo del formulario de movimiento: lo que se ve, lo que se
/// escribió y lo necesario para guardar. Inmutable; los cambios crean otro.
final class TransactionFormState {
  const TransactionFormState({
    required this.type,
    this.isEdit = false,
    this.isTemplateEdit = false,
    this.amountText = '',
    this.merchantText = '',
    this.noteText = '',
    this.from,
    this.to,
    this.category,
    this.selectedMerchant,
    this.awaitingCategory,
    required this.occurredAt,
    this.channel = PaymentChannel.other,
    this.advanced = false,
    this.saveAnother = false,
    this.alsoSaveTemplate = false,
    this.payLater = false,
    this.repeat,
    this.installments = false,
    this.installmentCount = 2,
    this.reminders = const PaymentReminderSettings(),
    this.firstInstallmentDate,
    this.splitEnabled = false,
    this.splits = const [],
    this.nextSplitId = 0,
    this.templateName = '',
    this.templateSchedule,
    this.originalMerchantId,
    this.editingUpdatedAt,
    this.editingAccounts = const [],
    this.editingCategories = const [],
    this.saving = false,
    this.loading = false,
    this.loadError,
    this.baseline,
    this.textRevision = 0,
  });

  final TransactionType type;
  final bool isEdit, isTemplateEdit;
  final String amountText, merchantText, noteText;
  final String? from, to, category;
  final MerchantRecord? selectedMerchant;

  /// Categoría recién creada que aún no aparece en la lista cargada.
  final String? awaitingCategory;
  final DateTime occurredAt;
  final PaymentChannel channel;
  final bool advanced, saveAnother, alsoSaveTemplate, payLater;
  final String? repeat;
  final bool installments;
  final int installmentCount;
  final PaymentReminderSettings reminders;
  final DateTime? firstInstallmentDate;
  final bool splitEnabled;
  final List<SplitEntry> splits;
  final int nextSplitId;
  final String templateName;
  final Map<String, dynamic>? templateSchedule;
  final String? originalMerchantId;
  final DateTime? editingUpdatedAt;
  final List<AccountRecord> editingAccounts;
  final List<CategoryRecord> editingCategories;
  final bool saving, loading;
  final String? loadError;

  /// Foto del borrador al abrir, guardar o descartar; ver [isDirty].
  final String? baseline;

  /// Sube cuando el estado cambia los textos por su cuenta (cargas, limpieza):
  /// la vista debe copiarlos a sus campos.
  final int textRevision;

  TransactionFormState copyWith({
    TransactionType? type,
    String? amountText,
    String? merchantText,
    String? noteText,
    Object? from = _keep,
    Object? to = _keep,
    Object? category = _keep,
    Object? selectedMerchant = _keep,
    Object? awaitingCategory = _keep,
    DateTime? occurredAt,
    PaymentChannel? channel,
    bool? advanced,
    bool? saveAnother,
    bool? alsoSaveTemplate,
    bool? payLater,
    Object? repeat = _keep,
    bool? installments,
    int? installmentCount,
    PaymentReminderSettings? reminders,
    Object? firstInstallmentDate = _keep,
    bool? splitEnabled,
    List<SplitEntry>? splits,
    int? nextSplitId,
    String? templateName,
    Object? templateSchedule = _keep,
    Object? originalMerchantId = _keep,
    Object? editingUpdatedAt = _keep,
    List<AccountRecord>? editingAccounts,
    List<CategoryRecord>? editingCategories,
    bool? saving,
    bool? loading,
    Object? loadError = _keep,
    Object? baseline = _keep,
    int? textRevision,
  }) => TransactionFormState(
    type: type ?? this.type,
    isEdit: isEdit,
    isTemplateEdit: isTemplateEdit,
    amountText: amountText ?? this.amountText,
    merchantText: merchantText ?? this.merchantText,
    noteText: noteText ?? this.noteText,
    from: identical(from, _keep) ? this.from : from as String?,
    to: identical(to, _keep) ? this.to : to as String?,
    category: identical(category, _keep) ? this.category : category as String?,
    selectedMerchant: identical(selectedMerchant, _keep)
        ? this.selectedMerchant
        : selectedMerchant as MerchantRecord?,
    awaitingCategory: identical(awaitingCategory, _keep)
        ? this.awaitingCategory
        : awaitingCategory as String?,
    occurredAt: occurredAt ?? this.occurredAt,
    channel: channel ?? this.channel,
    advanced: advanced ?? this.advanced,
    saveAnother: saveAnother ?? this.saveAnother,
    alsoSaveTemplate: alsoSaveTemplate ?? this.alsoSaveTemplate,
    payLater: payLater ?? this.payLater,
    repeat: identical(repeat, _keep) ? this.repeat : repeat as String?,
    installments: installments ?? this.installments,
    installmentCount: installmentCount ?? this.installmentCount,
    reminders: reminders ?? this.reminders,
    firstInstallmentDate: identical(firstInstallmentDate, _keep)
        ? this.firstInstallmentDate
        : firstInstallmentDate as DateTime?,
    splitEnabled: splitEnabled ?? this.splitEnabled,
    splits: splits ?? this.splits,
    nextSplitId: nextSplitId ?? this.nextSplitId,
    templateName: templateName ?? this.templateName,
    templateSchedule: identical(templateSchedule, _keep)
        ? this.templateSchedule
        : templateSchedule as Map<String, dynamic>?,
    originalMerchantId: identical(originalMerchantId, _keep)
        ? this.originalMerchantId
        : originalMerchantId as String?,
    editingUpdatedAt: identical(editingUpdatedAt, _keep)
        ? this.editingUpdatedAt
        : editingUpdatedAt as DateTime?,
    editingAccounts: editingAccounts ?? this.editingAccounts,
    editingCategories: editingCategories ?? this.editingCategories,
    saving: saving ?? this.saving,
    loading: loading ?? this.loading,
    loadError: identical(loadError, _keep)
        ? this.loadError
        : loadError as String?,
    baseline: identical(baseline, _keep) ? this.baseline : baseline as String?,
    textRevision: textRevision ?? this.textRevision,
  );

  // --- derivados ---

  bool get needsFrom =>
      type == TransactionType.expense || type == TransactionType.transfer;
  bool get needsTo =>
      type == TransactionType.income || type == TransactionType.transfer;

  bool categoryMatchesType(CategoryRecord category) =>
      category.kind == 'both' ||
      (type == TransactionType.income
          ? category.kind == 'income'
          : category.kind == 'expense');

  bool isCreditExpense(List<AccountRecord> accounts) =>
      type == TransactionType.expense &&
      accounts.where((account) => account.id == from).firstOrNull?.type ==
          AccountType.creditCard.name;

  /// «Pagar después» vigente: prepara pendientes en lugar de registrar el gasto.
  bool pendingOn(List<AccountRecord> accounts) =>
      payLater &&
      type == TransactionType.expense &&
      !isCreditExpense(accounts) &&
      !isEdit;

  bool installmentsOn(List<AccountRecord> accounts) =>
      installments &&
      type == TransactionType.expense &&
      (isCreditExpense(accounts) || pendingOn(accounts));

  /// Texto que identifica el borrador; si cambia respecto de [baseline] hay
  /// cambios sin guardar.
  String get draftSnapshot => jsonEncode([
    type.name,
    amountText,
    merchantText,
    noteText,
    from,
    to,
    category,
    occurredAt.toIso8601String(),
    channel.name,
    payLater,
    repeat,
    installments,
    installmentCount,
    reminders.toJson(),
    firstInstallmentDate?.toIso8601String(),
    splitEnabled,
    [
      for (final split in splits) [split.categoryId, split.amountText],
    ],
    alsoSaveTemplate,
    templateName,
    templateSchedule,
  ]);

  bool get isDirty => baseline != null && baseline != draftSnapshot;

  TransactionFormState markClean() => copyWith(baseline: draftSnapshot);

  /// Cuentas visibles: las activas más, al editar, las del movimiento aunque
  /// estén archivadas.
  List<AccountRecord> accountsFrom(List<AccountRecord> active) => [
    ...active,
    if (isEdit)
      ...editingAccounts.where((a) => !active.any((r) => r.id == a.id)),
  ];

  List<CategoryRecord> categoriesFrom(List<CategoryRecord> active) => [
    ...active,
    if (isEdit)
      ...editingCategories.where((c) => !active.any((r) => r.id == c.id)),
  ];

  /// Corrige lo que dejó de ser válido: categorías o cuentas que ya no existen,
  /// destino igual al origen y canal no permitido para el tipo y las cuentas.
  TransactionFormState normalized({
    required List<AccountRecord> accounts,
    required List<CategoryRecord> categories,
    required bool categoriesLoading,
  }) {
    final available = categories.where(categoryMatchesType).toList();
    var awaiting = awaitingCategory;
    if (available.any((row) => row.id == awaiting)) awaiting = null;
    var nextCategory = category;
    if (!categoriesLoading &&
        nextCategory != awaiting &&
        !available.any((row) => row.id == nextCategory)) {
      nextCategory = null;
    }
    final nextSplits = [
      for (final split in splits)
        !categoriesLoading &&
                !available.any((row) => row.id == split.categoryId)
            ? (id: split.id, categoryId: null, amountText: split.amountText)
            : split,
    ];
    final nextFrom = accounts.any((row) => row.id == from) ? from : null;
    final nextTo =
        !accounts.any((row) => row.id == to) ||
            (type == TransactionType.transfer && nextFrom == to)
        ? null
        : to;
    AccountType? typeOf(String? id) {
      final account = accounts.where((a) => a.id == id).firstOrNull;
      return account == null ? null : AccountType.values.byName(account.type);
    }

    final channels = PaymentChannelPolicy.allowed(
      type,
      from: typeOf(nextFrom),
      to: typeOf(nextTo),
    );
    var nextChannel = PaymentChannelPolicy.canonical(channel);
    if (!channels.contains(nextChannel)) nextChannel = channels.first;
    final sameSplits = [
      for (var i = 0; i < splits.length; i++) splits[i] == nextSplits[i],
    ].every((same) => same);
    if (awaiting == awaitingCategory &&
        nextCategory == category &&
        sameSplits &&
        nextFrom == from &&
        nextTo == to &&
        nextChannel == channel) {
      return this;
    }
    return copyWith(
      awaitingCategory: awaiting,
      category: nextCategory,
      splits: nextSplits,
      from: nextFrom,
      to: nextTo,
      channel: nextChannel,
    );
  }

  // --- cargas ---

  /// Aplica un movimiento existente (editar o clonar).
  TransactionFormState withMovement(MovementFormSource source) {
    final row = source.transaction;
    final merchant = source.merchant;
    final splits = source.splits;
    final plan = source.plan;
    final selected = isEdit || merchant?.isArchived == false ? merchant : null;
    final multi = splits.length > 1;
    var nextId = nextSplitId;
    final entries = [
      ...this.splits,
      if (multi)
        for (final split in splits)
          (
            id: nextId++,
            categoryId: split.categoryId,
            amountText: _plain(split.amountMinor),
          ),
    ];
    return copyWith(
      editingAccounts: source.accounts,
      editingCategories: source.categories,
      type: TransactionType.values.byName(row.type),
      amountText: _plain(row.amountMinor),
      originalMerchantId: isEdit ? row.merchantId : null,
      selectedMerchant: selected,
      merchantText: selected?.name ?? row.description,
      noteText: row.note,
      from: row.fromAccountId,
      to: row.toAccountId,
      channel: PaymentChannel.values.byName(row.paymentChannel),
      occurredAt: isEdit ? row.occurredAt.toLocal() : DateTime.now(),
      editingUpdatedAt: row.updatedAt,
      installments: plan != null,
      installmentCount: plan?.installmentCount ?? 2,
      firstInstallmentDate: isEdit ? plan?.firstPeriod.toUtc() : null,
      splitEnabled: multi,
      category: splits.length == 1 ? splits.single.categoryId : null,
      splits: entries,
      nextSplitId: nextId,
      advanced: true,
      textRevision: textRevision + 1,
    ).markClean();
  }

  /// Aplica una plantilla guardada. [linkedMerchant] es el comercio que la
  /// plantilla tenía asociado, si todavía existe.
  TransactionFormState withTemplate(
    ManualTemplate template,
    MerchantRecord? linkedMerchant, {
    required bool markClean,
  }) {
    final f = template.fields;
    final selected = linkedMerchant?.isArchived == false
        ? linkedMerchant
        : null;
    final nextNote = f['note'] as String? ?? '';
    final nextPayLater = f['payLater'] as bool? ?? false;
    final nextInstallments = f['installments'] as bool? ?? false;
    var nextId = nextSplitId;
    final entries = [
      ...splits,
      for (final item in f['splits'] as List? ?? [])
        (
          id: nextId++,
          categoryId: item['category'] as String?,
          amountText: item['amountMinor'] == null
              ? ''
              : _plain(item['amountMinor'] as int),
        ),
    ];
    final next = copyWith(
      templateName: template.name,
      templateSchedule: isTemplateEdit && f['schedule'] is Map
          ? Map<String, dynamic>.from(f['schedule'] as Map)
          : templateSchedule,
      type: TransactionType.values.byName(f['type'] as String),
      amountText: f['amountMinor'] == null
          ? ''
          : _plain(f['amountMinor'] as int),
      from: f['from'] as String?,
      to: f['to'] as String?,
      category: f['category'] as String?,
      selectedMerchant: selected,
      merchantText: selected?.name ?? f['merchant'] as String? ?? '',
      noteText: nextNote,
      channel: PaymentChannel.values.byName(f['channel'] as String? ?? 'other'),
      payLater: nextPayLater,
      installments: nextInstallments,
      installmentCount: f['installmentCount'] as int? ?? 2,
      reminders: f['reminders'] is Map
          ? PaymentReminderSettings.fromJson(f['reminders'] as Map)
          : const PaymentReminderSettings(),
      splitEnabled: f['splitEnabled'] as bool? ?? false,
      splits: entries,
      nextSplitId: nextId,
      advanced: nextInstallments || nextPayLater || nextNote.isNotEmpty,
      textRevision: textRevision + 1,
    );
    return markClean ? next.markClean() : next;
  }

  // --- guardado ---

  /// Valores para el servicio de guardado.
  TransactionFormValues toValues({
    required List<AccountRecord> accounts,
    required int bookGeneration,
    String? editId,
    TemplateToSave? template,
  }) => TransactionFormValues(
    type: type,
    amountText: amountText,
    occurredAt: occurredAt,
    from: from,
    to: to,
    merchantText: merchantText,
    selectedMerchant: selectedMerchant,
    originalMerchantId: originalMerchantId,
    note: noteText,
    channel: channel,
    category: category,
    splitEnabled: splitEnabled,
    splits: [
      for (final split in splits)
        (categoryId: split.categoryId, amountText: split.amountText),
    ],
    pendingPlan: pendingOn(accounts),
    installments: installmentsOn(accounts),
    installmentCount: installmentCount,
    firstInstallmentDate: firstInstallmentDate,
    repeat: repeat,
    reminders: reminders,
    editId: editId,
    editingUpdatedAt: editingUpdatedAt,
    bookGeneration: bookGeneration,
    template: template,
  );

  /// Valores iniciales del diálogo «Guardar plantilla».
  ({
    bool includeAmount,
    bool automatic,
    String frequency,
    DateTime nextDate,
    DateTime Function(String frequency)? nextDateForFrequency,
  })
  templateDefaults({required bool afterRegistration}) {
    final schedule = templateSchedule;
    final frequency = schedule?['frequency'] as String? ?? 'monthly';
    final nextDate = schedule?['nextDate'] is String
        ? parseScheduledDate(schedule!['nextDate'] as String)
        : afterRegistration
        ? nextScheduledDate(occurredAt, {
            'frequency': 'monthly',
            'anchorDay': occurredAt.day,
          })
        : DateTime.now();
    return (
      includeAmount: amountText.trim().isNotEmpty,
      automatic: schedule?['enabled'] == true,
      frequency: frequency,
      nextDate: nextDate,
      nextDateForFrequency: afterRegistration && schedule == null
          ? (value) => nextScheduledDate(occurredAt, {
              'frequency': value,
              'anchorDay': occurredAt.day,
              'anchorMonth': occurredAt.month,
            })
          : null,
    );
  }

  /// Plantilla a guardar a partir de lo elegido en el diálogo. [originalNextDate]
  /// y [originalFrequency] son los valores con que se abrió el diálogo.
  /// Lanza [FormatException] si el importe recordado no es válido.
  TemplateToSave templateFrom(
    SaveTemplateChoice choice, {
    required bool afterRegistration,
    required DateTime originalNextDate,
    required String originalFrequency,
  }) {
    final amount = choice.includeAmount
        ? Money.parse(amountText).minorUnits
        : null;
    if (amount != null && amount <= 0) {
      throw const FormatException('El importe debe ser mayor que cero.');
    }
    final schedule = templateSchedule;
    final nextDate = choice.nextDate;
    final unchanged =
        scheduledDate(originalNextDate) == scheduledDate(nextDate) &&
        originalFrequency == choice.frequency;
    final fromCreation =
        afterRegistration && schedule == null && !choice.choseDate;
    final includeSplits = choice.includeAmount && splitEnabled;
    return (
      name: choice.name,
      fields: <String, dynamic>{
        'schedule': {
          'enabled': choice.automatic,
          'paused':
              !choice.automatic &&
              (schedule?['enabled'] == true || schedule?['paused'] == true),
          'frequency': choice.frequency,
          'nextDate': scheduledDate(nextDate),
          'anchorDay': fromCreation
              ? occurredAt.day
              : unchanged
              ? (schedule?['anchorDay'] ?? nextDate.day)
              : nextDate.day,
          'anchorMonth': fromCreation
              ? occurredAt.month
              : unchanged
              ? (schedule?['anchorMonth'] ?? nextDate.month)
              : nextDate.month,
        },
        'type': type.name,
        'amountMinor': amount,
        'from': needsFrom ? from : null,
        'to': needsTo ? to : null,
        'category': category,
        'merchant': merchantText.trim(),
        'merchantId': selectedMerchant?.name == merchantText
            ? selectedMerchant?.id
            : null,
        'note': noteText.trim(),
        'channel': channel.name,
        'payLater': payLater,
        'installments': installments,
        'installmentCount': installmentCount,
        'reminders': choice.reminders.toJson(),
        'splitEnabled': includeSplits,
        'splits': [
          if (includeSplits)
            for (final split in splits)
              {
                'category': split.categoryId,
                'amountMinor': Money.parse(split.amountText).minorUnits,
              },
        ],
      },
    );
  }
}

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../../../core/settings/settings_repository.dart';
import '../../installments/domain/installment_service.dart';
import '../../merchants/merchant_service.dart';
import '../../payments/domain/pending_payment_service.dart';
import '../../templates/manual_template_service.dart';
import '../../templates/scheduled_template_service.dart';
import '../domain/ledger_models.dart';
import 'category_service.dart';
import 'ledger_service.dart';

/// Plantilla recogida en el diálogo «Guardar plantilla».
typedef TemplateToSave = ({String name, Map<String, dynamic> fields});

/// Valores del formulario de movimiento, ya leídos de los campos.
final class TransactionFormValues {
  const TransactionFormValues({
    required this.type,
    required this.amountText,
    required this.occurredAt,
    required this.merchantText,
    required this.note,
    required this.channel,
    required this.splitEnabled,
    required this.splits,
    required this.pendingPlan,
    required this.installments,
    required this.installmentCount,
    required this.reminders,
    required this.bookGeneration,
    this.from,
    this.to,
    this.selectedMerchant,
    this.originalMerchantId,
    this.category,
    this.firstInstallmentDate,
    this.repeat,
    this.editId,
    this.editingUpdatedAt,
    this.template,
  });

  final TransactionType type;
  final String amountText;
  final DateTime occurredAt;
  final String? from, to;
  final String merchantText;

  /// Comercio elegido de la lista; solo vale si su nombre coincide con el texto.
  final MerchantRecord? selectedMerchant;
  final String? originalMerchantId;
  final String note;
  final PaymentChannel channel;
  final String? category;
  final bool splitEnabled;
  final List<({String? categoryId, String amountText})> splits;

  /// «Pagar después»: prepara pendientes en lugar de registrar el gasto.
  final bool pendingPlan;
  final bool installments;
  final int installmentCount;
  final DateTime? firstInstallmentDate;

  /// `monthly` o `yearly` al repetir un pendiente; `null` si no se repite.
  final String? repeat;
  final PaymentReminderSettings reminders;

  /// Identificador de la edición, o `null` si se crea un movimiento.
  final String? editId;
  final DateTime? editingUpdatedAt;
  final int bookGeneration;
  final TemplateToSave? template;

  bool get needsFrom =>
      type == TransactionType.expense || type == TransactionType.transfer;
  bool get needsTo =>
      type == TransactionType.income || type == TransactionType.transfer;
}

final class TransactionFormResult {
  const TransactionFormResult({required this.requestReminderPermission});

  /// La interfaz debe pedir el permiso de avisos del sistema.
  final bool requestReminderPermission;
}

/// Reglas de guardado del formulario: validaciones, comercio, divisiones,
/// plantillas y plan de cuotas, todo en una transacción de base de datos.
final class TransactionFormService {
  TransactionFormService({
    required this.database,
    required this.ledger,
    required this.installmentService,
    required this.merchants,
    required this.categories,
    required this.pendingPayments,
    required this.templates,
    required this.scheduledTemplates,
    required this.settings,
  });

  final AppDatabase database;
  final LedgerService ledger;
  final InstallmentService installmentService;
  final MerchantService merchants;
  final CategoryService categories;
  final PendingPaymentService pendingPayments;
  final ManualTemplateService templates;
  final ScheduledTemplateService scheduledTemplates;
  final SettingsRepository settings;

  /// Contador de restauraciones: un formulario abierto antes de restaurar
  /// los datos ya no puede guardar.
  int get bookGeneration => database.restoreGeneration;

  Future<void> saveTemplate(
    TemplateToSave template, {
    required int bookGeneration,
    String? id,
  }) => database.transaction(() async {
    if (bookGeneration != database.restoreGeneration) {
      throw StateError(
        'La base cambió. Cerrá el formulario y volvé a abrirlo.',
      );
    }
    await templates.save(template.name, template.fields, id: id);
  });

  Future<TransactionFormResult> submit(TransactionFormValues values) async {
    final money = Money.parse(values.amountText);
    final installments = values.installments;
    if (installments &&
        (money.minorUnits < values.installmentCount ||
            values.installmentCount < 2 ||
            values.installmentCount > 120)) {
      throw const FormatException('Importe o cuotas inválidos.');
    }
    if (values.pendingPlan && values.merchantText.trim().isEmpty) {
      throw const FormatException('Ingresá una descripción.');
    }
    final repeats =
        values.pendingPlan && values.repeat != null && !installments;
    await database.transaction(() async {
      if (values.bookGeneration != database.restoreGeneration) {
        throw StateError(
          'Los datos fueron restaurados. Cancelá y volvé a abrir el formulario.',
        );
      }
      final merchantId = await _resolveMerchant(values);
      final splits = _buildSplits(values, money);
      await _rememberCategory(values, merchantId);
      if (repeats) {
        await _saveRepeatTemplate(values, money, merchantId, splits);
      } else if (values.pendingPlan) {
        await pendingPayments.createPlan(
          amountMinor: money.minorUnits,
          installmentCount: installments ? values.installmentCount : 1,
          firstDueDate: values.firstInstallmentDate ?? values.occurredAt,
          accountId: values.from!,
          merchantId: merchantId,
          description: values.merchantText.trim(),
          note: values.note,
          paymentChannel: values.channel,
          splits: splits,
          reminders: values.reminders,
          occurredAt: values.occurredAt,
          expectedBookGeneration: values.bookGeneration,
        );
      } else {
        await _saveMovement(values, money, merchantId, splits);
      }
    });
    if (repeats) await scheduledTemplates.processDue();
    final template = values.template;
    return TransactionFormResult(
      requestReminderPermission:
          (values.pendingPlan && values.reminders.enabled) ||
          ((template?.fields['schedule'] as Map?)?['enabled'] == true &&
              (template?.fields['reminders'] as Map?)?['enabled'] == true),
    );
  }

  /// Recuerda las últimas cuentas usadas para proponerlas en el próximo registro.
  Future<void> rememberLastAccounts({
    required TransactionType type,
    String? from,
    String? to,
  }) async {
    if (from != null) await settings.write('last_from_${type.name}', from);
    if (to != null) await settings.write('last_to_${type.name}', to);
  }

  Future<String?> _resolveMerchant(TransactionFormValues values) async {
    if (values.merchantText.trim().isEmpty) return null;
    final selected = values.selectedMerchant;
    if (values.type == TransactionType.expense &&
        selected?.name == values.merchantText) {
      final current = await merchants.byId(selected!.id);
      if (current.isArchived && current.id != values.originalMerchantId) {
        throw StateError('El comercio está archivado.');
      }
      return current.id;
    }
    return merchants.findOrCreate(values.merchantText);
  }

  List<SplitDraft> _buildSplits(TransactionFormValues values, Money money) {
    if (values.type == TransactionType.transfer) return const [];
    if (values.splitEnabled) {
      return [
        for (final input in values.splits)
          if (input.categoryId == null)
            throw const FormatException('Elegí todas las categorías.')
          else
            SplitDraft(
              categoryId: input.categoryId!,
              amountMinor: Money.parse(input.amountText).minorUnits,
            ),
      ];
    }
    final category = values.category;
    return [
      if (category != null)
        SplitDraft(categoryId: category, amountMinor: money.minorUnits),
    ];
  }

  Future<void> _rememberCategory(
    TransactionFormValues values,
    String? merchantId,
  ) async {
    if (values.type != TransactionType.expense ||
        merchantId == null ||
        values.splitEnabled) {
      return;
    }
    final category = values.category;
    if (category != null) {
      final active = await categories.find(category);
      if (active == null || active.isArchived) return;
    }
    await merchants.rememberCategory(merchantId, category);
  }

  Future<void> _saveRepeatTemplate(
    TransactionFormValues values,
    Money money,
    String? merchantId,
    List<SplitDraft> splits,
  ) async {
    final first = values.firstInstallmentDate ?? values.occurredAt;
    final name = values.merchantText.trim();
    await templates.save(name, {
      'schedule': {
        'enabled': true,
        'paused': false,
        'frequency': values.repeat,
        'nextDate': scheduledDate(first),
        'anchorDay': first.day,
        'anchorMonth': first.month,
      },
      'type': values.type.name,
      'amountMinor': money.minorUnits,
      'from': values.from,
      'to': null,
      'category': splits.length == 1 ? splits.single.categoryId : null,
      'merchant': name,
      'merchantId': merchantId,
      'note': values.note.trim(),
      'channel': values.channel.name,
      'payLater': true,
      'installments': false,
      'installmentCount': 2,
      'reminders': values.reminders.toJson(),
      'splitEnabled': splits.length > 1,
      'splits': [
        if (splits.length > 1)
          for (final split in splits)
            {'category': split.categoryId, 'amountMinor': split.amountMinor},
      ],
    });
  }

  Future<void> _saveMovement(
    TransactionFormValues values,
    Money money,
    String? merchantId,
    List<SplitDraft> splits,
  ) async {
    final template = values.template;
    String? templateId;
    Map<String, dynamic>? schedule;
    if (template != null) {
      final fields = {...template.fields, 'merchantId': merchantId};
      templateId = await templates.save(template.name, fields);
      schedule = Map<String, dynamic>.from(fields['schedule'] as Map);
    }
    final occurredDate = scheduledDate(values.occurredAt);
    final consumesDue =
        schedule?['enabled'] == true && schedule?['nextDate'] == occurredDate;
    final draft = TransactionDraft(
      type: values.type,
      amount: money,
      occurredAt: values.occurredAt,
      fromAccountId: values.needsFrom ? values.from : null,
      toAccountId: values.needsTo ? values.to : null,
      merchantId: merchantId,
      description: values.merchantText.trim(),
      note: values.note,
      paymentChannel: values.channel,
      splits: splits,
      externalFingerprint: consumesDue
          ? 'scheduled:$templateId:$occurredDate'
          : null,
      sourceReference: templateId,
    );
    final editId = values.editId;
    final String id;
    if (editId != null) {
      id = editId;
      await ledger.update(
        id,
        draft,
        expectedUpdatedAt: values.editingUpdatedAt,
        installmentCount: values.installments ? values.installmentCount : null,
        preserveInstallments: false,
        firstInstallmentDate: values.firstInstallmentDate ?? values.occurredAt,
      );
    } else {
      id = await ledger.create(draft);
    }
    if (values.installments && editId == null) {
      await installmentService.attachPlan(
        transactionId: id,
        count: values.installmentCount,
        firstPeriod: values.firstInstallmentDate ?? values.occurredAt,
      );
    }
    if (consumesDue &&
        template != null &&
        templateId != null &&
        schedule != null) {
      schedule['nextDate'] = scheduledDate(
        nextScheduledDate(
          parseScheduledDate(schedule['nextDate'] as String),
          schedule,
        ),
      );
      await templates.save(template.name, {
        ...template.fields,
        'merchantId': merchantId,
        'schedule': schedule,
      }, id: templateId);
    }
  }
}

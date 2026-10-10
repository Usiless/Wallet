import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/database/app_database.dart';
import '../../payments/domain/pending_payment_models.dart';
import '../../templates/manual_template_service.dart';
import '../data/transaction_form_service.dart';
import '../domain/ledger_models.dart';
import 'transaction_form_state.dart';

/// Con qué se abrió el formulario; identifica una instancia del ViewModel.
typedef TransactionFormArgs = ({
  TransactionType initialType,
  String? template,
  String? cloneId,
  String? editId,
  String? toAccountId,
  String? savedTemplateId,
  bool editTemplate,
});

final transactionFormProvider = NotifierProvider.autoDispose
    .family<TransactionFormNotifier, TransactionFormState, TransactionFormArgs>(
      TransactionFormNotifier.new,
    );

/// ViewModel del formulario de movimiento: mantiene el estado, aplica las
/// reglas y orquesta los servicios. Los diálogos y la navegación son de la vista.
class TransactionFormNotifier extends Notifier<TransactionFormState> {
  TransactionFormNotifier(this.args);

  final TransactionFormArgs args;

  /// Contador de restauraciones al abrir: si cambia, el formulario ya no guarda.
  int bookGeneration = 0;
  bool _templateApplied = false;

  @override
  TransactionFormState build() {
    bookGeneration = ref.read(transactionFormServiceProvider).bookGeneration;
    ref.listen(accountsProvider, (_, _) => _normalize());
    ref.listen(categoriesProvider, (_, _) => _normalize());
    final loadsSomething =
        args.editId != null ||
        args.cloneId != null ||
        args.savedTemplateId != null;
    Future.microtask(_start);
    return TransactionFormState(
      type: args.initialType,
      occurredAt: DateTime.now(),
      isEdit: args.editId != null,
      isTemplateEdit: args.editTemplate,
      to: args.toAccountId,
      loading: loadsSomething,
    );
  }

  Future<void> _start() async {
    if (!ref.mounted) return;
    final movementId = args.editId ?? args.cloneId;
    if (movementId != null) await loadMovement(movementId);
    if (args.savedTemplateId != null) {
      await loadTemplate(args.savedTemplateId!, markClean: true);
    }
    _normalize();
  }

  // --- listas y reglas dependientes de las cuentas y categorías cargadas ---

  List<AccountRecord> get accounts =>
      state.accountsFrom(ref.read(accountsProvider).value ?? const []);

  List<CategoryRecord> get categories =>
      state.categoriesFrom(ref.read(categoriesProvider).value ?? const []);

  void _normalize() {
    if (!ref.mounted || state.loading) return;
    final active = ref.read(accountsProvider).value;
    if (active == null) return;
    final categoriesAsync = ref.read(categoriesProvider);
    var next = state;
    if (args.template != null && !_templateApplied) {
      _templateApplied = true;
      next = _applyTemplate(next, args.template!, next.accountsFrom(active));
    }
    next = next.normalized(
      accounts: next.accountsFrom(active),
      categories: next.categoriesFrom(categoriesAsync.value ?? const []),
      categoriesLoading: categoriesAsync.isLoading,
    );
    if (next.baseline == null) next = next.markClean();
    if (!identical(next, state)) state = next;
  }

  void _update(TransactionFormState next) {
    state = next;
    _normalize();
  }

  /// Plantillas rápidas de apertura; hoy solo el pago de una tarjeta.
  TransactionFormState _applyTemplate(
    TransactionFormState current,
    String template,
    List<AccountRecord> accounts,
  ) {
    if (template != 'cardPayment') return current;
    return current.copyWith(
      type: TransactionType.transfer,
      from: accounts
          .where((account) => account.type == AccountType.bank.name)
          .firstOrNull
          ?.id,
      to:
          current.to ??
          accounts
              .where((account) => account.type == AccountType.creditCard.name)
              .firstOrNull
              ?.id,
    );
  }

  // --- textos (la vista los copia desde sus campos) ---

  void setAmountText(String value) {
    if (value != state.amountText) {
      state = state.copyWith(amountText: value);
    }
  }

  void setMerchantText(String value) {
    if (value != state.merchantText) {
      state = state.copyWith(merchantText: value);
    }
  }

  void setNoteText(String value) {
    if (value != state.noteText) state = state.copyWith(noteText: value);
  }

  // --- elecciones ---

  void setType(TransactionType value) => _update(state.copyWith(type: value));

  void setFrom(String? id) {
    final credit =
        accounts.where((account) => account.id == id).firstOrNull?.type ==
        AccountType.creditCard.name;
    var next = state.copyWith(from: id);
    if (credit) {
      next = next.copyWith(payLater: false, repeat: null);
    } else if (!state.payLater) {
      next = next.copyWith(installments: false);
    }
    _update(next);
  }

  void setTo(String? id) => _update(state.copyWith(to: id));

  void setCategory(String? id) => _update(state.copyWith(category: id));

  void setChannel(PaymentChannel value) =>
      _update(state.copyWith(channel: value));

  void setSaveAnother(bool value) => state = state.copyWith(saveAnother: value);

  void toggleAdvanced() {
    if (state.payLater || state.installments) return;
    state = state.copyWith(advanced: !state.advanced);
  }

  void setAlsoSaveTemplate(bool value) =>
      state = state.copyWith(alsoSaveTemplate: value);

  /// «Cuándo»: `now`, `later` o `installments`.
  void setWhen(String value) {
    final credit = state.isCreditExpense(accounts);
    final installments = value == 'installments';
    _update(
      state.copyWith(
        installments: installments,
        payLater: !credit && (value == 'later' || installments),
        repeat: value == 'later' ? state.repeat : null,
      ),
    );
  }

  void setInstallmentCount(int value) =>
      state = state.copyWith(installmentCount: value);

  void setRepeat(String? value) => state = state.copyWith(repeat: value);

  void setReminders(PaymentReminderSettings value) =>
      state = state.copyWith(reminders: value);

  void setFirstInstallmentDate(DateTime picked) {
    state = state.copyWith(
      firstInstallmentDate: DateTime.utc(
        picked.year,
        picked.month,
        picked.day,
        12,
      ),
    );
  }

  /// Cambia el día del movimiento; la primera cuota lo sigue si coincidía con él.
  void setOccurredAt(DateTime picked) {
    final old = state.occurredAt;
    var first = state.firstInstallmentDate;
    if (first != null &&
        first.year == old.year &&
        first.month == old.month &&
        first.day == old.day) {
      first = DateTime.utc(picked.year, picked.month, picked.day, 12);
    }
    state = state.copyWith(
      firstInstallmentDate: first,
      occurredAt: DateTime(
        picked.year,
        picked.month,
        picked.day,
        old.hour,
        old.minute,
      ),
    );
  }

  // --- divisiones entre categorías ---

  void toggleSplits() {
    final enabling = !state.splitEnabled;
    var next = state.copyWith(splitEnabled: enabling);
    if (enabling && state.splits.isEmpty) {
      final firstCategory =
          state.category ??
          categories.where(state.categoryMatchesType).firstOrNull?.id;
      next = next.copyWith(
        splits: [
          (id: state.nextSplitId, categoryId: firstCategory, amountText: ''),
          (id: state.nextSplitId + 1, categoryId: null, amountText: ''),
        ],
        nextSplitId: state.nextSplitId + 2,
      );
    }
    state = next;
  }

  void addSplit() {
    state = state.copyWith(
      splits: [
        ...state.splits,
        (id: state.nextSplitId, categoryId: null, amountText: ''),
      ],
      nextSplitId: state.nextSplitId + 1,
    );
  }

  void removeSplit(int id) {
    state = state.copyWith(
      splits: [
        for (final split in state.splits)
          if (split.id != id) split,
      ],
    );
  }

  void setSplitCategory(int id, String? categoryId) => _updateSplit(
    id,
    (split) =>
        (id: split.id, categoryId: categoryId, amountText: split.amountText),
  );

  void setSplitAmount(int id, String text) {
    final current = state.splits.where((s) => s.id == id).firstOrNull;
    if (current == null || current.amountText == text) return;
    _updateSplit(
      id,
      (split) => (id: split.id, categoryId: split.categoryId, amountText: text),
    );
  }

  void _updateSplit(int id, SplitEntry Function(SplitEntry) change) {
    state = state.copyWith(
      splits: [
        for (final split in state.splits)
          split.id == id ? change(split) : split,
      ],
    );
  }

  // --- comercio y categorías ---

  /// El usuario eligió un comercio de la lista: propone su categoría habitual.
  Future<void> selectMerchant(MerchantRecord merchant) async {
    final previousCategory = state.category;
    state = state.copyWith(selectedMerchant: merchant);
    final category = await ref
        .read(merchantServiceProvider)
        .defaultCategory(merchant.id);
    if (!ref.mounted) return;
    if (state.type == TransactionType.expense &&
        state.selectedMerchant?.id == merchant.id &&
        state.merchantText == merchant.name &&
        state.category == previousCategory &&
        !state.splitEnabled) {
      _update(state.copyWith(category: category));
    }
  }

  /// Crea la categoría y la deja elegida aunque la lista aún no la incluya.
  Future<void> createCategory(String name) async {
    final id = await ref
        .read(categoryServiceProvider)
        .create(
          name,
          kind: state.type == TransactionType.income ? 'income' : 'expense',
        );
    if (!ref.mounted) return;
    _update(state.copyWith(awaitingCategory: id, category: id));
  }

  // --- cargas ---

  Future<void> loadMovement(String id) async {
    state = state.copyWith(loading: true, loadError: null);
    try {
      final source = await ref.read(ledgerRepositoryProvider).loadForForm(id);
      if (!ref.mounted) return;
      state = state.withMovement(source);
    } catch (error) {
      if (ref.mounted) state = state.copyWith(loadError: '$error');
    } finally {
      if (ref.mounted) {
        state = state.copyWith(loading: false);
        _normalize();
      }
    }
  }

  Future<void> loadTemplate(String id, {required bool markClean}) async {
    state = state.copyWith(loading: true, loadError: null);
    try {
      final template = await ref.read(manualTemplateServiceProvider).read(id);
      if (template == null) throw StateError('La plantilla ya no existe.');
      if (!ref.mounted) return;
      final merchantId = template.fields['merchantId'] as String?;
      final linked = merchantId == null
          ? null
          : await ref.read(merchantServiceProvider).find(merchantId);
      if (!ref.mounted) return;
      state = state.withTemplate(template, linked, markClean: markClean);
    } catch (error) {
      if (ref.mounted) state = state.copyWith(loadError: '$error');
    } finally {
      if (ref.mounted) {
        state = state.copyWith(loading: false);
        _normalize();
      }
    }
  }

  /// Plantillas guardadas, primero las del tipo de movimiento actual.
  Future<List<ManualTemplate>> templatesForPicker() async {
    final templates = await ref.read(manualTemplateServiceProvider).list();
    templates.sort((a, b) {
      final aMatches = a.fields['type'] == state.type.name;
      final bMatches = b.fields['type'] == state.type.name;
      if (aMatches != bMatches) return aMatches ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return templates;
  }

  /// Parte de una plantilla elegida: conserva lo escrito salvo lo que ella pisa.
  Future<void> useTemplate(String id) async {
    state = state.copyWith(
      splits: const [],
      selectedMerchant: null,
      templateSchedule: null,
      alsoSaveTemplate: false,
      occurredAt: DateTime.now(),
      firstInstallmentDate: null,
    );
    await loadTemplate(id, markClean: args.savedTemplateId != null);
  }

  // --- guardado ---

  void setSaving(bool value) {
    if (state.saving != value) state = state.copyWith(saving: value);
  }

  /// Considera lo escrito como punto de partida (tras guardar o descartar).
  void markClean() => state = state.markClean();

  Future<TransactionFormResult> submit(TemplateToSave? template) {
    return ref
        .read(transactionFormServiceProvider)
        .submit(
          state.toValues(
            accounts: accounts,
            bookGeneration: bookGeneration,
            editId: args.editId,
            template: template,
          ),
        );
  }

  Future<void> rememberLastAccounts() => ref
      .read(transactionFormServiceProvider)
      .rememberLastAccounts(type: state.type, from: state.from, to: state.to);

  Future<void> saveTemplate(TemplateToSave template) => ref
      .read(transactionFormServiceProvider)
      .saveTemplate(
        template,
        bookGeneration: bookGeneration,
        id: args.editTemplate ? args.savedTemplateId : null,
      );

  /// Termina un guardado correcto: deja de estar ocupado y lo escrito pasa a
  /// ser el punto de partida.
  void finishSave() => state = state.copyWith(saving: false).markClean();

  /// Tras guardar con «Guardar y crear otro»: deja el formulario listo para otro.
  void resetForAnother() {
    state = state
        .copyWith(
          amountText: '',
          merchantText: '',
          noteText: '',
          selectedMerchant: null,
          alsoSaveTemplate: false,
          templateName: '',
          saving: false,
          textRevision: state.textRevision + 1,
        )
        .markClean();
  }
}

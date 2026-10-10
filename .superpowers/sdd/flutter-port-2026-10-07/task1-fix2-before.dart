import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/money/money.dart';
import '../../transactions/data/ledger_service.dart';
import '../../transactions/domain/ledger_models.dart';
import '../../transactions/domain/payment_channel_policy.dart';
import 'pending_payment_models.dart';
export 'pending_payment_models.dart';

final class PendingPaymentService {
  PendingPaymentService(this.database);
  final AppDatabase database;
  static const prefix = 'pending_payment:v1:';
  void _checkBook(int? expected) {
    if (expected != null && expected != database.restoreGeneration) {
      throw StateError('Los datos fueron restaurados.');
    }
  }

  Stream<List<PendingPayment>> watch() => database
      .customSelect(
        'SELECT count(*) AS count FROM app_settings',
        readsFrom: {
          database.appSettings,
          database.ledgerTransactions,
          database.transactionSplits,
        },
      )
      .watch()
      .asyncMap((_) => list());
  Future<List<PendingPayment>> _rawList() async =>
      (await (database.select(
            database.appSettings,
          )..where((t) => t.key.like('$prefix%'))).get())
          .map(
            (r) => PendingPayment(
              Map<String, dynamic>.from(jsonDecode(r.value) as Map),
            ),
          )
          .toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  Future<List<PendingPayment>> list() async {
    final rows = await _rawList();
    for (final p in rows) {
      await _hydrate(p);
    }
    return rows;
  }

  Future<void> _hydrate(PendingPayment p) async {
    final active = <Map<String, dynamic>>[];
    for (final payment in p.payments) {
      final tx =
          await (database.select(database.ledgerTransactions)
                ..where((t) => t.id.equals(payment['transactionId'] as String)))
              .getSingleOrNull();
      if (tx != null && tx.status != 'deleted' && tx.status != 'reversed') {
        final splits = await (database.select(
          database.transactionSplits,
        )..where((s) => s.transactionId.equals(tx.id))).get();
        active.add({
          ...payment,
          'amountMinor': tx.amountMinor,
          'paidAt': tx.occurredAt.toIso8601String(),
          'accountId': tx.fromAccountId,
          'splits': [
            for (final s in splits)
              {'categoryId': s.categoryId, 'amountMinor': s.amountMinor},
          ],
        });
      }
    }
    p.effectivePayments = active;
    p.effectivePaidMinor = active.fold<int>(
      0,
      (n, p) => n + (p['amountMinor'] as int),
    );
  }

  Future<PendingPayment?> read(String id) async {
    final row = await (database.select(
      database.appSettings,
    )..where((t) => t.key.equals('$prefix$id'))).getSingleOrNull();
    if (row == null) return null;
    final p = PendingPayment(
      Map<String, dynamic>.from(jsonDecode(row.value) as Map),
    );
    await _hydrate(p);
    return p;
  }

  Future<void> _save(PendingPayment p) async {
    await database
        .into(database.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion.insert(
            key: '$prefix${p.id}',
            value: jsonEncode(p.data),
            updatedAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<PendingPayment> _checked(String id, int revision) async {
    final p = await read(id);
    if (p == null || p.revision != revision || p.cancelled) {
      throw StateError('El pendiente cambió.');
    }
    return p;
  }

  Future<void> _account(String id, {bool allowCredit = false}) async {
    final a = await (database.select(
      database.accounts,
    )..where((a) => a.id.equals(id))).getSingleOrNull();
    if (a == null ||
        a.isArchived ||
        a.currencyCode != 'PYG' ||
        (!allowCredit && a.type == 'creditCard')) {
      throw StateError('Elegí una cuenta activa sin crédito.');
    }
  }

  Future<void> validateDraft({
    required int amountMinor,
    required String accountId,
    String? merchantId,
    PaymentChannel paymentChannel = PaymentChannel.other,
    List<SplitDraft> splits = const [],
    PaymentReminderSettings reminders = const PaymentReminderSettings(),
    bool allowCredit = false,
  }) async {
    reminders.validate();
    if (amountMinor <= 0) {
      throw const FormatException('Importe o cuotas inválidos.');
    }
    await _account(accountId, allowCredit: allowCredit);
    final account = await (database.select(
      database.accounts,
    )..where((a) => a.id.equals(accountId))).getSingle();
    if (!PaymentChannelPolicy.allowed(
      TransactionType.expense,
      from: AccountType.values.byName(account.type),
    ).contains(PaymentChannelPolicy.canonical(paymentChannel))) {
      throw const FormatException('Canal inválido.');
    }
    if (splits.isNotEmpty &&
        splits.fold<int>(0, (n, s) => n + s.amountMinor) != amountMinor) {
      throw const FormatException('Las categorías deben sumar el importe.');
    }
    for (final s in splits) {
      final c = await (database.select(
        database.categories,
      )..where((c) => c.id.equals(s.categoryId))).getSingleOrNull();
      if (s.amountMinor <= 0 ||
          c == null ||
          c.isArchived ||
          c.kind == 'income') {
        throw const FormatException('Categoría inválida.');
      }
    }
    if (merchantId != null) {
      final m = await (database.select(
        database.merchants,
      )..where((m) => m.id.equals(merchantId))).getSingleOrNull();
      if (m == null || m.isArchived) throw StateError('Comercio inválido.');
    }
  }

  // Largest remainders keep integer row totals exact. When amount is at most
  // the remaining capacities, no category can exceed its available capacity.
  List<int> _allocateAmounts(int amount, List<int> weights) {
    final total = weights.fold<int>(0, (sum, value) => sum + value);
    if (total == 0) return List<int>.filled(weights.length, 0);
    final result = [for (final weight in weights) amount * weight ~/ total];
    var residue = amount - result.fold<int>(0, (sum, value) => sum + value);
    final order = [for (var i = 0; i < weights.length; i++) i]
      ..sort((a, b) {
        final remainder = (amount * weights[b] % total).compareTo(
          amount * weights[a] % total,
        );
        return remainder != 0 ? remainder : a.compareTo(b);
      });
    for (final index in order) {
      if (residue == 0) break;
      if (weights[index] > 0) {
        result[index]++;
        residue--;
      }
    }
    return result;
  }

  Future<List<PendingPayment>> createPlan({
    required int amountMinor,
    required int installmentCount,
    required DateTime firstDueDate,
    required String accountId,
    String? merchantId,
    String description = '',
    String note = '',
    PaymentChannel paymentChannel = PaymentChannel.other,
    List<SplitDraft> splits = const [],
    String? sourceReference,
    DateTime? occurredAt,
    PaymentReminderSettings reminders = const PaymentReminderSettings(),
    int? expectedBookGeneration,
  }) => database.transaction(() async {
    _checkBook(expectedBookGeneration);
    if (installmentCount < 1 ||
        installmentCount > 120 ||
        amountMinor < installmentCount) {
      throw const FormatException('Importe o cuotas inválidos.');
    }
    await validateDraft(
      amountMinor: amountMinor,
      accountId: accountId,
      merchantId: merchantId,
      paymentChannel: paymentChannel,
      splits: splits,
      reminders: reminders,
      allowCredit: sourceReference != null,
    );
    final plan = const Uuid().v4(), result = <PendingPayment>[];
    var allocated = 0;
    final categoryAllocated = List<int>.filled(splits.length, 0);
    for (var i = 0; i < installmentCount; i++) {
      final amount = i == installmentCount - 1
          ? amountMinor - allocated
          : amountMinor ~/ installmentCount;
      allocated += amount;
      final dueMonth = DateTime(firstDueDate.year, firstDueDate.month + i, 1);
      final last = DateTime(dueMonth.year, dueMonth.month + 1, 0).day;
      final parts = <Map<String, dynamic>>[];
      final row = _allocateAmounts(amount, [
        for (var j = 0; j < splits.length; j++)
          splits[j].amountMinor - categoryAllocated[j],
      ]);
      for (var j = 0; j < splits.length; j++) {
        categoryAllocated[j] += row[j];
        parts.add({'categoryId': splits[j].categoryId, 'amountMinor': row[j]});
      }
      final p = PendingPayment({
        'version': 1,
        'id': const Uuid().v4(),
        'planId': plan,
        'installmentNumber': i + 1,
        'installmentCount': installmentCount,
        'amountMinor': amount,
        'dueDate': DateTime(
          dueMonth.year,
          dueMonth.month,
          firstDueDate.day > last ? last : firstDueDate.day,
        ).toIso8601String(),
        'accountId': accountId,
        'merchantId': merchantId,
        'description': description,
        'note': note,
        'paymentChannel': paymentChannel.name,
        'splits': parts,
        'revision': 0,
        'cancelled': false,
        'payments': <Map<String, dynamic>>[],
        'reminders': reminders.toJson(),
        'occurredAt': occurredAt?.toIso8601String(),
        'sourceReference': sourceReference,
      });
      await _save(p);
      result.add(p);
    }
    return result;
  });
  Future<String> pay({
    required String id,
    required int expectedRevision,
    required int amountMinor,
    required DateTime paidAt,
    required String accountId,
    bool carryRemainder = false,
    int? expectedBookGeneration,
  }) => database.transaction(() async {
    _checkBook(expectedBookGeneration);
    final p = await _checked(id, expectedRevision);
    await _account(accountId);
    if (amountMinor <= 0 || amountMinor > p.remainingMinor) {
      throw const FormatException('Importe inválido.');
    }
    PendingPayment? next;
    final remainder = p.remainingMinor - amountMinor;
    if (carryRemainder && remainder > 0) {
      final following =
          (await list())
              .where(
                (q) =>
                    q.planId == p.planId &&
                    q.installmentNumber > p.installmentNumber &&
                    !q.cancelled &&
                    q.remainingMinor > 0,
              )
              .toList()
            ..sort(
              (a, b) => a.installmentNumber.compareTo(b.installmentNumber),
            );
      if (following.isEmpty) throw StateError('No existe otra cuota.');
      next = following.first;
    }
    final residual = p.remainingSplits;
    var allocated = 0;
    final portions = <SplitDraft>[];
    final keys = residual.keys.toList();
    for (var i = 0; i < keys.length; i++) {
      final key = keys[i];
      final part = i == keys.length - 1
          ? amountMinor - allocated
          : amountMinor * residual[key]! ~/ p.remainingMinor;
      allocated += part;
      if (part > 0) {
        portions.add(SplitDraft(categoryId: key, amountMinor: part));
      }
    }
    final payingAccount = await (database.select(
      database.accounts,
    )..where((a) => a.id.equals(accountId))).getSingle();
    final effectiveChannel = payingAccount.type == 'cash'
        ? PaymentChannel.cash
        : (p.paymentChannel == PaymentChannel.cash
              ? PaymentChannel.other
              : p.paymentChannel);
    final tx = await LedgerService(database).create(
      TransactionDraft(
        type: TransactionType.expense,
        amount: Money(amountMinor, currencyCode: 'PYG'),
        occurredAt: paidAt,
        fromAccountId: accountId,
        merchantId: p.merchantId,
        description: p.description,
        note: p.note,
        paymentChannel: effectiveChannel,
        splits: portions,
        externalFingerprint: 'pending:${p.id}:${p.revision}',
        sourceReference: p.sourceReference ?? p.planId,
      ),
    );
    p.data['payments'] = [
      ...p.payments,
      {
        'transactionId': tx,
        'amountMinor': amountMinor,
        'paidAt': paidAt.toIso8601String(),
        'accountId': accountId,
        'splits': [
          for (final s in portions)
            {'categoryId': s.categoryId, 'amountMinor': s.amountMinor},
        ],
      },
    ];
    p.data['accountId'] = accountId;
    p.data['revision'] = p.revision + 1;
    if (next != null) {
      final carried = [
        for (final key in keys)
          {
            'categoryId': key,
            'amountMinor':
                residual[key]! -
                portions
                    .where((s) => s.categoryId == key)
                    .fold<int>(0, (n, s) => n + s.amountMinor),
          },
      ];
      final cumulativeCarry = <String, int>{};
      for (final part in [
        ...(p.data['carriedSplits'] as List? ?? []),
        ...carried,
      ]) {
        final key = part['categoryId'] as String;
        cumulativeCarry[key] =
            (cumulativeCarry[key] ?? 0) + (part['amountMinor'] as int);
      }
      p.data['carriedSplits'] = [
        for (final e in cumulativeCarry.entries)
          {'categoryId': e.key, 'amountMinor': e.value},
      ];
      p.data['carries'] = [
        ...(p.data['carries'] as List? ?? []),
        {'to': next.id, 'amountMinor': remainder, 'splits': carried},
      ];
      p.data['carriedTo'] = next.id;
      final nextSplits = <String, int>{
        for (final s in next.splits) s.categoryId: s.amountMinor,
      };
      for (final part in carried) {
        final key = part['categoryId'] as String;
        nextSplits[key] = (nextSplits[key] ?? 0) + (part['amountMinor'] as int);
      }
      next.data['splits'] = [
        for (final e in nextSplits.entries)
          {'categoryId': e.key, 'amountMinor': e.value},
      ];
      p.data['carriedMinor'] =
          (p.data['carriedMinor'] as int? ?? 0) + remainder;
      next.data['amountMinor'] = next.amountMinor + remainder;
      next.data['revision'] = next.revision + 1;
      await _save(next);
    }
    await _save(p);
    return tx;
  });
  Future<void> edit({
    required String id,
    required int expectedRevision,
    required int amountMinor,
    required DateTime dueDate,
    String? accountId,
    bool following = false,
    int? expectedBookGeneration,
  }) => database.transaction(() async {
    _checkBook(expectedBookGeneration);
    final p = await _checked(id, expectedRevision);
    if (accountId != null) await _account(accountId);
    final targets = following
        ? (await list())
              .where(
                (q) =>
                    q.planId == p.planId &&
                    q.installmentNumber >= p.installmentNumber &&
                    !q.cancelled &&
                    q.remainingMinor > 0,
              )
              .toList()
        : [p];
    for (final q in targets) {
      final carriedMinor = q.data['carriedMinor'] as int? ?? 0;
      if (amountMinor <= 0 || amountMinor < q.paidMinor + carriedMinor) {
        throw const FormatException(
          'El importe debe cubrir lo pagado y trasladado.',
        );
      }
      if (q.paidMinor > 0) continue;
      final carried = <String, int>{};
      for (final part in q.data['carriedSplits'] as List? ?? []) {
        final key = part['categoryId'] as String;
        carried[key] = (carried[key] ?? 0) + (part['amountMinor'] as int);
      }
      final residual = [
        for (final split in q.splits)
          split.amountMinor - (carried[split.categoryId] ?? 0),
      ];
      final weights = residual.any((value) => value > 0)
          ? residual
          : [for (final split in q.splits) split.amountMinor];
      final allocation = _allocateAmounts(amountMinor - carriedMinor, weights);
      final parts = <Map<String, dynamic>>[
        for (var i = 0; i < q.splits.length; i++)
          {
            'categoryId': q.splits[i].categoryId,
            'amountMinor':
                (carried[q.splits[i].categoryId] ?? 0) + allocation[i],
          },
      ];
      q.data['splits'] = parts;
      q.data['amountMinor'] = amountMinor;
      final offset = q.installmentNumber - p.installmentNumber;
      final month = DateTime(dueDate.year, dueDate.month + offset, 1);
      final last = DateTime(month.year, month.month + 1, 0).day;
      q.data['dueDate'] = DateTime(
        month.year,
        month.month,
        dueDate.day > last ? last : dueDate.day,
      ).toIso8601String();
      if (accountId != null) q.data['accountId'] = accountId;
      q.data['revision'] = q.revision + 1;
      await _save(q);
    }
  });
  Future<void> cancel(
    String id, {
    required int expectedRevision,
    int? expectedBookGeneration,
  }) => database.transaction(() async {
    _checkBook(expectedBookGeneration);
    final p = await _checked(id, expectedRevision);
    p.data['cancelled'] = true;
    p.data['revision'] = p.revision + 1;
    await _save(p);
  });
  Future<void> updateReminders(
    String id, {
    required int expectedRevision,
    required PaymentReminderSettings settings,
    bool following = true,
    int? expectedBookGeneration,
  }) => database.transaction(() async {
    _checkBook(expectedBookGeneration);
    final p = await _checked(id, expectedRevision);
    settings.validate();
    final targets = following
        ? (await list()).where(
            (q) =>
                q.planId == p.planId &&
                q.installmentNumber >= p.installmentNumber &&
                !q.cancelled &&
                q.remainingMinor > 0,
          )
        : [p];
    for (final q in targets) {
      q.data['reminders'] = settings.toJson();
      q.data['revision'] = q.revision + 1;
      await _save(q);
    }
  });
}

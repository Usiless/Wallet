import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/text/normalization.dart';
import '../../transactions/domain/ledger_models.dart';

final class CreateAccountDraft {
  const CreateAccountDraft({
    required this.name,
    required this.type,
    this.currencyCode = 'PYG',
    this.initialBalanceMinor = 0,
    this.aliases = const [],
    bool? includeInAvailableMoney,
    this.includeInNetWorth = true,
    this.creditLimitMinor,
    this.closingDay,
    this.dueDay,
  }) : includeInAvailableMoney =
           includeInAvailableMoney ??
           (type != AccountType.savings && type != AccountType.creditCard);

  final String name;
  final AccountType type;
  final String currencyCode;
  final int initialBalanceMinor;
  final List<String> aliases;
  final bool includeInAvailableMoney;
  final bool includeInNetWorth;
  final int? creditLimitMinor;
  final int? closingDay;
  final int? dueDay;
}

final class AccountsService {
  AccountsService(this.database, {Uuid? uuid}) : uuid = uuid ?? const Uuid();

  final AppDatabase database;
  final Uuid uuid;

  Future<void> setSavingsIncludedInAvailableMoney(
    String id,
    bool included,
  ) async {
    final changed =
        await (database.update(database.accounts)..where(
              (t) =>
                  t.id.equals(id) &
                  t.type.equals('savings') &
                  t.isArchived.equals(false),
            ))
            .write(
              AccountsCompanion(
                includeInAvailableMoney: Value(included),
                updatedAt: Value(DateTime.now().toUtc()),
              ),
            );
    if (changed != 1) {
      throw const ValidationException(
        'La cuenta de ahorro ya no está disponible.',
      );
    }
  }

  Future<String> createAccount(CreateAccountDraft draft) async {
    final name = draft.name.trim();
    if (name.isEmpty) {
      throw const ValidationException('Ingresá un nombre de cuenta.');
    }
    if (draft.currencyCode.length != 3) {
      throw const ValidationException(
        'La moneda debe usar un código ISO de tres letras.',
      );
    }
    if (draft.type == AccountType.creditCard &&
        (draft.creditLimitMinor == null || draft.creditLimitMinor! <= 0)) {
      throw const ValidationException('Ingresá un límite de crédito válido.');
    }
    _validateDay(draft.closingDay, 'cierre');
    _validateDay(draft.dueDay, 'vencimiento');

    final id = uuid.v4();
    final now = DateTime.now().toUtc();
    await database.transaction(() async {
      await database
          .into(database.accounts)
          .insert(
            AccountsCompanion.insert(
              id: id,
              name: name,
              type: draft.type.name,
              currencyCode: draft.currencyCode.toUpperCase(),
              initialBalanceMinor: Value(draft.initialBalanceMinor),
              includeInAvailableMoney: Value(draft.includeInAvailableMoney),
              includeInNetWorth: Value(draft.includeInNetWorth),
              createdAt: now,
              updatedAt: now,
            ),
          );
      for (final alias
          in draft.aliases
              .map((value) => value.trim())
              .where((value) => value.isNotEmpty)) {
        await database
            .into(database.accountAliases)
            .insert(
              AccountAliasesCompanion.insert(
                id: uuid.v4(),
                accountId: id,
                alias: alias,
                normalizedAlias: normalizeMaskedAlias(alias),
                source: 'manual',
                createdAt: now,
              ),
            );
      }
      if (draft.type == AccountType.creditCard) {
        await database
            .into(database.creditCardProfiles)
            .insert(
              CreditCardProfilesCompanion.insert(
                accountId: id,
                creditLimitMinor: draft.creditLimitMinor!,
                closingDay: draft.closingDay ?? 20,
                dueDay: draft.dueDay ?? 3,
                updatedAt: now,
              ),
            );
      }
    });
    return id;
  }

  Future<void> edit(String id, CreateAccountDraft draft) =>
      database.transaction(() async {
        final old = await (database.select(
          database.accounts,
        )..where((t) => t.id.equals(id))).getSingleOrNull();
        if (old == null) {
          throw const ValidationException('La cuenta ya no existe.');
        }
        if (old.type != draft.type.name ||
            old.currencyCode != draft.currencyCode ||
            old.initialBalanceMinor != draft.initialBalanceMinor) {
          throw const ValidationException(
            'El tipo, moneda y saldo inicial se conservan. Usá un ajuste para conciliar el saldo.',
          );
        }
        if (draft.name.trim().isEmpty) {
          throw const ValidationException('Ingresá un nombre.');
        }
        if (draft.type == AccountType.creditCard &&
            (draft.creditLimitMinor == null || draft.creditLimitMinor! <= 0)) {
          throw const ValidationException('Ingresá un límite válido.');
        }
        _validateDay(draft.closingDay, 'cierre');
        _validateDay(draft.dueDay, 'vencimiento');
        final now = DateTime.now().toUtc();
        await (database.update(
          database.accounts,
        )..where((t) => t.id.equals(id))).write(
          AccountsCompanion(
            name: Value(draft.name.trim()),
            includeInAvailableMoney: Value(draft.includeInAvailableMoney),
            includeInNetWorth: Value(draft.includeInNetWorth),
            updatedAt: Value(now),
          ),
        );
        final aliases = draft.aliases
            .map((a) => a.trim())
            .where((a) => a.isNotEmpty)
            .toList();
        final all = await database.select(database.accountAliases).get();
        final active = await getAccounts();
        for (final alias in aliases) {
          if (all.any(
            (a) =>
                a.accountId != id &&
                a.normalizedAlias == normalizeMaskedAlias(alias) &&
                active.any((c) => c.id == a.accountId),
          )) {
            throw const ValidationException(
              'Un alias pertenece a otra cuenta. Corregilo en Asociaciones.',
            );
          }
        }
        await (database.delete(
          database.accountAliases,
        )..where((t) => t.accountId.equals(id))).go();
        final used = <String>{};
        for (final alias in aliases) {
          final normalized = normalizeMaskedAlias(alias);
          if (!used.add(normalized)) continue;
          await database
              .into(database.accountAliases)
              .insert(
                AccountAliasesCompanion.insert(
                  id: uuid.v4(),
                  accountId: id,
                  alias: alias,
                  normalizedAlias: normalized,
                  source: 'manual',
                  createdAt: now,
                ),
              );
        }
        if (draft.type == AccountType.creditCard) {
          await (database.update(
            database.creditCardProfiles,
          )..where((t) => t.accountId.equals(id))).write(
            CreditCardProfilesCompanion(
              creditLimitMinor: Value(draft.creditLimitMinor!),
              closingDay: Value(draft.closingDay ?? 20),
              dueDay: Value(draft.dueDay ?? 3),
              updatedAt: Value(now),
            ),
          );
        }
      });

  Future<void> setArchived(String id, bool archived) async {
    final changed =
        await (database.update(
          database.accounts,
        )..where((t) => t.id.equals(id))).write(
          AccountsCompanion(
            isArchived: Value(archived),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
    if (changed != 1) {
      throw const ValidationException('La cuenta ya no existe.');
    }
  }

  Future<void> assignAlias(
    String rawAlias,
    String accountId, {
    bool replaceExisting = false,
  }) => database.transaction(() async {
    final account =
        await (database.select(database.accounts)..where(
              (t) => t.id.equals(accountId) & t.isArchived.equals(false),
            ))
            .getSingleOrNull();
    final normalized = normalizeMaskedAlias(rawAlias);
    if (account == null || normalized.isEmpty) {
      throw const ValidationException(
        'Elegí una cuenta activa y un alias válido.',
      );
    }
    final existing = await (database.select(
      database.accountAliases,
    )..where((t) => t.normalizedAlias.equals(normalized))).get();
    if (!replaceExisting && existing.any((a) => a.accountId != accountId)) {
      throw const ValidationException(
        'Este alias ya pertenece a otra cuenta. Usá Reasignar para moverlo.',
      );
    }
    await (database.delete(
      database.accountAliases,
    )..where((t) => t.normalizedAlias.equals(normalized))).go();
    await database
        .into(database.accountAliases)
        .insert(
          AccountAliasesCompanion.insert(
            id: uuid.v4(),
            accountId: accountId,
            alias: rawAlias.trim(),
            normalizedAlias: normalized,
            source: 'manual',
            createdAt: DateTime.now().toUtc(),
          ),
        );
  });

  Stream<List<AccountRecord>> watchAccounts({bool includeArchived = false}) {
    final query = database.select(database.accounts);
    if (!includeArchived) {
      query.where((table) => table.isArchived.equals(false));
    }
    query.orderBy([
      (table) => OrderingTerm.asc(table.sortOrder),
      (table) => OrderingTerm.asc(table.createdAt),
    ]);
    return query.watch();
  }

  Future<List<AccountRecord>> getAccounts({bool includeArchived = false}) {
    final query = database.select(database.accounts);
    if (!includeArchived) {
      query.where((table) => table.isArchived.equals(false));
    }
    query.orderBy([
      (table) => OrderingTerm.asc(table.sortOrder),
      (table) => OrderingTerm.asc(table.createdAt),
    ]);
    return query.get();
  }

  Future<CreditCardProfileRecord?> creditCardProfile(String accountId) =>
      (database.select(
        database.creditCardProfiles,
      )..where((table) => table.accountId.equals(accountId))).getSingleOrNull();

  Future<List<AccountAliasRecord>> aliasesOf(String accountId) =>
      (database.select(
        database.accountAliases,
      )..where((table) => table.accountId.equals(accountId))).get();

  Stream<CreditCardProfileRecord?> watchCreditCardProfile(String accountId) =>
      (database.select(database.creditCardProfiles)
            ..where((table) => table.accountId.equals(accountId)))
          .watchSingleOrNull();

  Stream<List<AccountAliasRecord>> watchAliasesOf(String accountId) =>
      (database.select(
        database.accountAliases,
      )..where((table) => table.accountId.equals(accountId))).watch();

  Stream<List<AccountAliasRecord>> watchAliases() =>
      database.select(database.accountAliases).watch();

  Future<void> removeAlias(String aliasId) => (database.delete(
    database.accountAliases,
  )..where((table) => table.id.equals(aliasId))).go();

  Future<AccountRecord?> findByNameOrAlias(String value) async {
    final normalized = normalizeForMatching(value);
    final aliasNormalized = normalizeMaskedAlias(value);
    final accounts = await getAccounts();
    final matching = accounts
        .where((a) => normalizeForMatching(a.name) == normalized)
        .toList();
    final aliases = await (database.select(
      database.accountAliases,
    )..where((t) => t.normalizedAlias.equals(aliasNormalized))).get();
    final ids = {
      ...matching.map((a) => a.id),
      ...aliases.map((a) => a.accountId),
    };
    final found = accounts.where((a) => ids.contains(a.id)).toList();
    return found.length == 1 ? found.single : null;
  }

  void _validateDay(int? value, String label) {
    if (value != null && (value < 1 || value > 31)) {
      throw ValidationException('El día de $label debe estar entre 1 y 31.');
    }
  }
}

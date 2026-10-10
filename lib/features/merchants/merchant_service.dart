import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/text/normalization.dart';

final class MerchantService {
  MerchantService(this.database, {Uuid? uuid}) : uuid = uuid ?? const Uuid();

  final AppDatabase database;
  final Uuid uuid;

  Future<void> rename(String id, String name) => database.transaction(() async {
    final normalized = normalizeForMatching(name);
    if (normalized.isEmpty || name.trim().length > 160) {
      throw StateError('Ingresá un nombre de hasta 160 caracteres.');
    }
    final found = await matches(name);
    if (found.any((m) => m.id != id)) {
      throw StateError(
        'Ese nombre identifica otro comercio. Corregí sus asociaciones primero.',
      );
    }
    await (database.update(
      database.merchants,
    )..where((t) => t.id.equals(id))).write(
      MerchantsCompanion(
        name: Value(name.trim()),
        normalizedName: Value(normalized),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    await learnAlias(id, name);
  });
  Future<void> setArchived(String id, bool archived) async {
    await (database.update(
      database.merchants,
    )..where((t) => t.id.equals(id))).write(
      MerchantsCompanion(
        isArchived: Value(archived),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> assignAlias(
    String rawName,
    String merchantId, {
    bool replaceExisting = false,
  }) => database.transaction(() async {
    final normalized = normalizeForMatching(rawName);
    if (normalized.isEmpty) throw StateError('Ingresá un alias.');
    final target =
        await (database.select(database.merchants)..where(
              (t) => t.id.equals(merchantId) & t.isArchived.equals(false),
            ))
            .getSingleOrNull();
    if (target == null) throw StateError('Elegí un comercio activo.');
    final canonical =
        await (database.select(database.merchants)..where(
              (t) =>
                  t.normalizedName.equals(normalized) &
                  t.id.equals(merchantId).not(),
            ))
            .get();
    if (canonical.isNotEmpty) {
      throw StateError('El alias es el nombre principal de otro comercio.');
    }
    final existing = await (database.select(
      database.merchantAliases,
    )..where((t) => t.normalizedAlias.equals(normalized))).getSingleOrNull();
    if (!replaceExisting &&
        existing != null &&
        existing.merchantId != merchantId) {
      throw StateError(
        'Este alias ya pertenece a otro comercio. Usá Reasignar para moverlo.',
      );
    }
    await (database.delete(
      database.merchantAliases,
    )..where((t) => t.normalizedAlias.equals(normalized))).go();
    await learnAlias(merchantId, rawName);
  });

  Future<String?> defaultCategory(String merchantId) async {
    final rule =
        await (database.select(database.categorizationRules)..where(
              (t) =>
                  t.id.equals('merchant-default-$merchantId') &
                  t.isEnabled.equals(true),
            ))
            .getSingleOrNull();
    if (rule == null) return null;
    final category =
        await (database.select(database.categories)..where(
              (t) => t.id.equals(rule.categoryId) & t.isArchived.equals(false),
            ))
            .getSingleOrNull();
    return category != null && category.kind != 'income' ? category.id : null;
  }

  Future<void> rememberCategory(String merchantId, String? categoryId) async {
    final id = 'merchant-default-$merchantId';
    if (categoryId == null) {
      await (database.delete(
        database.categorizationRules,
      )..where((t) => t.id.equals(id))).go();
      return;
    }
    final category =
        await (database.select(database.categories)..where(
              (t) => t.id.equals(categoryId) & t.isArchived.equals(false),
            ))
            .getSingleOrNull();
    if (category == null || category.kind == 'income') {
      throw StateError('Elegí una categoría de gasto activa.');
    }
    final now = DateTime.now().toUtc();
    await database
        .into(database.categorizationRules)
        .insertOnConflictUpdate(
          CategorizationRulesCompanion.insert(
            id: id,
            merchantId: Value(merchantId),
            transactionType: const Value('expense'),
            categoryId: categoryId,
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<List<MerchantRecord>> matches(String rawName) async {
    final normalized = normalizeForMatching(rawName);
    if (normalized.isEmpty) return [];
    final merchants = await (database.select(
      database.merchants,
    )..where((table) => table.isArchived.equals(false))).get();
    final aliases = await database.select(database.merchantAliases).get();
    final ids = aliases
        .where((alias) => normalizeForMatching(alias.alias) == normalized)
        .map((alias) => alias.merchantId)
        .toSet();
    return merchants
        .where(
          (merchant) =>
              ids.contains(merchant.id) ||
              normalizeForMatching(merchant.name) == normalized,
        )
        .toList();
  }

  Future<void> learnAlias(String merchantId, String rawName) async {
    final normalized = normalizeForMatching(rawName);
    if (normalized.isEmpty) return;
    final existing =
        await (database.select(database.merchantAliases)
              ..where((table) => table.normalizedAlias.equals(normalized)))
            .getSingleOrNull();
    if (existing != null) {
      if (existing.merchantId != merchantId) {
        throw StateError(
          'Este nombre ya está asociado a otro comercio. Revisá la asociación.',
        );
      }
      return;
    }
    await database
        .into(database.merchantAliases)
        .insert(
          MerchantAliasesCompanion.insert(
            id: uuid.v4(),
            merchantId: merchantId,
            alias: rawName.trim(),
            normalizedAlias: normalized,
            source: 'googleWalletNotification',
            createdAt: DateTime.now().toUtc(),
          ),
        );
  }

  Future<String> findOrCreate(
    String rawName, {
    String source = 'manual',
  }) async {
    final normalized = normalizeForMatching(rawName);
    if (normalized.isEmpty || rawName.trim().length > 160) {
      throw StateError(
        'Ingresá un nombre de comercio válido, de hasta 160 caracteres.',
      );
    }
    final alias =
        await (database.select(database.merchantAliases)
              ..where((table) => table.normalizedAlias.equals(normalized)))
            .getSingleOrNull();
    if (alias != null) {
      final target = await (database.select(
        database.merchants,
      )..where((t) => t.id.equals(alias.merchantId))).getSingleOrNull();
      if (target?.isArchived != false) {
        throw StateError(
          'El comercio está archivado. Reactivalo en Comercios.',
        );
      }
      return alias.merchantId;
    }
    final merchant =
        await (database.select(database.merchants)
              ..where((table) => table.normalizedName.equals(normalized)))
            .getSingleOrNull();
    if (merchant != null) {
      if (merchant.isArchived) {
        throw StateError(
          'El comercio está archivado. Reactivalo en Comercios.',
        );
      }
      return merchant.id;
    }
    final id = uuid.v4();
    final now = DateTime.now().toUtc();
    await database.transaction(() async {
      await database
          .into(database.merchants)
          .insert(
            MerchantsCompanion.insert(
              id: id,
              name: rawName.trim(),
              normalizedName: normalized,
              createdAt: now,
              updatedAt: now,
            ),
          );
      await database
          .into(database.merchantAliases)
          .insert(
            MerchantAliasesCompanion.insert(
              id: uuid.v4(),
              merchantId: id,
              alias: rawName.trim(),
              normalizedAlias: normalized,
              source: source,
              createdAt: now,
            ),
          );
    });
    return id;
  }

  Stream<List<MerchantRecord>> watchMerchants({bool includeArchived = false}) {
    final query = database.select(database.merchants);
    if (!includeArchived) {
      query.where((table) => table.isArchived.equals(false));
    }
    query.orderBy([(table) => OrderingTerm.asc(table.name)]);
    return query.watch();
  }

  Future<List<MerchantRecord>> listMerchants({bool includeArchived = false}) {
    final query = database.select(database.merchants);
    if (!includeArchived) {
      query.where((table) => table.isArchived.equals(false));
    }
    query.orderBy([(table) => OrderingTerm.asc(table.createdAt)]);
    return query.get();
  }

  Stream<List<MerchantAliasRecord>> watchAliases() =>
      database.select(database.merchantAliases).watch();

  Future<void> removeAlias(String aliasId) => (database.delete(
    database.merchantAliases,
  )..where((table) => table.id.equals(aliasId))).go();
}

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/text/normalization.dart';

final class CategoryService {
  CategoryService(this.database, {Uuid? uuid}) : uuid = uuid ?? const Uuid();

  final AppDatabase database;
  final Uuid uuid;

  Stream<List<CategoryRecord>> watchCategories({
    String? kind,
    bool includeArchived = false,
  }) {
    final query = database.select(database.categories);
    if (!includeArchived) {
      query.where((table) => table.isArchived.equals(false));
    }
    if (kind != null) {
      query.where((table) => table.kind.isIn([kind, 'both']));
    }
    query.orderBy([(table) => OrderingTerm.asc(table.sortOrder)]);
    return query.watch();
  }

  Future<void> rename(String id, String name) async {
    final clean = name.trim();
    if (clean.isEmpty || clean.length > 80) {
      throw const ValidationException(
        'Ingresá un nombre de hasta 80 caracteres.',
      );
    }
    await database.transaction(() async {
      final rows = await database.select(database.categories).get();
      if (rows.any(
        (r) =>
            r.id != id &&
            normalizeForMatching(r.name) == normalizeForMatching(clean),
      )) {
        throw const ValidationException(
          'Ya existe una categoría con ese nombre.',
        );
      }
      if (await (database.update(
            database.categories,
          )..where((t) => t.id.equals(id))).write(
            CategoriesCompanion(
              name: Value(clean),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          ) !=
          1) {
        throw const ValidationException('La categoría ya no existe.');
      }
    });
  }

  Future<void> setArchived(String id, bool archived) async {
    await (database.update(
      database.categories,
    )..where((t) => t.id.equals(id))).write(
      CategoriesCompanion(
        isArchived: Value(archived),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<String> create(
    String name, {
    required String kind,
    String? parentId,
  }) async {
    final clean = name.trim();
    if (clean.isEmpty) {
      throw const ValidationException('Ingresá un nombre de categoría.');
    }
    final existing = await database.select(database.categories).get();
    if (existing.any(
      (row) => normalizeForMatching(row.name) == normalizeForMatching(clean),
    )) {
      throw const ValidationException(
        'Ya existe una categoría con ese nombre.',
      );
    }
    final id = uuid.v4();
    final now = DateTime.now().toUtc();
    await database
        .into(database.categories)
        .insert(
          CategoriesCompanion.insert(
            id: id,
            name: clean,
            parentId: Value(parentId),
            kind: kind,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }
}

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:finanzas_locales/core/backup/backup_service.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/errors/app_exception.dart';
import 'package:finanzas_locales/features/budgets/domain/budget_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late BudgetService service;
  Future<BudgetRecord> month(int value) async =>
      (await service.watchBudgets(DateTime(2026, value)).first).single;
  Future<String> create() => service.create(
    name: 'Mes ficticio',
    month: DateTime(2026, 10),
    targetMinor: 100001,
    repeatMonthly: true,
  );
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = BudgetService(db);
  });
  tearDown(() => db.close());

  test(
    'categoría archivada conserva historia y suspende nuevas copias',
    () async {
      final timestamp = DateTime.now().toUtc();
      await db
          .into(db.categories)
          .insert(
            CategoriesCompanion.insert(
              id: 'category-test',
              name: 'Ficticia',
              kind: 'expense',
              createdAt: timestamp,
              updatedAt: timestamp,
            ),
          );
      await service.create(
        name: 'Por categoría',
        month: DateTime(2026, 10),
        targetMinor: 10,
        categoryId: 'category-test',
        repeatMonthly: true,
      );
      final original = await month(10);
      await (db.update(db.categories)
            ..where((c) => c.id.equals('category-test')))
          .write(const CategoriesCompanion(isArchived: Value(true)));
      await service.ensureCurrentMonth(now: DateTime(2026, 11));
      expect(await month(10), original);
      expect(await service.watchBudgets(DateTime(2026, 11)).first, isEmpty);
      await service.edit(
        original,
        name: 'General',
        targetMinor: 11,
        repeatMonthly: true,
      );
      await service.ensureCurrentMonth(now: DateTime(2026, 11));
      expect((await month(11)).categoryId, isNull);
      expect((await month(11)).targetMinor, 11);
    },
  );

  test(
    'apertura concurrente crea una vez, sin rellenar meses cerrados',
    () async {
      await create();
      await Future.wait([
        service.ensureCurrentMonth(now: DateTime(2026, 12, 2)),
        service.ensureCurrentMonth(now: DateTime(2026, 12, 3)),
      ]);
      expect(await service.watchBudgets(DateTime(2026, 11)).first, isEmpty);
      expect((await month(12)).targetMinor, 100001);
      expect(await db.select(db.budgets).get(), hasLength(2));
      expect(await db.select(db.ledgerTransactions).get(), isEmpty);
      expect(await db.select(db.accountPostings).get(), isEmpty);
    },
  );

  test(
    'editar cambia ese mes y los siguientes de su serie, conserva pasado e IDs',
    () async {
      await create();
      final october = await month(10);
      await service.ensureCurrentMonth(now: DateTime(2026, 11));
      final november = await month(11);
      await service.ensureCurrentMonth(now: DateTime(2026, 12));
      final december = await month(12);
      final unrelated = await service.create(
        name: 'Otro',
        month: DateTime(2026, 12),
        targetMinor: 77,
      );
      await service.edit(
        november,
        name: 'Nuevo nombre',
        targetMinor: 99999,
        repeatMonthly: true,
      );
      expect(await month(10), october);
      expect((await month(11)).id, november.id);
      expect((await month(11)).name, 'Nuevo nombre');
      final rows = await service.watchBudgets(DateTime(2026, 12)).first;
      expect(rows.singleWhere((b) => b.id == december.id).targetMinor, 99999);
      expect(rows.singleWhere((b) => b.id == unrelated).targetMinor, 77);
      await service.ensureCurrentMonth(now: DateTime(2027, 1));
      final january =
          (await service.watchBudgets(DateTime(2027, 1)).first).single;
      expect(january.name, 'Nuevo nombre');
      expect(january.targetMinor, 99999);
      await service.ensureCurrentMonth(now: DateTime(2026, 11));
      expect(await db.select(db.budgets).get(), hasLength(5));
    },
  );

  test(
    'pausar repetición conserva meses existentes y no crea próximos',
    () async {
      await create();
      await service.ensureCurrentMonth(now: DateTime(2026, 11));
      final november = await month(11);
      await service.edit(
        await month(10),
        name: 'Solo octubre',
        targetMinor: 42,
        repeatMonthly: false,
      );
      await service.ensureCurrentMonth(now: DateTime(2026, 12));
      expect(await month(11), november);
      expect(await service.watchBudgets(DateTime(2026, 12)).first, isEmpty);
      expect(await service.repeatsMonthly(await month(10)), isFalse);
    },
  );

  test(
    'conflicto concurrente y borrador anterior a restauración no escriben',
    () async {
      await create();
      final original = await month(10);
      final results = await Future.wait([
        for (final name in ['Uno', 'Dos'])
          service
              .edit(original, name: name, targetMinor: 30, repeatMonthly: true)
              .then<Object?>((_) => null, onError: (Object e) => e),
      ]);
      expect(results.whereType<ValidationException>(), hasLength(1));
      final updated = await month(10);
      final generation = db.restoreGeneration;
      db.restoreGeneration++;
      await expectLater(
        service.edit(
          updated,
          name: 'Obsoleto',
          targetMinor: 1,
          repeatMonthly: true,
          expectedBookGeneration: generation,
        ),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        service.create(
          name: 'Obsoleto',
          month: DateTime(2026, 10),
          targetMinor: 1,
          expectedBookGeneration: generation,
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(await month(10), updated);
    },
  );

  test('fallo de plantilla revierte edición y alta completas', () async {
    await create();
    await service.ensureCurrentMonth(now: DateTime(2026, 11));
    final before = await db.select(db.budgets).get();
    await db.customStatement(
      "CREATE TRIGGER fail_template BEFORE INSERT ON app_settings BEGIN SELECT RAISE(ABORT, 'fallo ficticio'); END",
    );
    await expectLater(
      service.edit(
        await month(10),
        name: 'No guardar',
        targetMinor: 1,
        repeatMonthly: true,
      ),
      throwsA(anything),
    );
    await expectLater(create(), throwsA(anything));
    expect(await db.select(db.budgets).get(), before);
    await db.customStatement('DROP TRIGGER fail_template');
    await service.ensureCurrentMonth(now: DateTime(2026, 12));
    expect((await month(12)).targetMinor, 100001);
  });

  test(
    'backup cifrado conserva serie, pausa e idempotencia al restaurar',
    () async {
      final dir = await Directory.systemTemp.createTemp('cabal-monthly-test-');
      addTearDown(() => dir.delete(recursive: true));
      await create();
      await service.ensureCurrentMonth(now: DateTime(2026, 11));
      final backup = BackupService(db, directory: dir);
      const password = 'clave ficticia de prueba';
      final bytes = await backup.createBytes(password);
      await service.edit(
        await month(11),
        name: 'Temporal',
        targetMinor: 1,
        repeatMonthly: false,
      );
      await backup.restore(bytes, password);
      expect(await service.repeatsMonthly(await month(11)), isTrue);
      await service.ensureCurrentMonth(now: DateTime(2026, 11));
      expect(await db.select(db.budgets).get(), hasLength(2));
      await service.ensureCurrentMonth(now: DateTime(2026, 12));
      expect((await month(12)).targetMinor, 100001);
      expect((await month(12)).name, 'Mes ficticio');
      expect(await db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
    },
  );
}

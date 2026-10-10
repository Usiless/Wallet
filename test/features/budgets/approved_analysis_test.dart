import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/app/router.dart';
import 'package:finanzas_locales/app/theme/app_theme.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/budgets/domain/budget_service.dart';
import 'package:finanzas_locales/features/budgets/presentation/budgets_screen.dart';
import 'package:finanzas_locales/features/reports/presentation/analysis_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('P02: navegación de Análisis cabe a 320 con texto 2x', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const AnalysisScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Reportes').first);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  testWidgets(
    'P01/P02: cinco destinos y consulta conserva mes al cambiar pestaña',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          onboardingCompleteProvider.overrideWith((ref) => Stream.value(true)),
        ],
      );
      final router = container.read(routerProvider);
      router.go('/analysis');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(find.byType(NavigationDestination), findsNWidgets(5));
      expect(find.text('Sin presupuestos este mes.'), findsOneWidget);
      await tester.tap(find.byTooltip('Mes de presupuesto anterior'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      final selected = DateTime(DateTime.now().year, DateTime.now().month - 1);
      final monthLabel = MaterialLocalizations.of(
        tester.element(find.byType(BudgetsScreen)),
      ).formatMonthYear(selected);
      expect(find.text(monthLabel), findsOneWidget);
      await tester.tap(find.widgetWithText(NavigationDestination, 'Más'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(find.textContaining('CSV'), findsNothing);
      expect(find.text('Plantillas'), findsOneWidget);
      expect(find.text('Movimientos programados'), findsOneWidget);
      expect(find.text('Pagos pendientes'), findsOneWidget);
      await tester.tap(find.widgetWithText(NavigationDestination, 'Análisis'));
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );
      expect(find.text(monthLabel), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 1));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 1));
      router.dispose();
      container.dispose();
      await tester.pump(const Duration(milliseconds: 1));
    },
  );
  for (final dark in [false, true]) {
    testWidgets(
      'P02: anillo y detalle legibles a 320 con texto 2x, oscuro=$dark',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        await tester.runAsync(
          () => BudgetService(db).create(
            name: 'Presupuesto ficticio',
            month: DateTime.now(),
            targetMinor: 200,
          ),
        );
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [databaseProvider.overrideWithValue(db)],
            child: MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: const BudgetsScreen(),
            ),
          ),
        );
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 5),
        );
        expect(find.text('0%'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final budgetNode = tester.getSemantics(
          find.bySemanticsLabel(RegExp('Presupuesto ficticio:')),
        );
        expect(
          budgetNode.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
        );
        budgetNode.owner!.performAction(budgetNode.id, SemanticsAction.tap);
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 5),
        );
        expect(find.text('Consumido'), findsOneWidget);
        expect(find.text('Objetivo'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
        semantics.dispose();
      },
    );
  }
  testWidgets(
    'P02/F17: editar nombre/objetivo, cancelar y activar repetición',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final service = BudgetService(db);
      await service.create(
        name: 'Original ficticio',
        month: DateTime.now(),
        targetMinor: 200,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const BudgetsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> edit() async {
        await tester.tap(find.text('Original ficticio'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Editar presupuesto'));
        await tester.pumpAndSettle();
      }

      await edit();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'No guardar',
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(
        (await tester.runAsync(
          () => service.watchBudgets(DateTime.now()).first,
        ))!.single.name,
        'Original ficticio',
      );
      await edit();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Nombre nuevo',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Objetivo PYG'),
        '345678',
      );
      await tester.tap(find.text('Repetir cada mes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      final saved = (await tester.runAsync(
        () => service.watchBudgets(DateTime.now()).first,
      ))!.single;
      expect(saved.name, 'Nombre nuevo');
      expect(saved.targetMinor, 345678);
      expect(await service.repeatsMonthly(saved), isTrue);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Nombre nuevo'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );
}

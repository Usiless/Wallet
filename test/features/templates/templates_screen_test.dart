import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/templates/manual_template_service.dart';
import 'package:finanzas_locales/features/templates/templates_screen.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ManualTemplateService service;
  late String account;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Map<String, dynamic> fields({Map<String, dynamic>? schedule}) => {
    'type': 'expense',
    'amountMinor': 10000,
    'from': account,
    'merchant': 'Proveedor',
    'channel': 'onlineCard',
    'schedule': ?schedule,
  };

  Map<String, dynamic> schedule({String? pendingReason}) => {
    'enabled': true,
    'frequency': 'monthly',
    'nextDate': '2026-10-04',
    'anchorDay': 4,
    'anchorMonth': 10,
    'pendingReason': ?pendingReason,
  };

  Future<void> seed(WidgetTester tester, Future<void> Function() templates) =>
      tester.runAsync(() async {
        service = ManualTemplateService(db);
        account = await AccountsService(db).createAccount(
          const CreateAccountDraft(name: 'Banco', type: AccountType.bank),
        );
        await templates();
      });

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> show(WidgetTester tester, {bool scheduledOnly = false}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(home: TemplatesScreen(scheduledOnly: scheduledOnly)),
      ),
    );
    await settle(tester);
  }

  Future<void> choose(WidgetTester tester, String option, String name) async {
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(ListTile, name),
        matching: find.byTooltip('Opciones de plantilla'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(option));
    await settle(tester);
  }

  Future<Map<String, dynamic>?> stored(WidgetTester tester, String id) async =>
      (await tester.runAsync(() => service.read(id)))?.fields;

  testWidgets('el filtro Programadas oculta las plantillas manuales', (
    tester,
  ) async {
    await seed(tester, () async {
      await service.save('Manual', fields());
      await service.save('Netflix', fields(schedule: schedule()));
    });
    await show(tester);
    expect(find.text('Manual'), findsOneWidget);
    expect(find.text('Netflix'), findsOneWidget);
    expect(find.text('Abrir y revisar'), findsOneWidget);
    expect(find.textContaining('Mensual · Próximo registro'), findsOneWidget);

    await tester.tap(find.text('Programadas'));
    await settle(tester);
    expect(find.text('Manual'), findsNothing);
    expect(find.text('Netflix'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('sin plantillas muestra el estado vacío de cada filtro', (
    tester,
  ) async {
    await seed(tester, () async {});
    await show(tester);
    expect(find.text('Sin plantillas'), findsOneWidget);

    await tester.tap(find.text('Programadas'));
    await settle(tester);
    expect(find.text('Sin plantillas programadas'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('eliminar quita la plantilla y deshacer la restaura con su id', (
    tester,
  ) async {
    late String id;
    await seed(tester, () async {
      id = await service.save('Alquiler', fields());
    });
    await show(tester);

    await choose(tester, 'Eliminar', 'Alquiler');
    expect(find.text('Plantilla eliminada.'), findsOneWidget);
    expect(await stored(tester, id), isNull);
    expect(find.text('Sin plantillas'), findsOneWidget);

    await tester.tap(find.text('Deshacer'));
    await settle(tester);
    expect(await stored(tester, id), isNotNull);
    expect(find.text('Alquiler'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('pausar desactiva la programación sin borrarla', (tester) async {
    late String id;
    await seed(tester, () async {
      id = await service.save('Netflix', fields(schedule: schedule()));
    });
    await show(tester);

    await choose(tester, 'Pausar programación', 'Netflix');
    final saved = (await stored(tester, id))!['schedule'] as Map;
    expect(saved['enabled'], false);
    expect(saved['paused'], true);
    expect(saved['nextDate'], '2026-10-04');
    expect(find.text('Automatización pausada'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('omitir un vencimiento pendiente avanza a la siguiente fecha', (
    tester,
  ) async {
    late String id;
    await seed(tester, () async {
      id = await service.save(
        'Netflix',
        fields(schedule: schedule(pendingReason: 'Cuenta ambigua')),
      );
    });
    await show(tester);
    expect(find.text('Pendiente: Cuenta ambigua'), findsOneWidget);

    await choose(tester, 'Omitir este vencimiento', 'Netflix');
    final saved = (await stored(tester, id))!['schedule'] as Map;
    expect(saved['nextDate'], '2026-11-04');
    expect(saved.containsKey('pendingReason'), isFalse);
    expect(find.textContaining('Pendiente:'), findsNothing);
    await unmount(tester);
  });
}

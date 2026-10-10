import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/app/router.dart';
import 'package:finanzas_locales/core/config/feature_flags.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/core/notifications/native_notification_bridge.dart';
import 'package:finanzas_locales/core/notifications/notification_envelope.dart';
import 'package:finanzas_locales/core/notifications/notification_ingestion_service.dart';
import 'package:finanzas_locales/core/settings/settings_repository.dart';
import 'package:finanzas_locales/features/settings/presentation/settings_screen.dart';
import 'package:finanzas_locales/features/developer_tools/presentation/active_notifications_screen.dart';
import 'package:finanzas_locales/features/transactions/data/ledger_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/developer_tools/data/notification_retest_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('finanzas_locales/notification_listener');
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    await database.close();
  });

  test(
    'simulación bloqueada sin bandera y marcada como prueba al capturar',
    () async {
      var sent = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'sendTestNotification');
            sent++;
            return null;
          });
      const bridge = NativeNotificationBridge();
      final service = NotificationIngestionService(
        database,
        LedgerService(database),
        settings: SettingsRepository(database),
      );
      final event = NotificationEnvelope(
        version: 1,
        packageName: 'com.google.android.apps.walletnfcrel',
        notificationKey: 'test-notification',
        id: 1,
        postTime: DateTime.now(),
        title: 'ECOP OBLIGADO',
        text: 'PYG 15000 · ••1234',
        isTest: true,
      );
      if (developerToolsEnabled) {
        await bridge.sendTestNotification(
          merchant: 'ECOP OBLIGADO',
          alias: '1234',
          amount: 15000,
        );
        expect(sent, 1);
        final candidate = (await service.ingest(event))!;
        expect(candidate.source, 'developerTest');
        final account = await AccountsService(database).createAccount(
          const CreateAccountDraft(
            name: 'Cuenta de prueba',
            type: AccountType.bank,
          ),
        );
        await service.confirm(candidate, fromAccountId: account);
        final transaction = await database
            .select(database.ledgerTransactions)
            .getSingle();
        expect(transaction.source, 'developerTest');
        expect(transaction.description, startsWith('[PRUEBA]'));
      } else {
        await expectLater(
          bridge.sendTestNotification(
            merchant: 'ECOP',
            alias: '1234',
            amount: 15000,
          ),
          throwsStateError,
        );
        expect(sent, 0);
        expect(await service.ingest(event), isNull);
        expect(
          await database.select(database.notificationEvents).get(),
          isEmpty,
        );
      }
    },
  );

  test(
    'repetir requiere bandera y gasto eliminado; deshacer no duplica',
    () async {
      final ledger = LedgerService(database);
      final service = NotificationIngestionService(
        database,
        ledger,
        settings: SettingsRepository(database),
      );
      final retest = NotificationRetestService(database, service);
      final event = NotificationEnvelope(
        version: 1,
        packageName: 'com.google.android.gms',
        notificationKey: 'retry',
        id: 1,
        postTime: DateTime.now().toUtc(),
        title: 'Comercio',
        text: 'PYG 15000 · ••9999',
      );
      if (!developerToolsEnabled) {
        await expectLater(retest.reopen(event), throwsStateError);
        expect(
          await database.select(database.paymentCandidates).get(),
          isEmpty,
        );
        return;
      }
      final account = await AccountsService(database).createAccount(
        const CreateAccountDraft(name: 'Mi cuenta', type: AccountType.bank),
      );
      final candidate = (await service.ingest(event))!;
      final first = await service.confirm(candidate, fromAccountId: account);
      await expectLater(retest.reopen(event), throwsStateError);
      await ledger.softDelete(first);
      await retest.reopen(event);
      final pending = await database
          .select(database.paymentCandidates)
          .getSingle();
      expect(pending.status, 'pending');
      expect(await database.select(database.accountPostings).get(), isEmpty);
      final second = await service.confirm(pending, fromAccountId: account);
      expect(second, isNot(first));
      await expectLater(ledger.restore(first), throwsA(anything));
      expect(
        await database.select(database.accountPostings).get(),
        hasLength(1),
      );
      expect(
        await database.select(database.accountAliases).get(),
        hasLength(1),
      );
      await expectLater(retest.reopen(event), throwsStateError);
    },
  );

  testWidgets(
    'inspección activa muestra campos sin guardar eventos ni gastos',
    (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async => [
              {
                'packageName': 'com.google.android.gms',
                'notificationKey': 'active',
                'title': 'Comercio real',
                'text': 'PYG 15000 · ••1234',
              },
            ],
          );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(database)],
          child: const MaterialApp(home: ActiveNotificationsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      if (developerToolsEnabled) {
        await tester.tap(find.text('Consultar notificaciones'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Comercio real'));
        await tester.pumpAndSettle();
        expect(find.text('Texto: PYG 15000 · ••1234'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Crear propuesta para revisar'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Crear propuesta para revisar'), findsOneWidget);
      } else {
        expect(find.text('Consultar notificaciones'), findsNothing);
      }
      expect(await database.select(database.notificationEvents).get(), isEmpty);
      expect(await database.select(database.paymentCandidates).get(), isEmpty);
      expect(await database.select(database.ledgerTransactions).get(), isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  test(
    'el puente respeta la bandera aunque el ajuste solicite captura',
    () async {
      MethodCall? configured;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            configured = call;
            return null;
          });
      await const NativeNotificationBridge().configure(
        enabled: true,
        diagnosticMode: true,
        allowedPackages: const {'com.google.android.gms'},
      );
      final args = configured!.arguments as Map;
      expect(args['enabled'], isTrue);
      expect(args['diagnosticMode'], developerToolsEnabled);
      expect(args['allowedPackages'], ['com.google.android.gms']);
    },
  );

  test('las rutas de desarrollo solo existen con la bandera habilitada', () {
    final container = ProviderContainer();
    final router = container.read(routerProvider);
    final paths = router.configuration.routes.whereType<GoRoute>().map(
      (route) => route.path,
    );
    expect(paths.contains('/developer-tools'), developerToolsEnabled);
    expect(
      paths.contains('/developer-tools/notifications'),
      developerToolsEnabled,
    );
    expect(paths.contains('/diagnostics'), isFalse);
    expect(
      paths.contains('/developer-tools/active-notifications'),
      developerToolsEnabled,
    );
    router.dispose();
    container.dispose();
  });

  test(
    'consulta activa bloqueada por bandera y filtrada a fuentes Wallet',
    () async {
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls++;
            expect(call.method, 'readActiveWalletNotifications');
            return [
              {'packageName': 'com.google.android.gms', 'title': 'Compra'},
              {'packageName': 'otra.app', 'title': 'Privado'},
            ];
          });
      final bridge = const NativeNotificationBridge();
      if (developerToolsEnabled) {
        final events = await bridge.readActiveWalletNotifications();
        expect(events, hasLength(1));
        expect(events.single.title, 'Compra');
        expect(calls, 1);
      } else {
        await expectLater(
          bridge.readActiveWalletNotifications(),
          throwsStateError,
        );
        expect(calls, 0);
      }
    },
  );

  test(
    'preferencias antiguas no habilitan retención con la bandera apagada',
    () async {
      final settings = SettingsRepository(database);
      await settings.write('diagnostic_mode', 'true');
      final service = NotificationIngestionService(
        database,
        LedgerService(database),
        settings: settings,
      );
      await service.ingest(
        NotificationEnvelope(
          version: 1,
          packageName: 'com.google.android.gms',
          notificationKey: 'test-flag',
          id: 1,
          postTime: DateTime.now().toUtc(),
          title: 'Comercio de prueba',
          text: 'PYG 15000 · ••1234',
        ),
      );
      final event = await database
          .select(database.notificationEvents)
          .getSingle();
      expect(
        event.notificationText,
        developerToolsEnabled ? 'PYG 15000 · ••1234' : isNull,
      );
      expect(await database.select(database.ledgerTransactions).get(), isEmpty);
    },
  );

  testWidgets('configuración agrupa las pruebas en un solo menú opcional', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(database)],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Herramientas de desarrollo'),
      developerToolsEnabled ? findsOneWidget : findsNothing,
    );
    expect(find.text('Modo diagnóstico'), findsNothing);
    expect(find.text('Procesar eventos capturados'), findsNothing);
    expect(find.text('Probar detección de Google Wallet'), findsNothing);
    expect(find.text('Cuentas'), findsNothing);
    expect(find.text('Google Wallet'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

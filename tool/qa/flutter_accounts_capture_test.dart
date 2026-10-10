// Explicit host-rendering evidence. Not an Android screenshot or a pixel assertion.
import 'dart:convert';
import 'dart:io';

import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/app/theme/app_theme.dart';
import 'package:finanzas_locales/app/router.dart';
import 'package:drift/native.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final config = jsonDecode(
      File('.dart_tool/package_config.json').readAsStringSync(),
    ) as Map;
    final flutter = (config['packages'] as List).cast<Map>().firstWhere(
      (p) => p['name'] == 'flutter',
    );
    final root = Directory.fromUri(Uri.parse(flutter['rootUri'] as String))
        .parent
        .parent;
    final font = FontLoader('Roboto');
    for (final name in ['Regular', 'Medium', 'Bold']) {
      font.addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '${root.path}/bin/cache/artifacts/material_fonts/Roboto-$name.ttf',
            ).readAsBytesSync(),
          ),
        ),
      );
    }
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '${root.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ).readAsBytesSync(),
          ),
        ),
      );
    await icons.load();
    final fallback = FontLoader('NotoSans')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File('/usr/share/fonts/google-noto/NotoSans-Regular.ttf')
                .readAsBytesSync(),
          ),
        ),
      );
    await fallback.load();
  });
  const phase = String.fromEnvironment('CAPTURE_PHASE', defaultValue: 'before');
  for (final variant in [
    (390.0, 1.0, false),
    (320.0, 2.0, true),
    (486.0, 1.0, false),
  ]) {
    testWidgets('Flutter Cuentas $phase ${variant.$1} texto ${variant.$2}', (
      tester,
    ) async {
      tester.view.physicalSize = Size(variant.$1, 1000);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(
        top: 24,
        left: 8,
        right: 8,
        bottom: 16,
      );
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.runAsync(() async {
        final service = AccountsService(db);
        for (final draft in [
          const CreateAccountDraft(
            name: 'Banco diario',
            type: AccountType.bank,
            initialBalanceMinor: 1234567890,
          ),
          const CreateAccountDraft(
            name: 'Visa',
            type: AccountType.creditCard,
            creditLimitMinor: 2000000000,
          ),
          const CreateAccountDraft(
            name: 'Efectivo',
            type: AccountType.cash,
            initialBalanceMinor: 830000,
          ),
          const CreateAccountDraft(
            name: 'Ahorro',
            type: AccountType.savings,
            initialBalanceMinor: 5000000,
          ),
        ]) {
          await service.createAccount(draft);
        }
      });
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          onboardingCompleteProvider.overrideWith((ref) => Stream.value(true)),
        ],
      );
      final router = container.read(routerProvider)..go('/accounts');
      final key = GlobalKey();
      final theme = variant.$3 ? AppTheme.dark() : AppTheme.light();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: RepaintBoundary(
            key: key,
            child: MaterialApp.router(
              theme: theme.copyWith(
                textTheme: theme.textTheme.apply(
                  fontFamily: 'Roboto',
                  fontFamilyFallback: ['NotoSans'],
                ),
              ),
              locale: const Locale('es', 'PY'),
              supportedLocales: const [Locale('es', 'PY')],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(variant.$2)),
                child: child!,
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(key),
        matchesGoldenFile(
          '../../docs/evaluation/flutter-port-2026-10-07/flutter-accounts-$phase-${variant.$1.toInt()}-${variant.$2.toInt()}x.png',
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      router.dispose();
      container.dispose();
      await tester.pump(const Duration(milliseconds: 1));
    });
  }
}

// Explicit host-rendering evidence. Not an Android screenshot or a pixel assertion.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/app/theme/app_theme.dart';
import 'package:finanzas_locales/features/dashboard/presentation/dashboard_screen.dart';
import 'package:finanzas_locales/features/payments/domain/pending_payment_models.dart';
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
  for (final variant in [
    (390.0, 1.0, false),
    (320.0, 2.0, true),
    (960.0, 1.0, false),
  ]) {
    testWidgets('Flutter Inicio ${variant.$1} texto ${variant.$2}', (
      tester,
    ) async {
      tester.view.physicalSize = Size(variant.$1, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            accountBalancesProvider.overrideWith(
              (ref) => Stream.value([
                const AccountBalance(
                  id: 'bank',
                  name: 'Cuenta diaria',
                  type: AccountType.bank,
                  currencyCode: 'PYG',
                  balanceMinor: 727000,
                  includeInAvailableMoney: true,
                  includeInNetWorth: true,
                ),
              ]),
            ),
            pendingCandidatesProvider.overrideWith((ref) => Stream.value([])),
            pendingPaymentsProvider.overrideWith(
              (ref) => Stream.value([
                for (final entry in [
                  (
                    1,
                    'Servicio de mantenimiento con descripción extensa',
                    110000,
                  ),
                  (2, 'Tele del living', 500000),
                ])
                  PendingPayment({
                    'id': '${entry.$1}',
                    'amountMinor': entry.$3,
                    'payments': [],
                    'dueDate': DateTime(
                      2026,
                      10,
                      5 + entry.$1,
                    ).toIso8601String(),
                    'cancelled': false,
                    'description': entry.$2,
                  }),
              ]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light().copyWith(
              textTheme: AppTheme.light().textTheme.apply(fontFamily: 'Roboto'),
            ),
            darkTheme: AppTheme.dark().copyWith(
              textTheme: AppTheme.dark().textTheme.apply(fontFamily: 'Roboto'),
            ),
            themeMode: variant.$3 ? ThemeMode.dark : ThemeMode.light,
            locale: const Locale('es', 'PY'),
            supportedLocales: const [Locale('es', 'PY')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(variant.$2)),
              child: child!,
            ),
            home: RepaintBoundary(key: key, child: const DashboardScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.stateList<ScrollableState>(find.byType(Scrollable)).map((s) => s.position.pixels),
        everyElement(0.0),
      );
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byKey(key),
        matchesGoldenFile(
          '../../docs/evaluation/flutter-port-2026-10-07/flutter-inicio-${variant.$1.toInt()}-${variant.$2.toInt()}x.png',
        ),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
}

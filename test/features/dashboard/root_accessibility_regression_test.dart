import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/app/theme/app_theme.dart';
import 'package:finanzas_locales/features/dashboard/presentation/dashboard_screen.dart';
import 'package:finanzas_locales/features/payments/domain/pending_payment_models.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:finanzas_locales/shared/widgets/money_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const longDescription = 'Servicio de mantenimiento con descripción extensa';

Future<void> showDashboard(
  WidgetTester tester, {
  int available = 727000,
  required Stream<List<PendingPayment>> payments,
}) async {
  tester.view.physicalSize = const Size(320, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        accountBalancesProvider.overrideWith(
          (ref) => Stream.value([
            AccountBalance(
              id: 'bank',
              name: 'Banco',
              type: AccountType.bank,
              currencyCode: 'PYG',
              balanceMinor: available,
              includeInAvailableMoney: true,
              includeInNetWorth: true,
            ),
          ]),
        ),
        pendingCandidatesProvider.overrideWith((ref) => Stream.value([])),
        pendingPaymentsProvider.overrideWith((ref) => payments),
      ],
      child: MaterialApp(
        theme: AppTheme.dark().copyWith(
          textTheme: AppTheme.dark().textTheme.apply(fontFamily: 'Roboto'),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const DashboardScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

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
    final font = FontLoader('Roboto')
      ..addFont(
        Future.value(
          ByteData.sublistView(
            File(
              '${root.path}/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
            ).readAsBytesSync(),
          ),
        ),
      );
    await font.load();
  });

  for (final fixture in [
    (727000, '727.000 ₲'),
    (1234567890, '1.234.567.890 ₲'),
    (-1234567890, '-1.234.567.890 ₲'),
  ]) {
    final amount = fixture.$1;
    testWidgets('importe completo sin elipsis ni recorte a 320/2x: $amount', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await showDashboard(
        tester,
        available: amount,
        payments: Stream.value([]),
      );
      await tester.pumpAndSettle();
      final hero = find.byKey(const ValueKey('overview-available'));
      final money = find.descendant(of: hero, matching: find.byType(MoneyText));
      final text = find.descendant(of: money, matching: find.byType(Text));
      final paragraph = tester.renderObject<RenderParagraph>(text);
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: 'Un importe financiero no puede perder dígitos por elipsis.',
      );
      final displayed = tester.widget<Text>(text).data!;
      expect(displayed, fixture.$2);
      final bounds = tester.getRect(hero);
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: displayed.length),
      );
      expect(boxes, isNotEmpty);
      for (final box in boxes) {
        final topLeft = paragraph.localToGlobal(Offset(box.left, box.top));
        final bottomRight = paragraph.localToGlobal(
          Offset(box.right, box.bottom),
        );
        expect(bounds.contains(topLeft), isTrue);
        expect(bounds.contains(bottomRight), isTrue);
      }
      expect(
        tester.getSemantics(text).getSemanticsData().label,
        contains(displayed),
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets(
    'títulos y nombres de próximos pagos conservan palabras enteras a 320/2x',
    (tester) async {
      await showDashboard(
        tester,
        payments: Stream.value([
          for (final entry in [(1, longDescription), (2, 'Tele del living')])
            PendingPayment({
              'id': '${entry.$1}',
              'amountMinor': 110000,
              'payments': [],
              'dueDate': DateTime(2026, 10, entry.$1).toIso8601String(),
              'cancelled': false,
              'description': entry.$2,
            }),
        ]),
      );
      await tester.pumpAndSettle();
      for (final label in [
        'Próximos pagos',
        longDescription,
        'Tele del living',
      ]) {
        final finder = find.text(label);
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        final paragraph = tester.renderObject<RenderParagraph>(finder);
        var offset = 0;
        for (final word in label.split(' ')) {
          final boxes = paragraph.getBoxesForSelection(
            TextSelection(
              baseOffset: offset,
              extentOffset: offset + word.length,
            ),
          );
          expect(
            boxes,
            hasLength(1),
            reason: 'La palabra "$word" debe leerse completa.',
          );
          offset += word.length + 1;
        }
        expect(paragraph.didExceedMaxLines, isFalse);
      }
      final secondPayment = find.ancestor(
        of: find.text('Tele del living'),
        matching: find.byType(ListTile),
      );
      final amount = find.descendant(
        of: secondPayment,
        matching: find.byType(MoneyText),
      );
      await tester.ensureVisible(amount);
      await tester.pumpAndSettle();
      expect(tester.getRect(amount).bottom, lessThanOrEqualTo(844));
      expect(tester.takeException(), isNull);
    },
  );

  for (final error in [false, true]) {
    testWidgets(
      'pagos sin datos no muestran obligaciones cero ni patrimonio inventado: error=$error',
      (tester) async {
        final stream = StreamController<List<PendingPayment>>();
        addTearDown(stream.close);
        await showDashboard(tester, payments: stream.stream);
        if (error) {
          stream.addError(StateError('No disponible'));
          await tester.pump();
          await tester.pump();
        }
        for (final title in ['Pendiente del mes', 'Patrimonio total']) {
          final tile = find.widgetWithText(ListTile, title);
          expect(
            find.descendant(of: tile, matching: find.byType(MoneyText)),
            findsNothing,
          );
        }
        final heroMoney = find.descendant(
          of: find.byKey(const ValueKey('overview-available')),
          matching: find.byType(MoneyText),
        );
        expect(tester.widget<MoneyText>(heroMoney).minorUnits, 727000);
        if (error) {
          expect(find.text('No se pudieron cargar los pagos.'), findsOneWidget);
        }
        stream.add([]);
        await tester.pump();
        await tester.pump();
        final pending = find.descendant(
          of: find.widgetWithText(ListTile, 'Pendiente del mes'),
          matching: find.byType(MoneyText),
        );
        final netWorth = find.descendant(
          of: find.byKey(const ValueKey('overview-net-worth')),
          matching: find.byType(MoneyText),
        );
        expect(tester.widget<MoneyText>(pending).minorUnits, 0);
        expect(tester.widget<MoneyText>(netWorth).minorUnits, 727000);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      },
    );
  }
}

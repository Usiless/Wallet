import 'package:finanzas_locales/shared/widgets/money_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'fitWidth muestra el importe completo a escala 2.0 sin desbordes',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Builder(
                      builder: (context) => MoneyText(
                        1000000000,
                        style: Theme.of(context).textTheme.headlineMedium,
                        fitWidth: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final text = find.byType(Text);
      expect(tester.takeException(), isNull);
      final fitted = find.ancestor(of: text, matching: find.byType(FittedBox));
      expect(fitted, findsOneWidget);
      expect(tester.getSize(fitted).width, lessThanOrEqualTo(360 - 32));
      expect(tester.widget<Text>(text).overflow, isNot(TextOverflow.ellipsis));
    },
  );

  testWidgets('fitWidth alinea el importe al inicio cuando cabe sin escalar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Builder(
              builder: (context) => MoneyText(
                1000,
                style: Theme.of(context).textTheme.headlineMedium,
                fitWidth: true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final text = find.byType(Text);
    final fitted = find.ancestor(of: text, matching: find.byType(FittedBox));
    expect(fitted, findsOneWidget);
    expect(tester.getTopLeft(text).dx, tester.getTopLeft(fitted).dx);
    expect(tester.getTopLeft(text).dx, 16);
  });
}

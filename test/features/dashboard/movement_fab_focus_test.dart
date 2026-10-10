import 'package:finanzas_locales/shared/widgets/movement_fab.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Escape devuelve foco al más y salir del grupo cierra las acciones',
    (tester) async {
      final outside = FocusNode();
      addTearDown(outside.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TextField(focusNode: outside),
            floatingActionButton: const MovementFab(),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Nuevo movimiento'));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton),
      );
      expect(fab.focusNode?.hasFocus, isTrue);
      await tester.tap(find.byTooltip('Nuevo movimiento'));
      await tester.pumpAndSettle();
      outside.requestFocus();
      await tester.pumpAndSettle();
      expect(find.text('Gasto'), findsNothing);
      expect(outside.hasFocus, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

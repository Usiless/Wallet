import 'package:finanzas_locales/features/updater/domain/app_version.dart';
import 'package:finanzas_locales/features/updater/domain/release_info.dart';
import 'package:finanzas_locales/features/updater/presentation/update_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ReleaseInfo _release() => ReleaseInfo(
  tag: 'v1.3.0',
  version: const AppVersion(1, 3, 0),
  notes: 'Mejoras de importes',
  apk: ReleaseAsset(
    name: 'app-release.apk',
    downloadUrl: Uri.parse('https://example.com/app-release.apk'),
    size: 1,
  ),
);

void main() {
  testWidgets('muestra versión y notas, y devuelve la elección', (
    tester,
  ) async {
    bool? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showUpdateDialog(context, _release());
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Versión 1.3.0'), findsOneWidget);
    expect(find.text('Mejoras de importes'), findsOneWidget);

    await tester.tap(find.text('Actualizar'));
    await tester.pumpAndSettle();
    expect(result, isTrue);

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Más tarde'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}

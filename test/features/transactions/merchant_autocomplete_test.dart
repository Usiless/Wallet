import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/merchants/merchant_autocomplete.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'buscar por alias muestra el comercio una vez y permite nombres nuevos',
    (tester) async {
      final now = DateTime.now();
      final merchant = MerchantRecord(
        id: 'ecop',
        name: 'Ecop Obligado',
        normalizedName: 'ECOP OBLIGADO',
        isArchived: false,
        createdAt: now,
        updatedAt: now,
      );
      final alias = MerchantAliasRecord(
        id: 'alias',
        merchantId: 'ecop',
        alias: 'Estación Ecop',
        normalizedAlias: 'ESTACION ECOP',
        source: 'manual',
        createdAt: now,
      );
      final controller = TextEditingController();
      MerchantRecord? selected;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            merchantsProvider.overrideWith((ref) => Stream.value([merchant])),
            merchantAliasesProvider.overrideWith(
              (ref) => Stream.value([alias]),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: MerchantAutocomplete(
                controller: controller,
                onSelected: (value) => selected = value,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'estacion');
      await tester.pumpAndSettle();
      expect(find.text('Ecop Obligado'), findsOneWidget);
      await tester.tap(find.text('Ecop Obligado'));
      await tester.pumpAndSettle();
      expect(selected?.id, 'ecop');
      expect(controller.text, 'Ecop Obligado');
      await tester.enterText(find.byType(TextFormField), 'Comercio nuevo');
      await tester.pumpAndSettle();
      expect(find.byType(ListTile), findsNothing);
      expect(controller.text, 'Comercio nuevo');
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}

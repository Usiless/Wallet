import 'package:drift/native.dart';
import 'package:finanzas_locales/app/providers.dart';
import 'package:finanzas_locales/app/router.dart';
import 'package:finanzas_locales/app/theme/app_theme.dart';
import 'package:finanzas_locales/core/database/app_database.dart';
import 'package:finanzas_locales/features/accounts/data/accounts_service.dart';
import 'package:finanzas_locales/features/accounts/presentation/accounts_screen.dart';
import 'package:finanzas_locales/features/transactions/domain/ledger_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final variant in [
    (320.0, 1.0, false),
    (390.0, 1.0, true),
    (486.0, 1.0, false),
    (320.0, 2.0, true),
    (486.0, 2.0, false),
  ]) {
    testWidgets(
      'Cuentas compactas/insets ${variant.$1} texto ${variant.$2} oscuro ${variant.$3}',
      (tester) async {
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
        late String credit;
        await tester.runAsync(() async {
          final service = AccountsService(db);
          await service.createAccount(
            const CreateAccountDraft(
              name: 'Banco',
              type: AccountType.bank,
              initialBalanceMinor: 1234567890,
            ),
          );
          credit = await service.createAccount(
            const CreateAccountDraft(
              name: 'Crédito personal',
              type: AccountType.creditCard,
              creditLimitMinor: 2000000000,
            ),
          );
          await service.createAccount(
            const CreateAccountDraft(
              name: 'Efectivo',
              type: AccountType.cash,
              initialBalanceMinor: -1234567890,
            ),
          );
        });
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            onboardingCompleteProvider.overrideWith(
              (ref) => Stream.value(true),
            ),
          ],
        );
        final router = container.read(routerProvider)..go('/accounts');
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              theme: variant.$3 ? AppTheme.dark() : AppTheme.light(),
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(variant.$2)),
                child: child!,
              ),
            ),
          ),
        );
        Future<void> settle() async {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)),
          );
          await tester.pumpAndSettle();
        }

        await settle();
        if (variant.$1 == 390) expect(find.text('Pagar tarjeta'), findsNothing);
        final chip = find.widgetWithText(ChoiceChip, 'Todas');
        expect(
          tester.getTopLeft(chip).dy,
          greaterThanOrEqualTo(40),
          reason: 'Contenido bajo la barra de estado.',
        );
        expect(
          tester.getTopLeft(chip).dx,
          greaterThanOrEqualTo(24),
          reason: 'Respetar recortes laterales.',
        );
        expect(find.text('Pagar tarjeta'), findsNothing);
        expect(find.text('Administrar'), findsNothing);
        expect(find.text('Ver movimientos'), findsNothing);
        for (final expected in ['1.234.567.890', '-1.234.567.890']) {
          final amountFinder = find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                RegExp(
                  '^${RegExp.escape(expected)}'
                  r'\s+PYG\s*$',
                ).hasMatch(widget.data ?? ''),
          );
          await tester.scrollUntilVisible(
            amountFinder,
            120,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          final text = amountFinder;
          final amount = tester.widget<Text>(text).data!;
          expect(
            amount.replaceAll(RegExp(r'\s+'), ' ').trim(),
            '$expected PYG',
          );
          final paragraph = tester.renderObject<RenderParagraph>(text);
          expect(paragraph.didExceedMaxLines, false);
          final card = find.ancestor(of: text, matching: find.byType(Card));
          final bounds = tester.getRect(card);
          final boxes = paragraph.getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: amount.length),
          );
          expect(boxes, isNotEmpty);
          for (final box in boxes) {
            expect(
              bounds.contains(
                paragraph.localToGlobal(Offset(box.left, box.top)),
              ),
              true,
            );
            expect(
              bounds.contains(
                paragraph.localToGlobal(Offset(box.right, box.bottom)),
              ),
              true,
            );
          }
        }
        await tester.scrollUntilVisible(
          find.text('Crédito personal'),
          -120,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(find.text('Crédito personal'));
        await settle();
        expect(
          tester
              .widget<AccountsScreen>(find.byType(AccountsScreen).last)
              .accountId,
          credit,
        );
        expect(tester.getTopLeft(find.byType(AppBar)).dy, 24);
        expect(
          tester.getSize(find.byType(AppBar)).height,
          56,
          reason: 'Sin duplicar inset en detalle.',
        );
        await tester.scrollUntilVisible(
          find.text('Pagar esta tarjeta'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await settle();
        expect(find.text('Pagar esta tarjeta'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Editar'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        for (final label in [
          'Ver movimientos',
          'Editar',
          'Archivar',
          'Conciliar saldo',
        ]) {
          expect(find.text(label), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        router.dispose();
        container.dispose();
        await tester.pump(const Duration(milliseconds: 1));
      },
    );
  }
}

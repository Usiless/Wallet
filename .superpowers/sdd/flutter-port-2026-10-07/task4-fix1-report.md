# Task 4 — fix round 1

Scope: DashboardScreen, budget card semantics, targeted root widget regressions, and controller-authorized fixes to AnalysisScreen/ReportsScreen for newly reproduced responsive failures. No APK, HTML, Git, providers, router, transaction form or payment domain changes. MoneyText is unchanged. Read project AGENTS, accepted product baseline, approved port plan and independent task4-review.

## Changes

- Budget cards replace the excluded child's accessibility activation with an explicit Semantics.onTap opening the same detail. Both light/dark 320px tests perform the actual SemanticsAction.tap and assert the detail opens.
- Available amount uses an intrinsic one-line MoneyText within FittedBox(scaleDown), local to the hero. The full numeral and currency remain visible; surrounding text retains the selected text scaling. This approach was confirmed by the controller; no digit groups wrap to another line.
- At widths under 360px or enlarged text, Próximos pagos and Ver todos stack, and upcoming amounts move below the description/date, freeing the full width for words. At normal width/scale the established horizontal layout remains.
- Missing initial payment data shows — for the dependent pending-month and net-worth values. Independent available remains valid. Existing loading/error feedback remains; real empty payment data restores a genuine zero pending and the corresponding net worth.
- Analysis navigation's preferred height now derives from labels measured at the actual available width and TextScaler, plus explicit segment padding. This fixes the original 64px preferred-height contract against 68px natural content, and its larger mismatch at 320/2x. It keeps the original controls and root layout.
- Reports view selector uses expanded width and intrinsic item height, preventing its selected label from overflowing the dropdown at 320/2x.

## Reproduction before implementation

- Actual Flutter host capture: `flutter test tool/qa/flutter_port_capture_test.dart --update-goldens --plain-name 'Flutter Inicio 320.0 texto 2.0'` passed; copied its output to `docs/evaluation/flutter-port-2026-10-07/flutter-inicio-320-2x-before.png` before production edits. Viewed this PNG: `727.0…` and within-word heading/description breaks are present.
- New Dashboard regression file: all six cases failed against the original production code: three full amounts (727000, 1234567890, -1234567890), word-boundary layout, missing loading data and initial error. Failures were specifically RenderParagraph.didExceedMaxLines, multiple text boxes for Próximos, and unsupported MoneyText descendants.
- Changed budget detail tests: both light/dark cases failed because SemanticsAction.tap was absent, before adding Semantics.onTap.

## Verification

Final directed command so far:

`flutter test test/features/dashboard/root_accessibility_regression_test.dart test/features/dashboard/savings_overview_test.dart test/features/dashboard/budget_ring_test.dart test/features/budgets/approved_analysis_test.dart --name 'importe|títulos y nombres|pagos sin datos|patrimonio|Inicio|anillo|segment|250|300|340|cero|devoluci'`

Result: **15 passed**, exit 0. Full amount tests use a real Roboto host font, literal expected strings, no paragraph elision, every glyph box transformed into the visible hero bounds, and the complete accessibility label. Layout tests inspect each word's line boxes and scroll both payment names and the second amount into view. Loading/error tests also deliver real empty data afterward and verify recovery.

`flutter analyze --no-pub lib/features/dashboard/presentation/dashboard_screen.dart lib/features/budgets/presentation/budgets_screen.dart test/features/dashboard/root_accessibility_regression_test.dart test/features/budgets/approved_analysis_test.dart`

Result: **No issues found**, exit 0.

The initial combined run of the entire approved_analysis file exposed another root-shell issue: its P01/P02 navigation test saw a 4px AppBar overflow and an obsolete assertion that Plantillas was absent in Más. The test hung during cleanup after failure and was interrupted; shutdown then emitted stream-close errors. The latter was updated per controller instruction to require Plantillas, Movimientos programados and Pagos pendientes, as approved normal Settings entries. The 4px overflow was localized to AnalysisScreen's PreferredSize(64) containing a natural 56px SegmentedButton plus 12px bottom padding (68px).

A new 320/2x analysis-navigation test failed before that correction with 68px vertical overflow. After the height fix, switching to Reports exposed a separate 90px horizontal overflow. Temporary error-details logging localized it specifically to DropdownButtonFormField<int> at ReportsScreen line 122; temporary logging was removed after diagnosis. The new test covers both navigation destinations and now passes. An intermediate count-of-hidden-segmented-buttons assertion was removed because it tested Flutter's IndexedStack finder behavior, not product behavior.

Final complete-file validation:

`flutter test test/features/budgets/approved_analysis_test.dart test/features/dashboard/root_accessibility_regression_test.dart test/features/dashboard/savings_overview_test.dart test/features/dashboard/budget_ring_test.dart test/features/reports/pending_report_screen_test.dart test/features/reports/reports_screen_test.dart`

Result: **20 passed**, exit 0. This includes the complete updated approved_analysis file (root tab persistence, semantic budget activation in both themes, editing/recurrence), initial loading/error recovery, amounts/layout, report selector and existing five-report navigation/data tests.

`flutter analyze --no-pub lib/features/dashboard/presentation/dashboard_screen.dart lib/features/budgets/presentation/budgets_screen.dart lib/features/reports/presentation/analysis_screen.dart lib/features/reports/presentation/reports_screen.dart test/features/dashboard/root_accessibility_regression_test.dart test/features/budgets/approved_analysis_test.dart`

Result: **No issues found**, exit 0.

Initial sandbox execution could not write the external Flutter SDK cache; escalation for authorized Flutter tests/analyze succeeded. One combined write/test command was rejected by automatic review because it interpreted a Python insertion as potentially deleting subsequent tests; no command ran. Used a contextual apply_patch insertion preserving every existing test, then a separately authorized Flutter test invocation. Nothing remains blocked by that rejection. No APK occurred.

## Limits

This verifies Flutter host rendering and semantic activation, not Android TalkBack, native insets, gesture delivery, device font fallback or phone performance. Controller will regenerate after-captures and obtain independent review; full suite belongs to final integration and is not claimed by this directed report.

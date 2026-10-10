# Task 3 · Payment/form UI resume

Scope: approved Flutter port, in place; no prototype changes, APK, Git, or subagents.

## Changes
- Transaction form exposes En cuotas as core expense field; preserves credit calendar/edit path, 2..120 range, Description, exclusive category split, draft reminders, and pending non-credit creation without ledger.
- Type switching preserves the expense installment draft but attaches credit installments only for expense creation. At 320 px with text 2x the type control becomes an expanded dropdown.
- Payment list follows prototype filters Pendientes / Con pagos / Todos; partial paid obligations appear under both pending and paid views.
- PaymentDetailScreen(paymentId: String) in payments_screen.dart supports actual amount/date, active non-credit account, optional partial carry only to existing next installment, history linked to existing ledger editor, future edit scope, confirmed cancellation, and editable reminders with following scope. All mutations pass revision and screen-captured restoreGeneration. Native permission denial does not roll back financial writes.
- Scheduled-template dialog exposes reminder settings, serializes fields.reminders, loads saved settings, uses Preparar pagos pendientes, and removes the outdated automatic-paid explanation. Templates empty-state/pause labels are concise.

## Verification so far
- Direct run: flutter test pending_form_test.dart + pending_screens_test.dart: initial red (En cuotas hidden and missing PaymentDetailScreen), then 4/4 green.
- Direct run: pending_screens_test.dart: 5/5 green, covering partial payment 40000/remain60000; explicit cancellation/no ledger with 320px text2x; invalid amount rollback; 20000 payment plus 30000 carry (next becomes80000); future edit and following reminders without ledger.
- Direct run: manual_template_form_test.dart --plain-name 'Plantilla programada edita': red missing scheduling/reminder control, then 1/1 green (cancel does not persist settings).
- Coordinator red: income after expense-installment toggle produced no ledger; fixture was then found to omit account selection, corrected source/destination selection, and expense guard limits attachPlan; small form overflow62px fixed responsive selector; filter missing Con pagos fixed matching prototype. Regression fixtures updated to scroll lazily built controls, choose explicit accounts, use the active split-mode label and approved En cuotas label while retaining financial assertions. Final revalidation remains required.
- Initial focused analyze had one info curly_braces_in_flow_control_structures; braces corrected and formatting parsed successfully. Final analysis pending coordinator rerun.

## Tool limitation
Later SDK-cache escalations from this agent were rejected by auto-review, which claimed a historical prototype-only restriction still applied, even after current authorization/doc evidence was supplied. Coordinator has current explicit user authorization and is running the remaining tests; no alternative execution was used to bypass rejection. Tests write SDK cache only; no APK generated.

## Still pending
- Coordinator final fresh targeted batch: `flutter test --no-pub test/features/transactions/pending_form_test.dart test/features/transactions/pending_screens_test.dart test/features/templates/manual_template_form_test.dart test/features/transactions/transaction_form_test.dart test/features/transactions/merchant_autocomplete_test.dart` — exit0, 20/20 passed, log `/tmp/cabal-payment-ui.log`. This includes both 320px/text2x form and payment detail. The last overflow62px was traced with full FlutterErrorDetails to the installment dropdown and corrected with isExpanded and one-line ellipsis.
- Final analyze, complete suite, and independent review remain coordinator-owned integration gates.
- Scheduled-template permission denial is green in latest batch. Approved scheduler horizon (end of next month) now asserted as one unpaid future obligation120000, idempotent second processDue, and ledger remains1 for initial manual expense.
- Android delivery with app closed/reboot remains unverified here; UI tests do not establish native delivery.

## Independent review · fix round1
Confirmed P2 from task3-review.md: selecting Guardar también como plantilla then enabling non-credit En cuotas hid the checkbox but made save return early. Added regression through that exact transition with valid bank account, amount, description and save-another; coordinator reproduced RED (no obligations). Cancellation of template collection now applies only when template collection was active (`!pendingPlan`), preserving the checkbox preference in the draft.

Previous payment account: detail derives initial account from the latest active effective payment's date within the same plan, falls back to the planned account only if it remains active/non-credit/PYG, and leaves selection empty if neither is eligible. Explicit user selection wins on rebuild. Planned account storage is unchanged. New widgets exercise bank plan → actual cash payment → next cash suggestion; explicit switch back to bank; inactive cash → planned bank fallback.

Round1 RED coordinator command: `flutter test --no-pub test/features/transactions/pending_form_test.dart test/features/transactions/pending_screens_test.dart` — 11 passed, 2 failed (hidden template intent and active previous-account suggestion), `/tmp/cabal-payment-ui-fix1-red.log`. GREEN coordinator rerun of the same command: 13/13 passed; `/tmp/cabal-payment-ui-fix1-green.log` ends `+13: All tests passed!` (fresh log inspected). Only the two production screens and their two focused widget test files were changed; no domain/prototype/APK changes.

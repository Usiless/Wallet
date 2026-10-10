# Task 3 independent review

Review date: 2026-10-08. Actual Flutter sources are authoritative; the source snapshot was supporting context only. Read AGENTS.md, approved PRODUCT_BASELINE decisions, Task 3 acceptance, implementation report, current form/payment/template/app/router/domain sources, and targeted widget tests. No production edits, prototype changes, APK, or delegated work.

## Verdict

**Changes required: one confirmed P2 defect.** The principal approved flows are present, but a hidden stale template flag can prevent saving a valid pending installment plan without an error. Spec compliance and quality gate remain conditional on fixing that branch and covering the state transition.

## Confirmed finding

### P2 — Hidden template preference silently prevents pending-plan save

File: `lib/features/transactions/presentation/transaction_form_screen.dart`, lines 1042–1048; related visibility condition lines 603–616.

Reproduction: create a bank/cash expense, select a valid account, enter a positive amount and description, enable **Guardar también como plantilla**, then enable **En cuotas**. The template checkbox disappears, but `_alsoSaveTemplate` stays true. On Save, `pendingPlan` is true, so `template` is deliberately null. The subsequent `_alsoSaveTemplate && template == null` branch resets saving and returns before creating any obligation, with no error message or way to clear the invisible preference. The same transition can occur by moving from a credit expense with the preference selected to a non-credit account while installments remain on.

This is a deterministic source-path finding, not an assertion that a new widget reproduction was run. Existing tests start with the template preference false and do not cover this transition. Scope the cancellation check to an actually requested template (`!pendingPlan`), or otherwise resolve the hidden flag consistently; add one regression asserting obligations exist and the ledger remains empty after this transition.

## Verified implementation and existing evidence

- Expense form uses Description, exposes En cuotas, and offers 2 through 120. Its pending path creates obligations; credit uses the existing ledger/installment path. Editing an existing non-credit movement does not invoke pending creation. Single category selection is excluded while split mode is active. Reminder settings and first date participate in the form draft snapshot; inline category creation does not reset these fields.
- Payment list implements Pendientes / Con pagos / Todos and includes partial payments in the first two relevant views. Detail accepts actual amount/date and active non-credit accounts, exposes carry only when an eligible existing following installment exists, links paid ledger history to the editor, supports future unpaid edits, confirmed cancellation, and reminder scope. Each payment mutation supplies its revision and the screen-captured restore generation. Saving reminders precedes permission handling, so permission denial does not undo the financial/configuration write.
- Scheduled template dialog saves reminder settings and uses Preparar pagos pendientes. Existing scheduler test asserts future unpaid obligations, idempotence, and preservation of only the initial actual expense. App/router sources integrate list/detail routes, notification-open routing, and reminder reconciliation after provider changes/resume.
- Coordinator evidence `docs/evaluation/flutter-port-2026-10-07/payment-ui-tests.log` ends **20/20 passed**. This covers form/payment 320px and text 2x, amount-error rollback, cancellation, partial payment/carry, future edit/reminder scope, category exclusion and legacy credit regression. Per assignment, this duplicate batch was not rerun.

## Limits

No fresh device rendering or native delivery was claimed. Existing 320px/text2x tests do not establish every long account/category label or every dialog layout; no additional confirmed overflow was identified from source alone. Android closed-app/reboot delivery, full-suite/analyzer integration gates, and Task 1/2 domain/native review remain coordinator-owned. No additional explanatory UI copy was identified in the Task 3 additions; financial status/date subtitles are transaction data rather than unsolicited help.

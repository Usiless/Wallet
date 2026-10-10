# Independent scoped re-review: Task 2 / Task 3 fix round 1

Date: 2026-10-08. Reviewed the original task2-review.md and task3-review.md, task2-fix1-report.md and task3-report.md, AGENTS.md, PRODUCT_BASELINE and the approved Flutter port plan. Current amended sources are authoritative; task2.diff is an original implementation snapshot, not a historical fix diff. No Git baseline was assumed. Scope is the confirmed findings, their fixes and regressions introduced by those fixes; this is not a fresh full-task review.

## Task 2

**Spec verdict: PASS for the scoped findings. Quality verdict: PASS for the scoped fixes, with Android runtime validation still open.**

### Finding 1 — Unrelated reconciliation removes notices and invalidates actions: ADDRESSED

- The coordinator now includes elapsed reminder identities for enabled, unpaid, uncancelled obligations (`payment_reminder_coordinator.dart:40–48`), so future-only planning no longer drops an unchanged delivered request during ordinary resume.
- `PaymentReminderReplacement.kt` retains each unchanged entry's generation, invalidates only removed/changed signatures, and prunes delivery markers to retained IDs. The signature used by the actual agenda includes obligation ID, title, body, local datetime and obligation revision (`PaymentReminderReceiver.kt:79–83`). Thus meaningful edits invalidate old actions even if the reminder date is unchanged.
- The receiver persists the replacement before selective alarm/notice cancellation (`:103–117`); consume and delivery compare the persisted entry generation (`:134–167`). Unchanged notices are not cancelled. Paid/cancelled/disabled obligations disappear from incoming entries and their old notices/actions are invalidated. No ledger writes occur in the native action or replacement path.
- Newly introduced historical entries are marked delivered/skipped. Known unchanged overdue entries retain delivery eligibility; delivered entries remain done. The agenda schedules only future entries, and notify marks delivery before emission. This prevents the new retention policy from flooding historical notices when a later alarm fires.
- MainActivity stores the new intent before signalling the capture callback (`MainActivity.kt:26–30`), and the app consumes the open action before reconciliation. This addresses warm foreground notification taps at source level without changing financial state.

Coverage: the actual pure replacement helper's four JUnit tests cover unchanged notice identity with unrelated removal, edited action invalidation without historical redelivery, new historical skips versus known delayed eligibility, and complete removal. The coordinator regression additionally preserves elapsed IDs after an unrelated obligation is fully paid and removes them when the obligation itself is paid. This is meaningful state-transition coverage; it does not execute Android notification managers or intent dispatch.

### Finding 2 — Accepted settings poison the entire reconciliation: ADDRESSED

The actual current UI, PaymentReminderSettings.validate(), scheduler and pending backup validation now use 0..60 days. Domain creation/update invokes settings validation. The coordinator catches each legacy unsupported setting individually, continues with valid open obligations, replaces the whole agenda, and returns false. A legacy 61-day record therefore cannot retain stale entries for another paid/cancelled obligation. The coordinator regression explicitly combines invalid 61 days, a valid record and a fully paid record and asserts only the valid reminders reach the bridge.

No new confirmed breakage found in these fixes. Keeping all current open historical identities increases native state relative to future-only planning; the explicit 20,000-request guard remains a practical limit. This review did not establish a capacity failure. Reboot/time/timezone rebuild still does not catch up elapsed alarms; that was already an original review limitation and is not newly introduced or claimed fixed here.

## Task 3

**Spec verdict: PASS for the scoped finding and account proposal correction. Quality verdict: PASS for these scoped fixes.**

### Finding — Hidden template preference silently blocks pending-plan save: ADDRESSED

`transaction_form_screen.dart:1037–1048` now applies the null-template cancellation guard only when template collection was requested (`!pendingPlan`). It leaves the hidden preference in draft state rather than silently resetting it when toggling installments. The pending path still calls createPlan and returns before the ledger/template path (`:1118–1138`). The regression selects the template preference, enables installments, switches type away and back, and saves; it asserts two obligations totaling 100000 and an empty ledger. This covers the original blocking state plus draft persistence through type changes. Credit and ordinary template collection retain their existing cancellation guard.

### Account proposal correction: VERIFIED

`payments_screen.dart:247–301` derives the suggestion from the latest effective payment date within the same plan. The eligibility list excludes archived accounts, credit cards and non-PYG accounts. An ineligible previous account falls back to the planned account only when eligible; otherwise selection stays empty. `_userSelectedAccount` preserves an explicit choice on subsequent rebuilds for the same loaded revision. The proposal does not rewrite the planned account.

The added widgets cover bank plan → actual cash payment → next cash suggestion, explicit selection back to bank, and archived cash → planned bank fallback. They also assert that stored planned account remains bank. The source branch covers no eligible fallback; this case is not separately asserted by the new widgets. No explanatory interface copy was added by these fixes. No new confirmed breakage found in the amended guard/account-selection code.

## Verification evidence and limits

- Inspected fresh coordinator-owned `docs/evaluation/flutter-port-2026-10-07/kotlin-check.log`: **OK (4 tests)** and **All Kotlin app sources compile; 4 pure policy tests pass. No APK generated.** This is direct Kotlin compilation plus pure JUnit, not a Gradle Android/device run.
- Inspected fresh `/tmp/cabal-payment-ui-fix1-green.log`: **+13: All tests passed!** for the focused pending form/payment screens. Parent will persist that log.
- Task 2's focused Flutter run of **7 passing tests** and clean targeted analyzer are prior fix-report evidence, not independently rerun here.
- No duplicate full domain/UI tests, implementation edits, subagents, prototype changes or APK compilation were performed by this reviewer. Only this review artifact was written. Native permission/reboot/timezone/process death/cold and warm tap/device delivery checks remain unverified; consolidated analyzer/full suite gates remain parent-owned.

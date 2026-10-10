# Task 1 — resumed domain port, 2026-10-08

## Scope and current state

Worked in place; no Git repository, no preserved pre-port diff baseline, no available earlier /tmp snapshot. Did not modify prototype or compile/build an APK. Domain changes are ready for independent review; final batch verification is assigned to root because two SDK escalation requests were rejected by automatic approval review using obsolete HTML-only authorization. Root supplied current explicit human authorization (Flutter/Dart port, Flutter analyze/tests, latest «continúa»); no tool bypass attempted. The last retry was interrupted by the user.

Changes present:

- Pending payment create/update reminder validation uses 0..60 days, hours0..23/minutes0..59. Removed empty freshness stub; restore-generation guards remain.
- Linked payments hydrate actual ledger amount, date, account and category splits. Deleted/reversed payments reopen residual; watchers also observe transaction splits.
- Residual category debt removes negative category entries and scales positive residues exactly to actual remaining debt after recategorization. Historical ledger category assignments and plan base categories remain unchanged. Regression fixture A60/B40 with actual paymentB80 leaves A20.
- Ledger edits/deletes/restores bump linked obligation revision transactionally. Edit/restore cannot exceed the obligation after other confirmed payments and carried residual, preventing old payment restoration after replacement.
- Repeated carry after deletion accumulates category trace and records additive carry history; no invented next installment. Latest cumulative-carry change awaits root verification.
- Future unpaid template economic/reminder edits validate account/merchant/categories/channel before mutating pending settings; propagate reminder settings and invalidate pending revision, retaining paid obligations. Scheduler reads template reminder settings and continues current+following-month horizon. Schedule-only date/frequency changes are not currently reconciled against already prepared future obligations: review this remaining edge case before claiming full Task1 acceptance.
- Report current totals include residual pending with account/category filter; actual rankings/trends/previous-period figures remain actual-only, matching prototype and root direction. Budget service consumes these report totals.
- Backup validator uses actual snapshot table `transactions` (previous code wrongly used `ledger_transactions`). Historical original payment metadata no longer must equal edited actual ledger metadata; confirmed actual amounts determine overpayment check. Added strict installment bounds, payment-channel validity, unique category references, globally unique payment links, obligation-specific external fingerprint links, carry totals/history/target checks, max60 reminders.
- Archived original merchant/category remain historical references on payment; LedgerService.create already permits these (no behavior change). Added characterization test awaiting root verification.
- Account suggestion for later installments is owned by payment UI; no propagation of planned account to future obligations.

## Verification actually observed

1. `flutter test test/pending_payment_service_test.dart test/features/templates/scheduled_template_service_test.dart`: exit0, **11 tests passed** before new regressions.
2. Reminder-bound and actual-payment-category regressions: observed intended RED (accepted61days; categoryA30 instead of60), then `flutter test test/pending_payment_service_test.dart`: exit0, **5 passed**.
3. Linked ledger overpayment/revision regression: observed RED (101 permitted for100 obligation), then targeted file exit0, **6 passed**.
4. Residual category/backup run: RED showed negative B-40 and backup wrong table reference, including original linked backup test failing. After fixes, `flutter test test/pending_payment_service_test.dart test/core/backup/backup_service_test.dart`: exit0, **13 tests passed**. Existing Drift multiple-database warning was emitted by backup portable encrypted-storage test; not a test failure.
5. `flutter test test/pending_payment_service_test.dart test/features/templates/scheduled_template_service_test.dart test/features/reports/report_analysis_test.dart`: **24 passed,1 failed** at that stage: `reopened carried installment preserves cumulative category carry` expected75 got25. Patched cumulative trace afterward, not rerun yet. Template reminder and invalid-account transaction regressions passed in this run; report category residual test passed.
6. `flutter test test/core/backup/backup_service_test.dart --plain-name 'backup rejects forged unrelated payment and invalid installment metadata'`: observed intended RED (forged unrelated ledger expense accepted). Strict backup repair applied afterward, not rerun yet.
7. Direct bundled `dart format` completed successfully for11 files, then backup file again; no syntax/parser error. No final analyze or full-suite claim.

## Root batch needed

```
flutter test test/pending_payment_service_test.dart test/features/templates/scheduled_template_service_test.dart test/features/templates/manual_template_service_test.dart test/core/backup/backup_service_test.dart test/features/reports/report_analysis_test.dart test/features/budgets/budget_service_test.dart test/features/transactions/ledger_service_test.dart test/features/notifications/notification_ingestion_service_test.dart
flutter analyze
flutter test
```

Root also reported an old widget expectation `processDue.registered.isEmpty` in manual-template form: current+next-month horizon legitimately prepares next month's pending while current consumed ledger date remains deduplicated. UI agent is adjusting regression to assert correct next-month pending + one actual ledger movement.

## Remaining review concerns

Schedule-only template edits against pre-generated horizon need review; amount/category edits to an obligation that already has carry must not shrink below carried debt. Backup carry/category semantic validation should receive independent adversarial review. Android notification delivery/OEM behavior remains outside host tests and no device validation is claimed.

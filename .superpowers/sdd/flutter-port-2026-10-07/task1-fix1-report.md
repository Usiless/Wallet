# Task 1 — financial fix round 1, 2026-10-08

Addressed the four findings in task1-review.md, in assigned domain files only. No UI/prototype changes, APK operation, Git operation, or historical-plan rewrite. Root controls any final APK generation under the updated human authorization.

## Repairs

1. **Nonnegative exact installment matrix.** New-plan category allocation uses largest integer remainders against remaining column capacities. Each row equals its installment, no category exceeds its remaining capacity, and the final column totals match the original category amounts. The 10/2 fixture A3/B3/C3/D1 produces two nonnegative rows and actual paid category totals A3/B3/C3/D1. This alters only newly generated plans.
2. **Editing debt already carried.** Validate the proposed amount against paidMinor+carriedMinor before mutation. Preserve carried category amounts as a fixed part of the plan and scale only the editable residual allocation. A deleted40 payment with60 carried rejects a50 edit; equality60 leaves exactly A36/B24 transferred and no residual, and roundtrips through encrypted backup.
3. **User calendar reconciliation.** ManualTemplateService.save defaults to reconciling user calendar changes (nextDate/frequency/anchorDay/anchorMonth). Upcoming occurrences with no historical payment link are canceled, marked supersededBySchedule and revision-invalidated. Scheduler bookkeeping, pause and skip pass reconcilePreparedSchedule:false. Scheduler deduplication ignores only calendar-superseded records so a user can return to a previously superseded date; ordinary manually canceled and historical paid/deleted records retain dedupe. Monthly date and monthly→yearly regressions preserve actual payment links and produce only the new upcoming due date even after repeated processing.
4. **Complete portable carry trace.** A positive carried amount requires a nonempty history with valid same-plan later installment targets, matching installmentCount, positive amounts, valid nonduplicated category references, per-transfer category totals, cumulative per-category totals and the exact global carry sum. carriedTo must match the final destination. Zero carry rejects unexpected nonempty history/target/category trace. Valid old v1 carriedTo records are normalized to a history using their existing amount/category trace, then subjected to the same checks; missing targets are never invented. Categorized and unclassified orphan20 records are rejected, while real transfers roundtrip in both cases.

## Red/green evidence

- Root executed `flutter test test/pending_domain_fix_round1_test.dart` before implementation and reported **5 RED** cases. Source findings correspond to negative matrix money, below-carry edit acceptance, both calendar edits retaining old pending debt, and orphan carry backup acceptance.
- Implementer GREEN:

```
flutter test test/pending_domain_fix_round1_test.dart test/pending_payment_service_test.dart test/features/templates/scheduled_template_service_test.dart test/core/backup/backup_service_test.dart
```

Exit0, **30 tests passed**, elapsed41s. Existing backup portable-encrypted-storage test emitted the existing Drift multiple-database warning; no test failed.

- Final expanded financial regression:

```
flutter test test/pending_domain_fix_round1_test.dart test/pending_payment_service_test.dart test/features/templates/scheduled_template_service_test.dart test/features/templates/manual_template_service_test.dart test/core/backup/backup_service_test.dart test/features/reports/report_analysis_test.dart test/features/budgets/budget_service_test.dart test/features/transactions/ledger_service_test.dart test/features/notifications/notification_ingestion_service_test.dart
```

Exit0, **59 tests passed**, elapsed39s. Same existing Drift warning from backup_service_test.dart:267; no failures.

- Targeted analysis:

```
flutter analyze lib/features/payments/domain lib/features/templates/manual_template_service.dart lib/features/templates/scheduled_template_service.dart lib/core/backup/backup_service.dart test/pending_domain_fix_round1_test.dart
```

Initial run identified6 brace-style infos. Fixed those, reran: exit0, **No issues found! (ran in0.8s)**.

Direct bundled Dart format parsed/formatted all changed files successfully. Independent re-review and root's final whole-app analysis/full-suite verification remain separate gates; this report does not claim those completed or Android/device verification.

## Files

- lib/features/payments/domain/pending_payment_service.dart
- lib/features/templates/manual_template_service.dart
- lib/features/templates/scheduled_template_service.dart
- lib/core/backup/backup_service.dart
- test/pending_domain_fix_round1_test.dart

No reliable original Git diff is available in this workspace. The earlier task1-report.md is historical context; this fix report supersedes its listed known schedule-only and below-carry edit gaps.

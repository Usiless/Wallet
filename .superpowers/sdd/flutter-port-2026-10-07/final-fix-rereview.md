# Final scoped Wallet re-review · 2026-10-09

**P1: ADDRESSED. Spec verdict: PASS. Quality verdict: PASS for the final repair. No new confirmed breakage introduced by this diff.** This closes the single outstanding code finding in final-review.md. The prior residual finding remains addressed. The independent integration review gate is now satisfied; final global verification, final APK identity/flags/signature/hash checks and accurate delivery documentation remain controller-owned.

## Scope and source verification

Reviewed the remaining P1 in final-review.md, final-scheduled-wallet-fix-report.md, final-scheduled-wallet-fix.diff, and actual current ingestion/test files. This was a scoped re-review, not another broad audit. No tests were rerun and no production/prototype/native code, APK or subagent work was performed.

Both ledger predicates now recognize `sourceReference LIKE scheduled:%` and `externalFingerprint LIKE pending:%` in addition to the historical recurring/scheduled markers. Their OR grouping remains inside the existing three-day branch. The same actual ledger account, merchant, amount, status and date conditions continue to apply. The process precheck leaves the candidate pending, while automatic confirm independently rechecks ledger state inside its database transaction. Full payment no longer falls through merely because the obligation's residual is zero; a partial actual payment is matched by its ledger amount rather than nominal/residual obligation amount.

The ordinary two-minute branch is unchanged. Unlinked ordinary manual expenses do not acquire the extended window. The earlier original-or-residual open-obligation checks remain intact, so this correction complements rather than replaces that protection. No producer, storage schema, source identity, permissions, native integration or UI logic changed.

## Regression quality and evidence

The nine new cases cover process and stale automatic confirm for template and non-template obligations, with full100 and partial40 payments. Real ManualTemplateService/ScheduledTemplateService prepare template fixtures; PendingPaymentService creates effective ledger payments. Wallet is one hour later, so the old ordinary two-minute guard cannot hide the original defect. Candidate creation precedes payment in stale-confirm cases, directly exercising the transactional recheck.

Assertions require pending status, exactly one original ledger payment and debit, preserved manual source/pending fingerprint and residual0 or60. The ordinary manual100 control still auto-registers a later Wallet100 and asserts two ledger rows, demonstrating that the repair did not globally widen manual matching. The original five residual regressions remain in the focused suite. These tests cover the reported outcomes, not just the predicates' implementation.

The implementer's report and controller report record corrected-fixture RED with eight behavioral failures and one passing ordinary control, followed by **40/40 focused GREEN**. The report explicitly distinguishes its earlier fixture-order issue from the meaningful RED rerun. I inspected the test source and current correction; I did not independently rerun that batch. Global suite/analyzer were still running when this scoped verdict was written, so this report does not invent their final result.

No additional repair or broad review is requested. Physical Android behavior and freeze/performance limitations remain exactly as recorded in final-review.md; this acceptance does not certify those runtime paths.

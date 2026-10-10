# Task 1 — independent fix round 2 re-review, 2026-10-08

**Spec verdict: PASS for this repair. Quality verdict: PASS. The P2 from task1-fix1-rereview.md is ADDRESSED.**

Reviewed task1-fix2-report.md, task1-fix2.diff, current `pending_payment_service.dart:436`, and the new first regression in pending_domain_fix_round1_test.dart. This is a narrow re-review of the guard-order correction; the earlier four findings remain addressed per task1-fix1-rereview.md. No financial re-audit, test rerun, production/prototype edit, Git/APK operation, or subagent.

The only production change moves `if (q.paidMinor > 0) continue` ahead of the proposed-amount check. Therefore installments intentionally preserved no longer veto edits of other unpaid installments. Every obligation actually modified still passes the positive-amount and paid-plus-carried lower bound before category/date/amount mutation, inside the existing transaction.

The new regression directly matches the reported case: plan300/3, pay80 on installment2, edit installment1 to50 with following:true. It checks amounts[50,100,50], residuals[50,20,50], preserved second payment/revision, and equality of the original ledger record. This meaningfully checks the intended preservation behavior. The implementer reports the expected RED FormatException, then15 passing tests including the original carry60/edit50 rejection and equality/backup case, plus clean targeted analysis. No new issue found in the two-line repair. Whole-app and Android/device validation remain separate.

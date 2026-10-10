# Task 1 — fix round 2, 2026-10-08

Addressed the P2 guard-order regression from task1-fix1-rereview.md. Only production change: move the already-paid installment skip before the proposed-amount lower-bound check. Preserved paid installments no longer reject a following edit; obligations actually edited still enforce their carry lower bound. No UI/prototype/APK operation.

Regression added to test/pending_domain_fix_round1_test.dart: create300/3, pay80 on second installment, edit first to50 with following:true. Assert amounts[50,100,50], residuals[50,20,50], second paid80/revision1, and exact original ledger record unchanged.

## Verification

- RED command:

```
flutter test test/pending_domain_fix_round1_test.dart --plain-name 'following edit preserves partly paid later installments and their ledger'
```

Exit1, expected FormatException `El importe debe cubrir lo pagado y trasladado.` from pending_payment_service.dart:439, before fixing production. An initial invocation before the test insertion succeeded ran no matching test (exit79); corrected insertion and then observed the meaningful RED above.

- GREEN command:

```
flutter test test/pending_domain_fix_round1_test.dart test/pending_payment_service_test.dart
```

Exit0, **15 tests passed**, elapsed18s. Includes original deleted-payment/carry60/edit50 rejection, equality60 exact categories and backup roundtrip, all fix-round1 cases and existing pending payments.

- Analysis:

```
flutter analyze lib/features/payments/domain/pending_payment_service.dart test/pending_domain_fix_round1_test.dart
```

Exit0, **No issues found! (ran in0.8s)**.

Snapshot task1-fix2-before.dart and task1-fix2.diff isolate the two-line production repair relative to the current reviewed source just before round2. They are not an original historical/pre-port Git diff. Source stable and production slot released to root before verification completed.

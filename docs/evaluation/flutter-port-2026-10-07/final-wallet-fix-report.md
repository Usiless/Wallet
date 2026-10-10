# Final Wallet residual fix · 2026-10-09

## Defect and correction

An open pending payment with original amount 100 and a recorded partial payment of 40 has remaining debt 60. Normal recognized Wallet notification for 60 previously passed both duplicate guards and created an unlinked expense, retaining the pending 60.

Only `lib/core/notifications/notification_ingestion_service.dart` production logic changed: both `process` and transactional `confirm(automatic: true)` now accept an exact match against either original `amountMinor` or hydrated `remainingMinor`. Existing open/not-cancelled, same account, same merchant and three-day predicates remain unchanged. Original-total protection remains. No fuzzy amounts or broader matching were added.

## Regression evidence

New `test/features/notifications/wallet_pending_residual_test.dart` uses the real in-memory database, account/merchant services, pending-payment service and ingestion service. It supplies normal Google Wallet envelopes, enables normal listener/auto-register settings, and uses no SMS or developer flags.

Five cases:
- `process` retains residual 60 for review.
- A stale candidate automatically confirmed after a new partial-payment conflict is rejected for residual 60.
- Both paths retain original-total 100 protection.
- Unmatched 61 still auto-registers, proving the fixture can reach normal automation.

Blocked cases verify candidate remains pending, one ledger transaction of 40, one account posting of -40, and one pending obligation with original 100 / remaining 60. No extra expense, debit or debt is created.

RED: new tests ran against unchanged production source: 3 passed / 2 failed. Both residual cases failed behaviorally (confirmed instead of pending; automatic confirm returned an expense id instead of throwing). Original-total and unmatched control passed. See `final-wallet-red.log`.

GREEN: focused Wallet ingestion, automation and scheduled-template suites: exit 0, 31/31 passed. See `final-wallet-green.log`.

Analysis: `flutter analyze`, exit 0, no issues. See `final-wallet-analyze.log`.

Full suite: `flutter test`, exit 0, 240/240 passed (47 seconds). See `final-wallet-suite.log`; canonical logs updated at `docs/evaluation/flutter-port-2026-10-07/flutter-test.log` and `flutter-analyze.log`, preserving prior logs with `-before-wallet-residual.log` suffix. The complete suite emits a Drift multiple-database warning from existing `backup_service_test.dart:267`; no failing tests. Focused suite is clean.

## Review artifacts and scope

`final-wallet-fix.diff` is a unified diff against source captured immediately before this change, plus the new test file. Original source retained as `final-wallet-ingestion-before.txt`. This checkout exposes an empty read-only `.git`, so the diff was generated from that captured source rather than claiming a Git baseline.

No UI, prototype, native Android, domain/storage changes or APK builds were performed. Previously compiled APK candidate does not contain this fix; controller owns independent review and any explicitly authorized final rebuild/delivery.

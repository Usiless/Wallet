# Task 2 independent spec and quality review

Reviewed 2026-10-08 against AGENTS.md, PRODUCT_BASELINE reminder decisions and docs/superpowers/plans/2026-10-07-approved-prototype-flutter.md. Scope: task2.diff and current Dart scheduler/bridge/coordinator, app integration, native agenda/receiver/activity/manifest, related reminder controls and validation. Review only; no implementation edits, Git, prototype edits, APK or native build.

**Spec verdict: changes required. Quality verdict: changes required.** The intended separation is present: notifications do not write the ledger, native storage is encrypted using DeviceCrypto, the default wall clock is 09:00 three days before and on the due date, and cancellation/fully paid filtering exists. Two confirmed defects prevent acceptance of idempotent reconciliation and editable reminders.

## Confirmed findings

### [P2] Unrelated reconciliation destroys existing reminder notifications and their action identity

`android/app/src/main/kotlin/py/finanzaslocales/finanzas_locales/PaymentReminderReceiver.kt:93–99` creates a fresh UUID for every replacement and unconditionally cancels every notification belonging to the old requests. `consume()` rejects the old generation at line 151. `lib/app/app.dart:163,180–187` invokes reconciliation on ordinary resume and payment stream updates, including changes unrelated to a particular obligation. Thus a delivered reminder still awaiting review disappears when the user opens the app normally or updates another obligation; it is not displayed again because its delivery marker is retained at native line 94. Even a byte-identical request set changes generation and invalidates existing notification PendingIntents. This is an observable non-idempotent effect, not merely extra scheduling work.

The Dart planner also omits elapsed requests (`lib/core/notifications/payment_reminder_scheduler.dart:48`), so merely preserving native notices whose IDs occur in the new future-only list is insufficient: unchanged delivered obligations need an explicit retention/validity policy. Preserve displayed reminders and their action validity until the relevant obligation is paid, cancelled, disabled or meaningfully changed; selectively invalidate removed/changed obligations. Add coverage for unchanged replacement and unrelated payment changes, in addition to stale-generation rejection.

### [P2] Accepted reminder settings can make all reconciliation fail silently

`lib/core/notifications/payment_reminder_scheduler.dart:29–37` rejects `daysBefore > 60` before creating/replacing the agenda. Current controls expose 0 through 365 (`lib/features/payments/presentation/payment_reminder_fields.dart:13`), and `PendingPaymentService.updateReminders()` accepts through 365 (`lib/features/payments/domain/pending_payment_service.dart:399–406`). Backup validation does not impose a 60-day maximum either (`lib/core/backup/backup_service.dart:296–304`). A user can therefore save 61 days through the normal UI, after which the single coordinator call throws for the complete list. `lib/app/app.dart:55–58` suppresses the error and leaves the previous native agenda in force. Other obligations paid/cancelled afterward can retain stale alarms because reconciliation continues to fail. Validation happens before the scheduler checks `enabled` (line 39), so disabling that record does not repair the mismatch.

Use the same approved range throughout UI, domain, backup and scheduler, and test a saved boundary setting through the coordinator. A malformed or unsupported setting must not silently keep reminders for obligations that are already paid/cancelled.

## Other inspected behavior and limits

- Native generation is persisted before old alarm cancellation; stale queued broadcasts are rejected against persisted generation. Requests are validated before replacement. Delivery marks are persisted before notification emission, providing at-most-once attempts across process death, with an acknowledged tradeoff that death/revocation between persistence and notify can lose that attempt.
- The manifest registers boot, time, timezone and package-replacement rebuilding. Native date parsing uses the current default timezone; immutable explicit PendingIntents include distinct URI identities. Permission checks cover app and channel state. Denied-permission reconciliation still replaces stored requests and cancels prior alarms. These are source observations, not Android runtime validation.
- Native notification content uses private lockscreen visibility; descriptions are stored encrypted in preferences. No financial writes were found in the receiver/agenda or notification action. Flutter opens the obligation route after looking it up; the existing lock gate remains around the routed content.
- Alarm delivery is inexact. Rebuilding only schedules future instants, and the foreground planner also drops elapsed ones. A pending delayed alarm can consequently be removed by a clock/rebuild/resume before delivery. Whether missed reminders should catch up needs an explicit policy and Android lifecycle tests; the current host tests only assert that elapsed planner inputs are omitted. Do not claim reliable delivery or catch-up from these tests.
- Delivered IDs accumulate without pruning. This warrants a bounded retention policy for long-lived use, but no measured resource failure is claimed here.

## Validation evidence

Read the provided diff and actual implementation and inspected both reminder test files. The present files contain four scheduler/bridge tests plus one coordinator test; mocks do not execute the Kotlin agenda, NotificationManager, AlarmManager, reboot handling or notification taps.

Attempted command:

```text
flutter test test/core/notifications/payment_reminder_test.dart test/features/payments/payment_reminder_coordinator_test.dart
```

The command exited 1 before running tests: Flutter attempted to update `/home/ulises/development/flutter/bin/cache/engine.stamp.tmp.28` and `engine.realm`, which are read-only in this sandbox. The previous implementation's passing test/analyzer claims were not re-established by this review. No native compilation was performed. Physical/emulated Android checks remain required for notification permission changes, cold/warm taps, reboot/unlock, time/timezone changes, inexact alarm delay, process death and OEM power restrictions.

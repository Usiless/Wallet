import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/security/app_lock_service.dart';
import '../core/notifications/native_notification_bridge.dart';
import '../core/notifications/payment_reminder_coordinator.dart';
import '../core/config/feature_flags.dart';
import '../features/payments/domain/pending_payment_service.dart';
import '../shared/widgets/app_lock_gate.dart';
import 'providers.dart';
import 'router.dart';
import 'theme/app_theme.dart';

final class FinanzasApp extends ConsumerStatefulWidget {
  const FinanzasApp({super.key});

  @override
  ConsumerState<FinanzasApp> createState() => _FinanzasAppState();
}

class _FinanzasAppState extends ConsumerState<FinanzasApp>
    with WidgetsBindingObserver {
  bool _processing = false;
  bool _initialReminderActionRead = false;
  bool _syncingReminders = false;
  bool _reminderRefreshRequested = false;
  bool _refreshRequested = false;
  List<PendingPayment>? _reminderPayments;
  bool _reminderForceRequested = false;
  final _reminderCoordinator = PaymentReminderCoordinator();
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  late final NativeNotificationBridge _captureBridge;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _captureBridge = ref.read(nativeNotificationBridgeProvider);
    _captureBridge.setCaptureHandler(() async {
      if (mounted &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        await _ingestNativeQueue();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _ingestNativeQueue());
  }

  Future<void> _reconcileReminders({
    List<PendingPayment>? payments,
    bool force = false,
  }) async {
    if (payments != null) _reminderPayments = payments;
    _reminderForceRequested |= force;
    if (!_initialReminderActionRead || !mounted) return;
    if (_syncingReminders) {
      _reminderRefreshRequested = true;
      return;
    }
    _syncingReminders = true;
    try {
      do {
        _reminderRefreshRequested = false;
        final force = _reminderForceRequested;
        _reminderForceRequested = false;
        final payments =
            (force ? null : _reminderPayments) ??
            await ref.read(pendingPaymentServiceProvider).list();
        if (!mounted) return;
        await _reminderCoordinator.synchronize(
          ref.read(paymentReminderBridgeProvider),
          payments,
          force: force,
        );
      } while (_reminderRefreshRequested && mounted);
    } catch (_) {
      // Storage and platform failures are retried on the next change/resume;
      // permission is requested only from the explicit reminder controls.
    } finally {
      _syncingReminders = false;
    }
  }

  Future<void> _ingestNativeQueue() async {
    if (_processing) {
      _refreshRequested = true;
      return;
    }
    _processing = true;
    try {
      try {
        final paymentId = await ref
            .read(paymentReminderBridgeProvider)
            .consumeOpenAction();
        if (mounted && paymentId != null) {
          final payment = await ref
              .read(pendingPaymentServiceProvider)
              .read(paymentId);
          if (mounted)
            ref
                .read(routerProvider)
                .go(
                  payment == null
                      ? '/payments'
                      : '/payments/${Uri.encodeComponent(paymentId)}',
                );
        }
      } catch (_) {
        // Platform channel is unavailable in host rendering/tests.
      } finally {
        _initialReminderActionRead = true;
      }
      final action = await ref
          .read(nativeNotificationBridgeProvider)
          .getInitialAction();
      if (action == 'py.finanzaslocales.QUICK_EXPENSE') {
        ref.read(routerProvider).go('/transactions/new?type=expense');
      } else if (action == 'py.finanzaslocales.OPEN_INBOX') {
        ref.read(routerProvider).go('/inbox');
      }
      final settings = ref.read(settingsProvider);
      final wallet = await settings.readBool('notification_listener_enabled');
      final sms =
          developerToolsEnabled &&
          await settings.readBool('sms_notifications_enabled');
      if (!developerToolsEnabled) {
        await settings.write('diagnostic_mode', 'false');
        await settings.write('sms_notifications_enabled', 'false');
      }
      await ref
          .read(nativeNotificationBridgeProvider)
          .configure(
            enabled: wallet || sms,
            diagnosticMode:
                developerToolsEnabled &&
                await settings.readBool('diagnostic_mode'),
            allowedPackages: {
              if (wallet) ...{
                'com.google.android.gms',
                'com.google.android.apps.walletnfcrel',
              },
              if (sms) 'com.google.android.apps.messaging',
            },
          );
      final events = await ref
          .read(nativeNotificationBridgeProvider)
          .queuedEnvelopes();
      for (final event in events) {
        if (event.isTest && !developerToolsEnabled) continue;
        if (event.packageName == 'com.google.android.apps.messaging' && sms) {
          await ref.read(smsNotificationIngestionProvider).ingest(event);
        } else if (wallet || (developerToolsEnabled && event.isTest)) {
          await ref.read(notificationIngestionProvider).process(event);
        }
        await ref.read(nativeNotificationBridgeProvider).acknowledge(event);
      }
      await ref.read(notificationIngestionProvider).purgeExpiredRawEvents();
    } catch (_) {
      // Android access may be unavailable; explicit refresh remains available.
    } finally {
      try {
        final result = await ref
            .read(scheduledTemplateServiceProvider)
            .processDue();
        if (mounted &&
            (result.registered.isNotEmpty || result.pending.isNotEmpty)) {
          _messenger.currentState?.showSnackBar(
            SnackBar(
              content: Text(
                '${result.registered.length} pagos pendientes preparados. ${result.pending.length} por revisar.',
              ),
              action: SnackBarAction(
                label: 'Ver',
                onPressed: () => ref.read(routerProvider).push('/payments'),
              ),
            ),
          );
        }
      } catch (_) {
        // Failed storage access leaves the schedule intact for the next opening.
      }
      try {
        await ref.read(budgetServiceProvider).ensureCurrentMonth();
      } catch (_) {
        if (mounted) {
          _messenger.currentState?.showSnackBar(
            const SnackBar(
              content: Text(
                'No se pudieron preparar los presupuestos mensuales. Volvé a intentar desde Análisis.',
              ),
            ),
          );
        }
      }
      await _reconcileReminders(force: true);
      _processing = false;
      if (_refreshRequested && mounted) {
        _refreshRequested = false;
        await _ingestNativeQueue();
      }
    }
  }

  @override
  void dispose() {
    _captureBridge.setCaptureHandler(null);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _ingestNativeQueue();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pendingPaymentsProvider, (_, next) {
      if (next.hasValue) _reconcileReminders(payments: next.requireValue);
    });
    final router = ref.watch(routerProvider);
    final lock = AppLockService(ref.watch(settingsProvider));
    return MaterialApp.router(
      scaffoldMessengerKey: _messenger,
      title: 'Cabal',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      locale: const Locale('es', 'PY'),
      supportedLocales: const [Locale('es', 'PY'), Locale('es')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) =>
          AppLockGate(service: lock, child: child ?? const SizedBox.shrink()),
    );
  }
}

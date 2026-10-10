import 'package:flutter/services.dart';

import '../config/feature_flags.dart';
import 'notification_envelope.dart';

final class NativeNotificationBridge {
  const NativeNotificationBridge();

  static const _channel = MethodChannel(
    'finanzas_locales/notification_listener',
  );

  void setCaptureHandler(Future<void> Function()? handler) {
    _channel.setMethodCallHandler(
      handler == null
          ? null
          : (call) async {
              if (call.method == 'notificationCaptured') await handler();
              return null;
            },
    );
  }

  Future<bool> isAccessGranted() async =>
      await _channel.invokeMethod<bool>('isAccessGranted') ?? false;

  Future<void> openAccessSettings() =>
      _channel.invokeMethod<void>('openAccessSettings');

  Future<bool> requestOwnNotificationPermission() async =>
      await _channel.invokeMethod<bool>('requestOwnNotificationPermission') ??
      false;

  Future<void> configure({
    required bool enabled,
    required bool diagnosticMode,
    required Set<String> allowedPackages,
  }) {
    return _channel.invokeMethod<void>('configure', {
      'enabled': enabled,
      'diagnosticMode': developerToolsEnabled && diagnosticMode,
      'allowedPackages': allowedPackages
          .where(
            (package) =>
                const {
                  'com.google.android.gms',
                  'com.google.android.apps.walletnfcrel',
                }.contains(package) ||
                (developerToolsEnabled &&
                    package == 'com.google.android.apps.messaging'),
          )
          .toList(growable: false),
    });
  }

  Future<List<NotificationEnvelope>> queuedEnvelopes() async {
    final values =
        await _channel.invokeListMethod<Object?>('queuedEnvelopes') ?? const [];
    return values
        .whereType<Map<Object?, Object?>>()
        .map(NotificationEnvelope.fromMap)
        .toList(growable: false);
  }

  Future<void> acknowledge(NotificationEnvelope envelope) async {
    if (envelope.captureId != null) {
      await _channel.invokeMethod<void>('acknowledgeEnvelope', {
        'captureId': envelope.captureId,
      });
    }
  }

  Future<List<NotificationEnvelope>> readActiveWalletNotifications() async {
    if (!developerToolsEnabled) {
      throw StateError('Herramientas de desarrollo desactivadas.');
    }
    final values =
        await _channel.invokeListMethod<Object?>(
          'readActiveWalletNotifications',
        ) ??
        const [];
    return values
        .whereType<Map<Object?, Object?>>()
        .map(NotificationEnvelope.fromMap)
        .where(
          (event) => const {
            'com.google.android.gms',
            'com.google.android.apps.walletnfcrel',
          }.contains(event.packageName),
        )
        .toList(growable: false);
  }

  Future<void> sendTestNotification({
    required String merchant,
    required String alias,
    required int amount,
  }) async {
    if (!developerToolsEnabled) {
      throw StateError('Herramientas de desarrollo desactivadas.');
    }
    await _channel.invokeMethod<void>('sendTestNotification', {
      'merchant': merchant,
      'alias': alias,
      'amount': amount,
    });
  }

  Future<void> clearCapturedEvents() =>
      _channel.invokeMethod<void>('clearCapturedEvents');

  Future<String?> getInitialAction() =>
      _channel.invokeMethod<String>('getInitialAction');
}

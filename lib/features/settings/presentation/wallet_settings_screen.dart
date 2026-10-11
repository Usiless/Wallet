import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/config/feature_flags.dart';
import '../../../shared/widgets/app_snack.dart';

final class WalletSettingsScreen extends ConsumerStatefulWidget {
  const WalletSettingsScreen({super.key});
  @override
  ConsumerState<WalletSettingsScreen> createState() =>
      _WalletSettingsScreenState();
}

class _WalletSettingsScreenState extends ConsumerState<WalletSettingsScreen> {
  bool? _enabled;
  bool _auto = false;
  bool _busy = false;
  bool _loadFailed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loadFailed = false);
    try {
      final settings = ref.read(settingsProvider);
      final enabled = await settings.readBool('notification_listener_enabled');
      final auto = await settings.readBool('wallet_auto_register');
      if (mounted) {
        setState(() {
          _enabled = enabled;
          _auto = auto;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadFailed = true);
    }
  }

  Future<void> _openAccessSettings() async {
    try {
      await ref.read(nativeNotificationBridgeProvider).openAccessSettings();
    } catch (_) {
      if (mounted) {
        showMessage(context, 'No se pudieron abrir los ajustes de Android.');
      }
    }
  }

  Future<void> _save(bool enabled, bool auto) async {
    setState(() => _busy = true);
    try {
      final bridge = ref.read(nativeNotificationBridgeProvider);
      if (enabled && !await bridge.isAccessGranted()) {
        if (mounted) {
          showMessage(
            context,
            'Concedé acceso en Android y volvé a activar la detección.',
          );
        }
        await bridge.openAccessSettings();
        return;
      }
      final settings = ref.read(settingsProvider);
      await settings.write('notification_listener_enabled', '$enabled');
      await settings.write('wallet_auto_register', '$auto');
      final sms =
          developerToolsEnabled &&
          await settings.readBool('sms_notifications_enabled');
      await bridge.configure(
        enabled: enabled || sms,
        diagnosticMode:
            developerToolsEnabled && await settings.readBool('diagnostic_mode'),
        allowedPackages: {
          if (enabled) ...{
            'com.google.android.gms',
            'com.google.android.apps.walletnfcrel',
          },
          if (sms) 'com.google.android.apps.messaging',
        },
      );
      if (mounted) {
        setState(() {
          _enabled = enabled;
          _auto = auto;
        });
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Google Wallet')),
    body: ListView(
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_loadFailed)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('No se pudo cargar la configuración de Wallet.'),
                TextButton(onPressed: _load, child: const Text('Reintentar')),
              ],
            ),
          ),
        SwitchListTile(
          title: const Text('Detectar compras de Google Wallet'),
          value: _enabled ?? false,
          // Al apagar la detección el registro automático también se apaga.
          onChanged: _enabled == null || _busy
              ? null
              : (v) => _save(v, v && _auto),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _openAccessSettings,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Acceso a notificaciones en Android'),
            ),
          ),
        ),
        SwitchListTile(
          title: const Text('Registrar automáticamente compras reconocidas'),
          value: (_enabled ?? false) && _auto,
          onChanged: (_enabled ?? false) && !_busy
              ? (v) => _save(_enabled!, v)
              : null,
        ),
      ],
    ),
  );
}

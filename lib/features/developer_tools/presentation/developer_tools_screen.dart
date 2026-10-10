import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/config/feature_flags.dart';

final class DeveloperToolsScreen extends ConsumerStatefulWidget {
  const DeveloperToolsScreen({super.key});

  @override
  ConsumerState<DeveloperToolsScreen> createState() =>
      _DeveloperToolsScreenState();
}

class _DeveloperToolsScreenState extends ConsumerState<DeveloperToolsScreen> {
  bool? _diagnostic;
  bool? _sms;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    if (developerToolsEnabled) _load();
  }

  Future<void> _load() async {
    final settings = ref.read(settingsProvider);
    final diagnostic = await settings.readBool('diagnostic_mode');
    final sms = await settings.readBool('sms_notifications_enabled');
    if (mounted) {
      setState(() {
        _diagnostic = diagnostic;
        _sms = sms;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!developerToolsEnabled) {
      return const Scaffold(
        body: Center(child: Text('Herramientas de desarrollo desactivadas.')),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Herramientas de desarrollo')),
      body: ListView(
        children: [
          if (_busy) const LinearProgressIndicator(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Herramientas para probar la captura de compras. Las pruebas pueden afectar los datos de esta instalación.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.science_outlined),
            title: const Text('Notificaciones de prueba'),
            subtitle: const Text(
              'Comercios editables, identificador de tarjeta y montos aleatorios.',
            ),
            onTap: () => context.push('/developer-tools/simulator'),
          ),
          SwitchListTile(
            value: _sms ?? false,
            onChanged: _sms == null || _busy ? null : _setSms,
            title: const Text('Probar alertas Sudameris en Google Messages'),
            subtitle: const Text(
              'Observa notificaciones; no lee la bandeja de SMS ni confirma movimientos automáticamente.',
            ),
          ),
          const Divider(),
          SwitchListTile(
            value: _diagnostic ?? false,
            onChanged: _diagnostic == null || _busy ? null : _setDiagnostic,
            title: const Text('Modo diagnóstico'),
            subtitle: const Text(
              'Retiene contenido de notificaciones para investigar problemas de captura.',
            ),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: const Text('Ver diagnóstico'),
            subtitle: const Text(
              'Consultar, exportar o borrar eventos retenidos.',
            ),
            onTap: () => context.push('/developer-tools/notifications'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Lectura de notificaciones existentes'),
            subtitle: const Text(
              'Seleccioná una notificación activa de Wallet y revisá los datos antes de crear una propuesta.',
            ),
            onTap: () => context.push('/developer-tools/active-notifications'),
          ),
        ],
      ),
    );
  }

  Future<void> _setDiagnostic(bool value) => _saveSetting(
    key: 'diagnostic_mode',
    value: value,
    smsEnabled: _sms ?? false,
    diagnostic: value,
  );

  Future<void> _setSms(bool value) => _saveSetting(
    key: 'sms_notifications_enabled',
    value: value,
    smsEnabled: value,
    diagnostic: _diagnostic ?? false,
  );

  Future<void> _saveSetting({
    required String key,
    required bool value,
    required bool smsEnabled,
    required bool diagnostic,
  }) async {
    setState(() => _busy = true);
    try {
      await ref.read(settingsProvider).write(key, value.toString());
      await _configureNative(smsEnabled: smsEnabled, diagnostic: diagnostic);
    } catch (error) {
      _message('$error');
    } finally {
      await _load();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _configureNative({
    required bool smsEnabled,
    required bool diagnostic,
  }) async {
    final walletEnabled = await ref
        .read(settingsProvider)
        .readBool('notification_listener_enabled');
    await ref
        .read(nativeNotificationBridgeProvider)
        .configure(
          enabled: walletEnabled || smsEnabled,
          diagnosticMode: diagnostic,
          allowedPackages: {
            if (walletEnabled) ...{
              'com.google.android.gms',
              'com.google.android.apps.walletnfcrel',
            },
            if (smsEnabled) 'com.google.android.apps.messaging',
          },
        );
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
    }
  }
}

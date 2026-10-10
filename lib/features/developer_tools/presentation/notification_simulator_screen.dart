import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/config/feature_flags.dart';
import '../../../shared/widgets/app_snack.dart';

final class NotificationSimulatorScreen extends ConsumerStatefulWidget {
  const NotificationSimulatorScreen({super.key});
  @override
  ConsumerState<NotificationSimulatorScreen> createState() =>
      _NotificationSimulatorScreenState();
}

class _NotificationSimulatorScreenState
    extends ConsumerState<NotificationSimulatorScreen> {
  final _names = TextEditingController();
  final _alias = TextEditingController();
  final _min = TextEditingController(text: '5000');
  final _max = TextEditingController(text: '150000');
  String? _selected;
  bool _busy = false;
  static const _samples =
      'ECOP OBLIGADO\nPETROSUR-OBLIGADO\nShell\nMAKOS HELADERIA\nHotel Encanto Rural\nSupermarket United Colonies\nCANTINA EDUC\nEL LIBRO EN SU CASA\nLIB.INTERCONTINENTAL\nDELIBRI\nCASA DE CARNES BREMM\nPANIFICADORA REAL10 II\nCopetrol Bella Vista DM SRL\nPUMA GLAMIS SHOP\nEL LECTOR\nSHALOM\nDETALLES\nPunto Farma 640\nSupermercado El Quincho';
  @override
  void initState() {
    super.initState();
    if (developerToolsEnabled) _load();
  }

  Future<void> _load() async {
    final saved = await ref
        .read(settingsProvider)
        .read('developer_test_merchants');
    if (mounted) setState(() => _names.text = saved ?? _samples);
  }

  @override
  void dispose() {
    _names.dispose();
    _alias.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  List<String> get _merchants => _names.text
      .split('\n')
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty)
      .toSet()
      .toList();
  Future<void> _send() async {
    if (!developerToolsEnabled || _busy) return;
    setState(() => _busy = true);
    try {
      final min = int.tryParse(_min.text);
      final max = int.tryParse(_max.text);
      if (min == null ||
          max == null ||
          min <= 0 ||
          max < min ||
          max > 100000000 ||
          !RegExp(r'^\d{4,6}$').hasMatch(_alias.text.trim()) ||
          _merchants.isEmpty) {
        throw StateError(
          'Ingresá comercios, un identificador de 4 a 6 dígitos y un rango válido de importes PYG.',
        );
      }
      final merchant = _selected != null && _merchants.contains(_selected)
          ? _selected!
          : _merchants[Random().nextInt(_merchants.length)];
      final bridge = ref.read(nativeNotificationBridgeProvider);
      if (!await bridge.isAccessGranted()) {
        throw StateError(
          'Concedé acceso a notificaciones en Google Wallet → Abrir ajustes.',
        );
      }
      if (!await bridge.requestOwnNotificationPermission()) {
        throw StateError(
          'Se necesita permiso para mostrar esta notificación de prueba.',
        );
      }
      await ref
          .read(settingsProvider)
          .write('developer_test_merchants', _names.text);
      final amount = min + Random().nextInt(max - min + 1);
      await bridge.sendTestNotification(
        merchant: merchant,
        alias: _alias.text.trim(),
        amount: amount,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Prueba enviada: $merchant, $amount PYG. Volvé a la app o actualizá Movimientos pendientes.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
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
      appBar: AppBar(title: const Text('Notificaciones de prueba')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Emite una notificación de esta app, marcada PRUEBA. Usa el mismo lector y reconocimiento que Wallet. '
            'Los movimientos simulados afectan los saldos de esta instalación y aparecen con [PRUEBA]. '
            'Si el registro automático está activado, también se prueba ese recorrido. Podés eliminarlos después.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _names,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Comercios de prueba, uno por línea',
            ),
            onChanged: (_) => setState(() => _selected = null),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            key: ValueKey(_names.text),
            initialValue: _selected,
            decoration: const InputDecoration(labelText: 'Comercio'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Aleatorio')),
              for (final name in _merchants)
                DropdownMenuItem(value: name, child: Text(name)),
            ],
            onChanged: (value) => setState(() => _selected = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _alias,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Identificador de tarjeta (4 a 6 dígitos)',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _min,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Importe mínimo PYG'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _max,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Importe máximo PYG'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _send,
            child: const Text('Enviar notificación de prueba'),
          ),
        ],
      ),
    );
  }
}

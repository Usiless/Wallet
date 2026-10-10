import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/notifications/notification_envelope.dart';
import '../../pending_inbox/domain/payment_candidate.dart';
import '../data/notification_retest_service.dart';

final class ActiveNotificationsScreen extends ConsumerStatefulWidget {
  const ActiveNotificationsScreen({super.key});

  @override
  ConsumerState<ActiveNotificationsScreen> createState() =>
      _ActiveNotificationsScreenState();
}

class _ActiveNotificationsScreenState
    extends ConsumerState<ActiveNotificationsScreen> {
  List<NotificationEnvelope>? _events;
  NotificationEnvelope? _selected;
  PaymentCandidate? _preview;
  String? _accountName;
  String? _error;
  bool _busy = false;

  Future<void> _read() async {
    if (!developerToolsEnabled || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _selected = null;
      _preview = null;
      _events = null;
    });
    try {
      final events = await ref
          .read(nativeNotificationBridgeProvider)
          .readActiveWalletNotifications();
      if (mounted) setState(() => _events = events);
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _select(NotificationEnvelope event) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _selected = event;
      _preview = null;
      _accountName = null;
      _error = null;
    });
    try {
      final preview = await ref
          .read(notificationIngestionProvider)
          .preview(event);
      final accounts = await ref.read(accountsServiceProvider).getAccounts();
      final name = accounts
          .where((a) => a.id == preview?.suggestedAccountId)
          .firstOrNull
          ?.name;
      if (mounted) {
        setState(() {
          _preview = preview;
          _accountName = name;
        });
      }
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _propose() async {
    if (!developerToolsEnabled ||
        _busy ||
        _selected == null ||
        _preview == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(notificationIngestionProvider)
          .ingest(_selected!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == null
                ? 'Esta notificación ya fue procesada. No se creó otro gasto.'
                : 'Propuesta guardada. Revisá la cuenta antes de confirmar.',
          ),
        ),
      );
      context.push('/inbox');
    } catch (error) {
      _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error) {
    if (mounted) {
      setState(
        () => _error = error is PlatformException
            ? error.message ?? 'No se pudieron consultar las notificaciones.'
            : '$error',
      );
    }
  }

  Future<void> _repeat() async {
    if (_busy || _selected == null || !developerToolsEnabled) return;
    setState(() => _busy = true);
    try {
      await NotificationRetestService(
        ref.read(databaseProvider),
        ref.read(notificationIngestionProvider),
      ).reopen(_selected!);
      if (mounted) context.push('/inbox');
    } catch (error) {
      _showError(error);
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
    final selected = _selected;
    final preview = _preview;
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones existentes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Consulta las notificaciones activas de Wallet y Google Play Services. '
            'No borra notificaciones ni registra gastos. El contenido se muestra en esta pantalla; '
            'al crear una propuesta se aplican los ajustes de diagnóstico.',
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _busy
                ? null
                : () async {
                    try {
                      await ref
                          .read(nativeNotificationBridgeProvider)
                          .openAccessSettings();
                    } catch (error) {
                      _showError(error);
                    }
                  },
            child: const Text('Abrir acceso a notificaciones'),
          ),
          FilledButton.icon(
            onPressed: _busy ? null : _read,
            icon: const Icon(Icons.refresh),
            label: const Text('Consultar notificaciones'),
          ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_error!),
            ),
          if (_events?.isEmpty == true)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No hay notificaciones activas de estas fuentes. '
                'Android no recupera notificaciones ya descartadas.',
              ),
            ),
          for (final event in _events ?? <NotificationEnvelope>[])
            Card(
              child: ListTile(
                selected: identical(event, selected),
                title: Text(event.title ?? 'Notificación sin título'),
                subtitle: Text(
                  '${event.packageName}\n${event.postTime.toLocal()}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _busy ? null : () => _select(event),
              ),
            ),
          if (selected != null) ...[
            const Divider(),
            Text(
              'Contenido recibido',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Text(
              'Puede contener datos personales. Revisalo aquí antes de compartirlo.',
            ),
            for (final entry in <String, String?>{
              'Título': selected.title,
              'Texto': selected.text,
              'Texto ampliado': selected.bigText,
              'Subtexto': selected.subText,
              'Resumen': selected.summaryText,
              'Líneas': selected.textLines.isEmpty
                  ? null
                  : selected.textLines.join('\n'),
            }.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: SelectableText(
                  '${entry.key}: ${entry.value ?? '(ausente)'}',
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Interpretación',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (!_busy && preview == null)
              const Text(
                'No se reconoció una compra compatible. El lector actual busca importes en PYG. '
                'Podés revisar el contenido recibido para ajustar el reconocimiento.',
              ),
            if (preview != null) ...[
              Text('Importe: ${preview.amountMinor} ${preview.currencyCode}'),
              Text(
                'Comercio sugerido: ${preview.rawMerchant ?? '(no detectado)'}',
              ),
              Text(
                'Identificador detectado: ${preview.detectedAlias ?? '(no detectado)'}',
              ),
              Text(
                'Cuenta sugerida: ${_accountName ?? 'Sin coincidencia única; deberás seleccionarla.'}',
              ),
              const Text(
                'Al confirmar el gasto, el identificador se guarda como alias de la cuenta elegida, si todavía no existe en ella.',
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _busy ? null : _propose,
                child: const Text('Crear propuesta para revisar'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : _repeat,
                child: const Text('Repetir prueba tras eliminar el movimiento'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

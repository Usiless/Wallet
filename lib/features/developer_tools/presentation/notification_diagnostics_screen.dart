import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/database/app_database.dart';
import '../../../core/text/normalization.dart';

final class NotificationDiagnosticsScreen extends ConsumerWidget {
  const NotificationDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!developerToolsEnabled) {
      return const Scaffold(
        body: Center(child: Text('Herramientas de desarrollo desactivadas.')),
      );
    }
    final database = ref.watch(databaseProvider);
    final stream = (database.select(
      database.notificationEvents,
    )..orderBy([(table) => OrderingTerm.desc(table.postedAt)])).watch();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnóstico local'),
        actions: [
          IconButton(
            tooltip: 'Exportar sanitizado',
            onPressed: () => _export(context, database),
            icon: const Icon(Icons.ios_share),
          ),
          IconButton(
            tooltip: 'Borrar eventos crudos',
            onPressed: () => _clear(context, ref, database),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: StreamBuilder<List<NotificationEventRecord>>(
        stream: stream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay eventos retenidos.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Los números largos se ocultan al mostrar, copiar o exportar. Los eventos vencidos se limpian al procesar o abrir la app.',
                  ),
                ),
              ),
              for (final event in snapshot.data!)
                ExpansionTile(
                  title: Text(event.packageName),
                  subtitle: Text(event.postedAt.toLocal().toString()),
                  childrenPadding: const EdgeInsets.all(16),
                  children: [
                    SelectableText(
                      sanitizeDiagnosticText(
                        [
                          event.title,
                          event.notificationText,
                          event.bigText,
                          event.subText,
                          event.summaryText,
                        ].whereType<String>().join('\n'),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _export(BuildContext context, AppDatabase database) async {
    final events = await database.select(database.notificationEvents).get();
    final json = const JsonEncoder.withIndent('  ').convert([
      for (final event in events)
        {
          'version': event.envelopeVersion,
          'packageName': event.packageName,
          'postTime': event.postedAt.toIso8601String(),
          'title': event.title == null
              ? null
              : sanitizeDiagnosticText(event.title!),
          'text': event.notificationText == null
              ? null
              : sanitizeDiagnosticText(event.notificationText!),
          'bigText': event.bigText == null
              ? null
              : sanitizeDiagnosticText(event.bigText!),
          'isUpdate': event.isUpdate,
        },
    ]);
    await FilePicker.saveFile(
      dialogTitle: 'Exportar diagnóstico sanitizado',
      fileName: 'diagnostico-notificaciones.json',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: Uint8List.fromList(utf8.encode(json)),
    );
  }

  Future<void> _clear(
    BuildContext context,
    WidgetRef ref,
    AppDatabase database,
  ) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Borrar eventos crudos'),
        content: const Text('Los movimientos confirmados no se borrarán.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
    if (accepted != true) return;
    await database.delete(database.notificationEvents).go();
    await ref.read(nativeNotificationBridgeProvider).clearCapturedEvents();
  }
}

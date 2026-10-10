import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../shared/widgets/async_value_view.dart';
import 'manual_template_service.dart';
import 'template_summary.dart';
import '../../shared/widgets/app_fab.dart';
import '../../shared/widgets/app_snack.dart';

final class TemplatesScreen extends ConsumerStatefulWidget {
  const TemplatesScreen({this.scheduledOnly = false, super.key});
  final bool scheduledOnly;
  @override
  ConsumerState<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends ConsumerState<TemplatesScreen> {
  late bool scheduledOnly = widget.scheduledOnly;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Plantillas'),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Todas')),
              ButtonSegment(value: true, label: Text('Programadas')),
            ],
            selected: {scheduledOnly},
            onSelectionChanged: (v) => setState(() => scheduledOnly = v.first),
          ),
        ),
      ),
    ),
    body: AsyncValueView(
      value: ref.watch(manualTemplatesProvider),
      onRetry: () => ref.invalidate(manualTemplatesProvider),
      data: (allTemplates) {
        final templates = scheduledOnly
            ? allTemplates.where((template) {
                final schedule = template.fields['schedule'] as Map?;
                return schedule?['enabled'] == true ||
                    schedule?['paused'] == true ||
                    schedule?['pendingReason'] != null;
              }).toList()
            : allTemplates;
        return templates.isEmpty
            ? Center(
                child: Text(
                  scheduledOnly
                      ? 'Sin plantillas programadas'
                      : 'Sin plantillas',
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                children: [
                  for (final template in templates)
                    Card(
                      child: ListTile(
                        title: Text(template.name),
                        subtitle: Text(
                          templateScheduleLabel(context, template),
                        ),
                        onTap: () => context.push(
                          Uri(
                            path: '/transactions/new',
                            queryParameters: {'savedTemplate': template.id},
                          ).toString(),
                        ),
                        trailing: PopupMenuButton<String>(
                          tooltip: 'Opciones de plantilla',
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('Editar'),
                            ),
                            if ((template.fields['schedule']
                                    as Map?)?['enabled'] ==
                                true)
                              const PopupMenuItem(
                                value: 'pause',
                                child: Text('Pausar programación'),
                              ),
                            if ((template.fields['schedule']
                                    as Map?)?['pendingReason'] !=
                                null)
                              const PopupMenuItem(
                                value: 'skip',
                                child: Text('Omitir este vencimiento'),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Eliminar'),
                            ),
                          ],
                          onSelected: (action) async {
                            if (action == 'edit') {
                              context.push(
                                Uri(
                                  path: '/transactions/new',
                                  queryParameters: {
                                    'savedTemplate': template.id,
                                    'editTemplate': 'true',
                                  },
                                ).toString(),
                              );
                            } else if (action == 'delete') {
                              await _deleteTemplate(context, ref, template);
                            } else {
                              await _scheduleAction(
                                context,
                                ref,
                                template.id,
                                skip: action == 'skip',
                              );
                            }
                          },
                        ),
                      ),
                    ),
                ],
              );
      },
    ),
    floatingActionButton: AppFab.extended(
      icon: const Icon(Icons.add),
      label: const Text('Crear plantilla'),
      onPressed: () => context.push('/transactions/new?editTemplate=true'),
    ),
  );
  Future<void> _deleteTemplate(
    BuildContext context,
    WidgetRef ref,
    ManualTemplate template,
  ) async {
    final service = ref.read(manualTemplateServiceProvider);
    try {
      await service.delete(template.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Plantilla eliminada.'),
            action: SnackBarAction(
              label: 'Deshacer',
              onPressed: () async {
                try {
                  await service.save(
                    template.name,
                    template.fields,
                    id: template.id,
                  );
                } catch (error) {
                  if (context.mounted) showError(context, error);
                }
              },
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }

  Future<void> _scheduleAction(
    BuildContext context,
    WidgetRef ref,
    String id, {
    required bool skip,
  }) async {
    try {
      final service = ref.read(scheduledTemplateServiceProvider);
      if (skip) {
        await service.skipPending(id);
        if (context.mounted) showMessage(context, 'Vencimiento omitido.');
      } else {
        await service.pause(id);
        if (context.mounted) showMessage(context, 'Programación pausada.');
      }
    } catch (error) {
      if (context.mounted) showError(context, error);
    }
  }
}

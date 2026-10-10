import 'package:flutter/material.dart';

import 'manual_template_service.dart';
import 'template_summary.dart';

/// Lo que el usuario eligió en la hoja «Usar plantilla».
sealed class TemplatePick {
  const TemplatePick();
}

final class UseTemplate extends TemplatePick {
  const UseTemplate(this.id);
  final String id;
}

final class ToggleSaveAsTemplate extends TemplatePick {
  const ToggleSaveAsTemplate();
}

final class ManageTemplates extends TemplatePick {
  const ManageTemplates();
}

/// [templates] ya viene ordenada. [offerSave] muestra «Guardar como plantilla»
/// y [saving] indica si ya está activado.
Future<TemplatePick?> showTemplatePicker(
  BuildContext context, {
  required List<ManualTemplate> templates,
  required bool offerSave,
  required bool saving,
}) => showModalBottomSheet<TemplatePick>(
  context: context,
  isScrollControlled: true,
  builder: (sheet) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(sheet).height * .6,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Usar plantilla',
              style: Theme.of(sheet).textTheme.titleLarge,
            ),
          ),
          Expanded(
            child: templates.isEmpty
                ? const Center(child: Text('Todavía no guardaste plantillas.'))
                : ListView(
                    children: [
                      for (final template in templates)
                        ListTile(
                          title: Text(template.name),
                          subtitle: Text(
                            '${templateMovementLabel(template)} · ${templateScheduleLabel(sheet, template)}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              Navigator.pop(sheet, UseTemplate(template.id)),
                        ),
                    ],
                  ),
          ),
          if (offerSave)
            TextButton.icon(
              onPressed: () =>
                  Navigator.pop(sheet, const ToggleSaveAsTemplate()),
              icon: Icon(saving ? Icons.bookmark_remove : Icons.bookmark_add),
              label: Text(
                saving ? 'No guardar como plantilla' : 'Guardar como plantilla',
              ),
            ),
          TextButton.icon(
            onPressed: () => Navigator.pop(sheet, const ManageTemplates()),
            icon: const Icon(Icons.tune),
            label: const Text('Administrar plantillas y registros programados'),
          ),
        ],
      ),
    ),
  ),
);

import 'package:flutter/material.dart';

import 'manual_template_service.dart';

String templateMovementLabel(ManualTemplate template) =>
    switch (template.fields['type']) {
      'income' => 'Ingreso',
      'transfer' => 'Transferencia',
      _ => 'Gasto',
    };

String templateScheduleLabel(BuildContext context, ManualTemplate template) {
  final schedule = template.fields['schedule'] as Map?;
  if (schedule == null) return 'Abrir y revisar';
  if (schedule['enabled'] != true) {
    return schedule['paused'] == true
        ? 'Automatización pausada'
        : 'Abrir y revisar';
  }
  if (schedule['pendingReason'] != null) {
    return 'Pendiente: ${schedule['pendingReason']}';
  }
  final rawDate = schedule['nextDate'];
  final date = rawDate is String ? DateTime.tryParse(rawDate) : null;
  final formatted = date == null
      ? 'fecha por definir'
      : MaterialLocalizations.of(context).formatShortDate(date);
  return "${schedule['frequency'] == 'yearly' ? 'Anual' : 'Mensual'} · Próximo registro: $formatted";
}

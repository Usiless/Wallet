import 'package:flutter/material.dart';

import '../payments/domain/pending_payment_models.dart';
import '../payments/presentation/payment_reminder_fields.dart';
import 'scheduled_template_service.dart';

/// Lo que el usuario eligió en el diálogo «Guardar plantilla».
final class SaveTemplateChoice {
  const SaveTemplateChoice({
    required this.name,
    required this.includeAmount,
    required this.automatic,
    required this.frequency,
    required this.nextDate,
    required this.choseDate,
    required this.reminders,
  });

  final String name;
  final bool includeAmount, automatic;
  final String frequency;
  final DateTime nextDate;

  /// Verdadero si el usuario eligió la fecha a mano en el selector.
  final bool choseDate;
  final PaymentReminderSettings reminders;
}

/// Devuelve `null` si se cancela. [nextDateForFrequency] propone una nueva
/// próxima fecha al cambiar la frecuencia mientras el usuario no la haya elegido.
Future<SaveTemplateChoice?> showSaveTemplateDialog(
  BuildContext context, {
  required String name,
  required bool includeAmount,
  required bool automatic,
  required String frequency,
  required DateTime nextDate,
  required PaymentReminderSettings reminders,
  DateTime Function(String frequency)? nextDateForFrequency,
}) => showDialog<SaveTemplateChoice>(
  context: context,
  builder: (_) => _SaveTemplateDialog(
    name: name,
    includeAmount: includeAmount,
    automatic: automatic,
    frequency: frequency,
    nextDate: nextDate,
    reminders: reminders,
    nextDateForFrequency: nextDateForFrequency,
  ),
);

final class _SaveTemplateDialog extends StatefulWidget {
  const _SaveTemplateDialog({
    required this.name,
    required this.includeAmount,
    required this.automatic,
    required this.frequency,
    required this.nextDate,
    required this.reminders,
    required this.nextDateForFrequency,
  });

  final String name, frequency;
  final bool includeAmount, automatic;
  final DateTime nextDate;
  final PaymentReminderSettings reminders;
  final DateTime Function(String frequency)? nextDateForFrequency;

  @override
  State<_SaveTemplateDialog> createState() => _SaveTemplateDialogState();
}

class _SaveTemplateDialogState extends State<_SaveTemplateDialog> {
  late String _name = widget.name;
  late bool _includeAmount = widget.includeAmount;
  late bool _automatic = widget.automatic;
  late String _frequency = widget.frequency;
  late DateTime _nextDate = widget.nextDate;
  late PaymentReminderSettings _reminders = widget.reminders;
  bool _choseDate = false;

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Guardar plantilla'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            initialValue: _name,
            decoration: const InputDecoration(
              labelText: 'Nombre de la plantilla',
            ),
            onChanged: (value) => setState(() => _name = value),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Recordar importe'),
            value: _includeAmount,
            onChanged: _automatic
                ? null
                : (value) => setState(() => _includeAmount = value ?? false),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Preparar pagos pendientes'),
            value: _automatic,
            onChanged: (value) => setState(() {
              _automatic = value ?? false;
              if (_automatic) _includeAmount = true;
            }),
          ),
          if (_automatic) ...[
            DropdownButtonFormField<String>(
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: 'Frecuencia'),
              items: const [
                DropdownMenuItem(value: 'monthly', child: Text('Mensual')),
                DropdownMenuItem(value: 'yearly', child: Text('Anual')),
              ],
              onChanged: (value) => setState(() {
                _frequency = value!;
                final propose = widget.nextDateForFrequency;
                if (propose != null && !_choseDate) {
                  _nextDate = propose(_frequency);
                }
              }),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Próxima fecha'),
              subtitle: Text(scheduledDate(_nextDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final chosen = await showDatePicker(
                  context: context,
                  initialDate: _nextDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (chosen != null && mounted) {
                  setState(() {
                    _nextDate = chosen;
                    _choseDate = true;
                  });
                }
              },
            ),
            PaymentReminderFields(
              value: _reminders,
              onChanged: (value) => setState(() => _reminders = value),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: _name.trim().isEmpty
            ? null
            : () => Navigator.pop(
                context,
                SaveTemplateChoice(
                  name: _name,
                  includeAmount: _includeAmount,
                  automatic: _automatic,
                  frequency: _frequency,
                  nextDate: _nextDate,
                  choseDate: _choseDate,
                  reminders: _reminders,
                ),
              ),
        child: const Text('Guardar'),
      ),
    ],
  );
}

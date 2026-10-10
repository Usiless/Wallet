import 'package:flutter/material.dart';

import '../domain/pending_payment_models.dart';

class PaymentReminderFields extends StatelessWidget {
  const PaymentReminderFields({
    required this.value,
    required this.onChanged,
    super.key,
  });
  final PaymentReminderSettings value;
  final ValueChanged<PaymentReminderSettings> onChanged;
  void change({bool? enabled, int? days, int? hour, int? minute, bool? due}) =>
      onChanged(
        PaymentReminderSettings(
          enabled: enabled ?? value.enabled,
          daysBefore: days ?? value.daysBefore,
          hour: hour ?? value.hour,
          minute: minute ?? value.minute,
          onDueDate: due ?? value.onDueDate,
        ),
      );
  @override
  Widget build(BuildContext context) => Column(
    children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Recordatorios'),
        value: value.enabled,
        onChanged: (v) => change(enabled: v),
      ),
      if (value.enabled) ...[
        DropdownButtonFormField<int>(
          initialValue: value.daysBefore,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Días antes'),
          items: [
            for (var i = 0; i <= 60; i++)
              DropdownMenuItem(value: i, child: Text('$i')),
          ],
          onChanged: (v) => change(days: v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('El día del vencimiento'),
          value: value.onDueDate,
          onChanged: (v) => change(due: v),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Hora'),
          trailing: Text(
            '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
          ),
          onTap: () async {
            final t = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: value.hour, minute: value.minute),
            );
            if (t != null) change(hour: t.hour, minute: t.minute);
          },
        ),
      ],
    ],
  );
}

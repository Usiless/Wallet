import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/notifications/expense_check_reminders.dart';
import '../../../core/notifications/expense_check_store.dart';
import '../../../shared/widgets/app_snack.dart';

final class ExpenseCheckTiles extends ConsumerWidget {
  const ExpenseCheckTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(expenseCheckSettingsProvider).value;

    Future<void> save(ExpenseCheckSettings next) async {
      try {
        await writeExpenseCheckSettings(ref.read(settingsProvider), next);
      } catch (error) {
        if (context.mounted) showError(context, error);
        return;
      }
      if (!next.enabled || value?.enabled == true) return;
      try {
        if (!await ref
                .read(paymentReminderBridgeProvider)
                .requestPermission() &&
            context.mounted) {
          showMessage(context, 'Guardado. Recordatorios sin permiso.');
        }
      } catch (_) {
        if (context.mounted) {
          showMessage(context, 'Guardado. Recordatorios no disponibles.');
        }
      }
    }

    final repeats = value != null && value.everyHours > 0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          secondary: const Icon(Icons.edit_notifications_outlined),
          title: const Text('Recordatorio de gastos'),
          value: value?.enabled ?? false,
          onChanged: value == null
              ? null
              : (v) => save(value.copyWith(enabled: v)),
        ),
        if (value != null && value.enabled) ...[
          ListTile(
            leading: const Icon(Icons.repeat),
            title: const Text('Frecuencia'),
            trailing: Text(_frequencyLabel(value.everyHours)),
            onTap: () async {
              final every = await showDialog<int>(
                context: context,
                builder: (_) => _FrequencyDialog(selected: value.everyHours),
              );
              if (every != null) await save(value.copyWith(everyHours: every));
            },
          ),
          _TimeTile(
            icon: Icons.schedule,
            label: repeats ? 'Desde' : 'Hora',
            hour: value.hour,
            minute: value.minute,
            onChanged: (t) =>
                save(value.copyWith(hour: t.hour, minute: t.minute)),
          ),
          if (repeats)
            _TimeTile(
              icon: Icons.schedule_outlined,
              label: 'Hasta',
              hour: value.untilHour,
              minute: value.untilMinute,
              onChanged: (t) => save(
                value.copyWith(untilHour: t.hour, untilMinute: t.minute),
              ),
            ),
        ],
      ],
    );
  }
}

String _frequencyLabel(int everyHours) =>
    everyHours == 0 ? 'Una vez al día' : 'Cada $everyHours h';

final class _FrequencyDialog extends StatelessWidget {
  const _FrequencyDialog({required this.selected});
  final int selected;

  @override
  Widget build(BuildContext context) => SimpleDialog(
    title: const Text('Frecuencia'),
    children: [
      RadioGroup<int>(
        groupValue: selected,
        onChanged: (v) => Navigator.pop(context, v),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final every in [0, ...expenseCheckIntervals])
              RadioListTile<int>(
                value: every,
                title: Text(_frequencyLabel(every)),
              ),
          ],
        ),
      ),
    ],
  );
}

final class _TimeTile extends StatelessWidget {
  const _TimeTile({
    required this.icon,
    required this.label,
    required this.hour,
    required this.minute,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final int hour, minute;
  final Future<void> Function(TimeOfDay) onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(label),
    trailing: Text(
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
    ),
    onTap: () async {
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: hour, minute: minute),
      );
      if (t != null) await onChanged(t);
    },
  );
}

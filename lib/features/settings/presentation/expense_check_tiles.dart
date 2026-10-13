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
        if (value != null && value.enabled)
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Hora'),
            trailing: Text(
              '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
            ),
            onTap: () async {
              final t = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(hour: value.hour, minute: value.minute),
              );
              if (t != null) {
                await save(value.copyWith(hour: t.hour, minute: t.minute));
              }
            },
          ),
      ],
    );
  }
}

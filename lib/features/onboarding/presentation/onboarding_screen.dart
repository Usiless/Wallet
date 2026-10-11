import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/errors/user_message.dart';
import '../../../core/security/app_lock_service.dart';
import '../../accounts/data/accounts_service.dart';
import '../../accounts/presentation/create_account_dialog.dart';
import '../domain/onboarding_config.dart';
import '../../../shared/widgets/inline_progress.dart';

final class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  var _step = 0;
  var _saving = false;
  final _accounts = <CreateAccountDraft>[];
  var _lock = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurar Cabal')),
      body: SafeArea(
        child: Column(
          children: [
            LinearProgressIndicator(value: (_step + 1) / 3),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: SingleChildScrollView(
                  key: ValueKey(_step),
                  padding: const EdgeInsets.all(24),
                  child: switch (_step) {
                    0 => _privacyStep(context),
                    1 => _accountsStep(context),
                    _ => _securityStep(context),
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  if (_step > 0)
                    TextButton(
                      onPressed: _saving ? null : () => setState(() => _step--),
                      child: const Text('Atrás'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _saving
                        ? null
                        : _step < 2
                        ? () => setState(() => _step++)
                        : _finish,
                    child: _saving
                        ? const InlineProgress()
                        : Text(_step < 2 ? 'Continuar' : 'Empezar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _privacyStep(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        Icons.shield_outlined,
        size: 56,
        color: Theme.of(context).colorScheme.primary,
      ),
      const SizedBox(height: 24),
      Text(
        'Tus finanzas quedan en tu teléfono',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 32),
      const DropdownMenu<String>(
        initialSelection: 'PYG',
        label: Text('Moneda predeterminada'),
        expandedInsets: EdgeInsets.zero,
        dropdownMenuEntries: [
          DropdownMenuEntry(value: 'PYG', label: 'PYG — Guaraní paraguayo'),
        ],
      ),
    ],
  );

  Widget _accountsStep(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Agregá tus cuentas',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const SizedBox(height: 24),
      if (_accounts.isEmpty)
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Todavía no agregaste cuentas.'),
          ),
        ),
      for (final account in _accounts)
        Card(
          child: ListTile(
            title: Text(account.name),
            trailing: IconButton(
              tooltip: 'Quitar cuenta',
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _accounts.remove(account)),
            ),
          ),
        ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: _addAccount,
        icon: const Icon(Icons.add),
        label: const Text('Agregar cuenta'),
      ),
    ],
  );

  Future<void> _addAccount() async {
    final draft = await showCreateAccountDialog(context);
    if (draft != null && mounted) {
      setState(() => _accounts.add(draft));
    }
  }

  Widget _securityStep(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Seguridad', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 16),
      SwitchListTile(
        value: _lock,
        onChanged: (value) => setState(() => _lock = value),
        title: const Text('Bloquear al abrir o volver a la app'),
      ),
    ],
  );

  Future<void> _finish() async {
    try {
      setState(() => _saving = true);
      if (_lock) {
        final enabled = await AppLockService(ref.read(settingsProvider))
            .setEnabled(true);
        if (!enabled) {
          throw StateError('No se activó el bloqueo del dispositivo.');
        }
      }
      await ref
          .read(onboardingServiceProvider)
          .complete(
            OnboardingConfig(
              accounts: List.unmodifiable(_accounts),
              enableAppLock: _lock,
            ),
          );
      if (mounted) context.go('/dashboard');
    } catch (error) {
      _message(userMessage(error));
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

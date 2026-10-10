import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/config/feature_flags.dart';
import '../../../core/backup/backup_codec.dart';
import '../../../core/security/app_lock_service.dart';
import '../../../shared/widgets/text_prompt_dialog.dart';

final class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({this.backups = false, super.key});
  final bool backups;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool? _lock;
  var _busy = false;
  String? _progress;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = ref.read(settingsProvider);
    final lock = await settings.readBool('app_lock_enabled');
    if (mounted) {
      setState(() {
        _lock = lock;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.backups
          ? AppBar(title: const Text('Backup cifrado'))
          : null,
      body: ListView(
        children: [
          if (_busy) ...[
            const LinearProgressIndicator(),
            if (_progress != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_progress!),
              ),
          ],
          if (!widget.backups) ...[
            const _SectionTitle('Organización'),
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Pagos pendientes'),
              onTap: () => context.push('/payments'),
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_outline),
              title: const Text('Plantillas'),
              onTap: () => context.push('/templates'),
            ),
            ListTile(
              leading: const Icon(Icons.event_repeat),
              title: const Text('Movimientos programados'),
              onTap: () => context.push('/templates?scheduled=true'),
            ),
            ListTile(
              leading: const Icon(Icons.contactless),
              title: const Text('Google Wallet'),
              onTap: () => context.push('/wallet-settings'),
            ),
            const _SectionTitle('Tus datos'),
            ListTile(
              leading: const Icon(Icons.store_outlined),
              title: const Text('Comercios, categorías y asociaciones'),
              onTap: () => context.push('/catalog'),
            ),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Backup cifrado'),
              onTap: () => context.push('/backups'),
            ),
          ],
          if (widget.backups) ...[
            const _SectionTitle('Backup cifrado'),
            ListTile(
              leading: const Icon(Icons.backup_outlined),
              title: const Text('Crear backup'),
              onTap: _busy ? null : _createBackup,
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: const Text('Restaurar backup'),
              onTap: _busy ? null : _restoreBackup,
            ),
          ],
          if (!widget.backups) ...[
            const Divider(),
            const _SectionTitle('Seguridad'),
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              value: _lock ?? false,
              onChanged: _lock == null || _busy ? null : _setLock,
              title: const Text('Bloqueo del dispositivo'),
            ),
            const Divider(),
            if (developerToolsEnabled) ...[
              const _SectionTitle('Desarrollo'),
              ListTile(
                leading: const Icon(Icons.developer_mode),
                title: const Text('Herramientas de desarrollo'),
                onTap: () => context.push('/developer-tools'),
              ),
              const Divider(),
            ],
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Información de la aplicación'),
              onTap: () => showLicensePage(
                context: context,
                applicationName: 'Cabal',
                applicationVersion: '0.1.0',
              ),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _setLock(bool value) async {
    setState(() => _busy = true);
    try {
      final service = AppLockService(ref.read(settingsProvider));
      final changed = await service.setEnabled(value);
      if (changed && mounted) setState(() => _lock = value);
    } catch (error) {
      _message('$error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _createBackup() async {
    final password = await _passwordDialog('Contraseña para el backup');
    if (password == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final saved = await ref
          .read(backupServiceProvider)
          .createWithPicker(password);
      if (saved) _message('Backup cifrado guardado.');
    } catch (error) {
      _message('$error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  Future<void> _restoreBackup() async {
    setState(() => _busy = true);
    try {
      final selected = await ref.read(backupServiceProvider).pickForRestore();
      if (selected == null || !mounted) return;
      final (bytes, summary) = selected;
      final accepted = await _confirmRestore(summary);
      if (!accepted || !mounted) return;
      final password = await _passwordDialog('Contraseña del backup');
      if (password == null) return;
      await ref
          .read(backupServiceProvider)
          .restore(
            bytes,
            password,
            onProgress: (value) {
              if (mounted) setState(() => _progress = value);
            },
          );
      if (!mounted) return;
      ref.invalidate(settingsProvider);
      _message('Backup restaurado.');
      context.go('/start');
    } catch (error) {
      _message('$error');
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
  }

  Future<String?> _passwordDialog(String title) => showTextPrompt(
    context,
    title: title,
    label: 'Contraseña',
    helper: 'Mínimo 8 caracteres. No puede recuperarse si la olvidás.',
    confirmLabel: 'Continuar',
    obscure: true,
  );

  Future<bool> _confirmRestore(BackupSummary summary) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Revisar backup'),
            content: Text(
              'Creado: ${summary.createdAt.toLocal()}\n'
              'Esquema: ${summary.schemaVersion}\n'
              'Cuentas: ${summary.accountCount}\n'
              'Movimientos: ${summary.transactionCount}\n\n'
              'La base actual se guardará antes de ser reemplazada.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Restaurar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _message(String value) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
    }
  }
}

final class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    child: Text(
      label,
      style: Theme.of(context).textTheme.titleSmall
          ?.copyWith(color: Theme.of(context).colorScheme.primary),
    ),
  );
}

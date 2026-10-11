import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/errors/user_message.dart';
import '../data/apk_installer.dart';
import '../data/update_log.dart';
import 'download_dialog.dart';
import 'update_dialog.dart';

const _resumeTimeout = Duration(minutes: 5);

/// Punto de entrada desde Ajustes: consulta, descarga, verifica e instala.
Future<void> checkForUpdates(BuildContext context, WidgetRef ref) async {
  final service = ref.read(updateServiceProvider);
  final installer = ref.read(apkInstallerProvider);
  try {
    final release = await service.checkForUpdate();
    if (!context.mounted) return;
    if (release == null) {
      _show(context, 'Ya tenés la última versión.');
      return;
    }
    final update = await showUpdateDialog(context, release);
    if (update != true || !context.mounted) return;
    final file = await showDownloadDialog(context, service, release);
    if (file == null || !context.mounted) return;
    final allowed = await _ensureInstallPermission(context, installer);
    if (!allowed || !context.mounted) return;
    await installer.install(file);
    updaterLog('Instalación lanzada');
  } catch (error) {
    if (error is UpdateException && error.failure == UpdateFailure.cancelled) {
      return;
    }
    updaterLog('Actualización interrumpida', error: error);
    if (context.mounted) _show(context, userMessage(error));
  }
}

/// true = puede instalar; false = el usuario canceló el diálogo.
/// Lanza UpdateException(installer) si sigue sin permiso tras volver de ajustes.
Future<bool> _ensureInstallPermission(
  BuildContext context,
  ApkInstaller installer,
) async {
  if (await installer.canInstall()) return true;
  if (!context.mounted) return false;
  final open = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Permitir instalar desde Cabal'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Abrir ajustes'),
        ),
      ],
    ),
  );
  if (open != true) {
    updaterLog('Permiso de instalación: el usuario no abrió los ajustes');
    return false;
  }
  updaterLog('Permiso de instalación pedido');
  await _waitForResume(() => installer.openInstallSettings());
  if (await installer.canInstall()) {
    updaterLog('Permiso de instalación concedido');
    return true;
  }
  updaterLog('Permiso de instalación denegado');
  throw const UpdateException(
    UpdateFailure.installer,
    'Cabal no tiene permiso para instalar. Activalo en los ajustes y volvé a intentar.',
  );
}

/// Ejecuta [action] y espera a que la app vuelva a primer plano (o al timeout).
Future<void> _waitForResume(Future<void> Function() action) async {
  final resumed = Completer<void>();
  final listener = AppLifecycleListener(
    onResume: () {
      if (!resumed.isCompleted) resumed.complete();
    },
  );
  try {
    await action();
    await resumed.future.timeout(_resumeTimeout, onTimeout: () {});
  } finally {
    listener.dispose();
  }
}

void _show(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

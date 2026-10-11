import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/errors/app_exception.dart';
import '../data/update_log.dart';
import '../data/update_service.dart';
import '../domain/release_info.dart';

typedef _Outcome = ({File? file, Object? error, StackTrace? stack});

/// Devuelve el APK verificado, o null si se canceló. Otros errores se propagan.
Future<File?> showDownloadDialog(
  BuildContext context,
  UpdateService service,
  ReleaseInfo release,
) async {
  final outcome = await showDialog<_Outcome>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _DownloadDialog(service: service, release: release),
  );
  if (outcome == null) return null;
  final error = outcome.error;
  if (error != null) {
    Error.throwWithStackTrace(error, outcome.stack ?? StackTrace.current);
  }
  return outcome.file;
}

final class _DownloadDialog extends StatefulWidget {
  const _DownloadDialog({required this.service, required this.release});

  final UpdateService service;
  final ReleaseInfo release;

  @override
  State<_DownloadDialog> createState() => _DownloadDialogState();
}

final class _DownloadDialogState extends State<_DownloadDialog> {
  final _cancel = Completer<void>();
  DownloadProgress? _progress;
  var _cancelRequested = false;
  var _finished = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    if (!_cancel.isCompleted) _cancel.complete();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      final file = await widget.service.download(
        widget.release,
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
        cancel: _cancel.future,
      );
      _finish((file: file, error: null, stack: null));
    } catch (error, stack) {
      final cancelled =
          error is UpdateException && error.failure == UpdateFailure.cancelled;
      if (cancelled) {
        updaterLog('Descarga cancelada por el usuario');
        _finish((file: null, error: null, stack: null));
      } else {
        _finish((file: null, error: error, stack: stack));
      }
    }
  }

  void _finish(_Outcome outcome) {
    if (_finished || !mounted) return;
    _finished = true;
    Navigator.of(context).pop(outcome);
  }

  void _cancelDownload() {
    if (_cancelRequested) return;
    setState(() => _cancelRequested = true);
    _cancel.complete();
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Descargando actualización'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(value: progress?.fraction),
            if (progress?.fraction != null) ...[
              const SizedBox(height: 12),
              Text(_percent(progress!.fraction!)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: _cancelRequested ? null : _cancelDownload,
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}

String _percent(double fraction) => '${(fraction * 100).round()} %';

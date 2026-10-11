import 'package:flutter/material.dart';

import '../domain/release_info.dart';

/// true = «Actualizar», false/null = «Más tarde».
Future<bool?> showUpdateDialog(BuildContext context, ReleaseInfo release) {
  final notes = release.notes.trim();
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Versión ${release.version}'),
      content: notes.isEmpty
          ? null
          : ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: SingleChildScrollView(child: Text(notes)),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Más tarde'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Actualizar'),
        ),
      ],
    ),
  );
}

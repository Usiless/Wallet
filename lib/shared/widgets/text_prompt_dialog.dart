import 'package:flutter/material.dart';

/// Pide una línea de texto. Devuelve `null` si se cancela.
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  required String label,
  required String confirmLabel,
  String initial = '',
  String? helper,
  bool obscure = false,
}) => showDialog<String>(
  context: context,
  builder: (_) => _TextPromptDialog(
    title: title,
    label: label,
    confirmLabel: confirmLabel,
    initial: initial,
    helper: helper,
    obscure: obscure,
  ),
);

/// El diálogo es dueño de su controlador: se libera cuando termina de cerrarse.
final class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({
    required this.title,
    required this.label,
    required this.confirmLabel,
    required this.initial,
    required this.helper,
    required this.obscure,
  });

  final String title, label, confirmLabel, initial;
  final String? helper;
  final bool obscure;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: TextField(
      controller: _controller,
      autofocus: true,
      obscureText: widget.obscure,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helper,
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, _controller.text),
        child: Text(widget.confirmLabel),
      ),
    ],
  );
}

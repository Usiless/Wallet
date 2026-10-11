import 'package:flutter/material.dart';

/// Indicador de carga del tamaño de una línea de texto.
final class InlineProgress extends StatelessWidget {
  const InlineProgress({super.key});

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 20,
    child: CircularProgressIndicator(strokeWidth: 2),
  );
}

import 'package:flutter/material.dart';

/// Botón flotante sin Hero compartido: con el tag por defecto, dos pantallas
/// con botón flotante en la misma navegación chocan.
final class AppFab extends StatelessWidget {
  const AppFab({
    required this.onPressed,
    required Widget this.child,
    this.tooltip,
    this.focusNode,
    super.key,
  }) : icon = null,
       label = null;

  const AppFab.extended({
    required this.onPressed,
    required Widget this.icon,
    required Widget this.label,
    super.key,
  }) : child = null,
       tooltip = null,
       focusNode = null;

  final VoidCallback onPressed;
  final Widget? child, icon, label;
  final String? tooltip;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) => child != null
      ? FloatingActionButton(
          heroTag: null,
          focusNode: focusNode,
          tooltip: tooltip,
          onPressed: onPressed,
          child: child,
        )
      : FloatingActionButton.extended(
          heroTag: null,
          onPressed: onPressed,
          icon: icon,
          label: label!,
        );
}

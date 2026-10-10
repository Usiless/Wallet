import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'app_fab.dart';

/// One entry point, shared by home and history. The menu never writes data.
class MovementFab extends StatefulWidget {
  const MovementFab({super.key});
  @override
  State<MovementFab> createState() => _MovementFabState();
}

class _MovementFabState extends State<MovementFab> {
  bool _open = false;
  final _focus = FocusNode();
  final _triggerFocus = FocusNode();
  @override
  void dispose() {
    _focus.dispose();
    _triggerFocus.dispose();
    super.dispose();
  }

  void _close({bool returnFocus = true}) {
    if (!_open || !mounted) return;
    setState(() => _open = false);
    if (returnFocus) _triggerFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_open,
    onPopInvokedWithResult: (popped, _) {
      if (!popped) _close();
    },
    child: CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
      child: Focus(
        focusNode: _focus,
        onFocusChange: (hasFocus) {
          if (!hasFocus) _close(returnFocus: false);
        },
        child: TapRegion(
          onTapOutside: (_) => _close(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_open)
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                        (MediaQuery.sizeOf(context).height -
                                MediaQuery.paddingOf(context).vertical -
                                220)
                            .clamp(80, 480),
                    maxWidth: MediaQuery.sizeOf(context).width - 32,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final action in [
                          ('expense', 'Gasto', Icons.remove),
                          ('income', 'Ingreso', Icons.add),
                          ('transfer', 'Transferir', Icons.swap_horiz),
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AppFab.extended(
                              onPressed: () {
                                _close(returnFocus: false);
                                context.push(
                                  '/transactions/new?type=${action.$1}',
                                );
                              },
                              icon: Icon(action.$3),
                              label: Text(action.$2),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              AppFab(
                focusNode: _triggerFocus,
                tooltip: _open ? 'Cerrar acciones' : 'Nuevo movimiento',
                onPressed: () {
                  setState(() => _open = !_open);
                  _triggerFocus.requestFocus();
                },
                child: AnimatedRotation(
                  turns: _open ? .125 : 0,
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 160),
                  child: const Icon(Icons.add),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

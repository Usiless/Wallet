import 'package:flutter/material.dart';

import '../../core/security/app_lock_service.dart';

final class AppLockGate extends StatefulWidget {
  const AppLockGate({required this.service, required this.child, super.key});

  final AppLockService service;
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _locked = true;
  bool _checking = true;
  DateTime? _backgroundedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _unlock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _backgroundedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed &&
        _backgroundedAt != null &&
        DateTime.now().difference(_backgroundedAt!) >
            const Duration(seconds: 10)) {
      _backgroundedAt = null;
      setState(() => _locked = true);
      _unlock();
    }
  }

  Future<void> _unlock() async {
    setState(() => _checking = true);
    final success = await widget.service.unlock();
    if (!mounted) return;
    setState(() {
      _locked = !success;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_locked) return widget.child;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Center(
        child: _checking
            ? const CircularProgressIndicator()
            : Semantics(
                button: true,
                label: 'Desbloquear Cabal',
                child: FilledButton.icon(
                  onPressed: _unlock,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('Desbloquear'),
                ),
              ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';

final class PendingCountBadge extends ConsumerWidget {
  const PendingCountBadge({
    required this.child,
    this.showCount = true,
    super.key,
  });
  final Widget child;
  final bool showCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(pendingCandidatesProvider).value?.length ?? 0;
    return Badge(
      isLabelVisible: count > 0,
      label: showCount ? Text(count > 99 ? '99+' : '$count') : null,
      child: child,
    );
  }
}

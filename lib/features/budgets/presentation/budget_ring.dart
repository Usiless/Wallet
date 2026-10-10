import 'dart:math' as math;

import 'package:flutter/material.dart';

final class BudgetRingSegment {
  const BudgetRingSegment(
    this.fraction, {
    required this.excess,
    required this.pending,
  });
  final double fraction;
  final bool excess, pending;
}

class BudgetRingPainter extends CustomPainter {
  const BudgetRingPainter(this.ratio, this.colors, {double? paidRatio})
    : paidRatio = paidRatio ?? ratio;
  final double ratio, paidRatio;
  final ColorScheme colors;

  List<BudgetRingSegment> get segments {
    final total = math.max(0.0, ratio), paid = paidRatio.clamp(0.0, total);
    final within = math.min(1.0, total), scale = math.max(1.0, total);
    return [
      BudgetRingSegment(
        math.min(paid, within) / scale,
        excess: false,
        pending: false,
      ),
      BudgetRingSegment(
        math.max(0.0, within - paid) / scale,
        excess: false,
        pending: true,
      ),
      BudgetRingSegment(
        math.max(0.0, paid - within) / scale,
        excess: true,
        pending: false,
      ),
      BudgetRingSegment(
        (total - math.max(paid, within)) / scale,
        excess: true,
        pending: true,
      ),
    ].where((segment) => segment.fraction > 0).toList();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero),
        radius = math.min(size.width, size.height) / 2 - 5;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8;
    canvas.drawCircle(
      center,
      radius,
      paint..color = colors.surfaceContainerHighest,
    );
    var start = -math.pi / 2;
    for (final segment in segments) {
      final color = segment.excess ? colors.error : colors.primary;
      final sweep = 2 * math.pi * segment.fraction;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint..color = color.withValues(alpha: segment.pending ? .42 : 1),
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(BudgetRingPainter old) =>
      old.ratio != ratio || old.paidRatio != paidRatio || old.colors != colors;
}

import 'package:finanzas_locales/features/budgets/presentation/budgets_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('250% pendiente normaliza verde 40 rojo 60 con opacidad suave', () {
    final ring = BudgetRingPainter(
      2.5,
      const ColorScheme.light(),
      paidRatio: 0,
    );
    expect(ring.segments.map((s) => s.fraction), [0.4, 0.6]);
    expect(ring.segments.every((s) => s.pending), isTrue);
    expect(ring.segments.first.excess, isFalse);
    expect(ring.segments.last.excess, isTrue);
  });
  test('300% pagado mantiene un único anillo proporcional', () {
    final ring = BudgetRingPainter(3, const ColorScheme.dark(), paidRatio: 3);
    expect(ring.segments.map((s) => s.fraction), [1 / 3, 2 / 3]);
    expect(ring.segments.every((s) => !s.pending), isTrue);
  });
  test('340% mixto y cero conservan escala real sin negativos', () {
    final ring = BudgetRingPainter(
      3.4,
      const ColorScheme.light(),
      paidRatio: .5,
    );
    expect(
      ring.segments.fold<double>(0, (sum, s) => sum + s.fraction),
      closeTo(1, 1e-9),
    );
    expect(
      ring.segments
          .where((s) => s.pending)
          .fold<double>(0, (sum, s) => sum + s.fraction),
      closeTo(2.9 / 3.4, 1e-9),
    );
    expect(
      const BudgetRingPainter(0, ColorScheme.light(), paidRatio: 0).segments,
      isEmpty,
    );
    expect(
      const BudgetRingPainter(-1, ColorScheme.light(), paidRatio: -1).segments,
      isEmpty,
    );
  });
}

/// Reparto entero acumulado: cada parte es el redondeo hacia abajo de la
/// proporción acumulada menos lo ya asignado. La suma es siempre [amount].
List<int> allocateCumulative(int amount, List<int> weights) {
  final total = weights.fold<int>(0, (sum, value) => sum + value);
  if (total <= 0) return List<int>.filled(weights.length, 0);
  var cumulative = 0, assigned = 0;
  return [
    for (final weight in weights)
      () {
        cumulative += weight;
        final accumulated = amount * cumulative ~/ total;
        final portion = accumulated - assigned;
        assigned = accumulated;
        return portion;
      }(),
  ];
}

/// Reparto entero con cada parte redondeada hacia abajo y el resto en la
/// última. [total] es el denominador; por defecto, la suma de [weights].
List<int> allocateLastRemainder(int amount, List<int> weights, {int? total}) {
  final denominator =
      total ?? weights.fold<int>(0, (sum, value) => sum + value);
  var allocated = 0;
  return [
    for (var i = 0; i < weights.length; i++)
      () {
        final part = i == weights.length - 1
            ? amount - allocated
            : amount * weights[i] ~/ denominator;
        allocated += part;
        return part;
      }(),
  ];
}

String normalizeForMatching(String value) {
  const replacements = {
    'Á': 'A',
    'À': 'A',
    'Ä': 'A',
    'Â': 'A',
    'É': 'E',
    'È': 'E',
    'Ë': 'E',
    'Ê': 'E',
    'Í': 'I',
    'Ì': 'I',
    'Ï': 'I',
    'Î': 'I',
    'Ó': 'O',
    'Ò': 'O',
    'Ö': 'O',
    'Ô': 'O',
    'Ú': 'U',
    'Ù': 'U',
    'Ü': 'U',
    'Û': 'U',
    'Ñ': 'N',
  };
  var normalized = value.trim().toUpperCase();
  replacements.forEach((source, target) {
    normalized = normalized.replaceAll(source, target);
  });
  return normalized
      .replaceAll(RegExp(r'[^A-Z0-9]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String normalizeMaskedAlias(String value) =>
    normalizeForMatching(value)
        .replaceAll(RegExp(r'[^A-Z0-9]'), '')
        .replaceFirst(RegExp(r'^0+'), '');

String sanitizeDiagnosticText(String value) => value
    .replaceAll(RegExp(r'\b\d{7,}\b'), '[NUMERO_OCULTO]')
    .replaceAll(RegExp(r'(?<!\d)\d{4}(?!\d)'), '••••');

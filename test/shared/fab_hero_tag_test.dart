import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('todos los FloatingActionButton desactivan el Hero compartido', () {
    final pattern = RegExp(r'FloatingActionButton(?:\.extended)?\(');
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final source = file.readAsStringSync();
      for (final match in pattern.allMatches(source)) {
        final tail = source.substring(match.end, match.end + 200);
        if (!tail.contains('heroTag')) offenders.add(file.path);
      }
    }
    expect(offenders, isEmpty);
  });
}

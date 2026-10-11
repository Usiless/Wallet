import 'package:finanzas_locales/features/updater/domain/app_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses X.Y.Z with optional v prefix and ignores +build', () {
    expect(AppVersion.tryParse('1.2.3'), const AppVersion(1, 2, 3));
    expect(AppVersion.tryParse('v1.2.3'), const AppVersion(1, 2, 3));
    expect(AppVersion.tryParse('V1.2.3'), const AppVersion(1, 2, 3));
    expect(AppVersion.tryParse('1.2.0+5'), const AppVersion(1, 2, 0));
  });

  test('rejects prerelease, short and malformed versions', () {
    expect(AppVersion.tryParse('1.2.3-beta'), isNull);
    expect(AppVersion.tryParse('1.2'), isNull);
    expect(AppVersion.tryParse('1.2.3.4'), isNull);
    expect(AppVersion.tryParse('-1.2.3'), isNull);
    expect(AppVersion.tryParse('latest'), isNull);
    expect(AppVersion.tryParse(''), isNull);
  });

  test('compares numerically, not as strings', () {
    final v1_10 = AppVersion.tryParse('1.10.0')!;
    final v1_9 = AppVersion.tryParse('1.9.0')!;
    expect(v1_10 > v1_9, isTrue);
    expect(v1_9 < v1_10, isTrue);
    expect(v1_10.compareTo(v1_9), greaterThan(0));
    expect(AppVersion.tryParse('2.0.0')! > v1_10, isTrue);
    expect(
      AppVersion.tryParse('1.2.10')! > AppVersion.tryParse('1.2.9')!,
      isTrue,
    );
  });

  test('equality ignores the v prefix and build number', () {
    final a = AppVersion.tryParse('v1.2.3+7');
    expect(a, const AppVersion(1, 2, 3));
    expect(a.hashCode, const AppVersion(1, 2, 3).hashCode);
    expect(a == const AppVersion(1, 2, 4), isFalse);
    expect(const AppVersion(1, 2, 3).toString(), '1.2.3');
  });
}

import 'package:firebase_remote_update/firebase_remote_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppVersion.tryParse', () {
    test('parses full and partial versions', () {
      expect(AppVersion.tryParse('1.2.8'), const AppVersion(1, 2, 8));
      expect(AppVersion.tryParse('2'), const AppVersion(2, 0, 0));
      expect(AppVersion.tryParse('2.1'), const AppVersion(2, 1, 0));
    });

    test('ignores build metadata after +', () {
      expect(AppVersion.tryParse('1.2.8+128'), const AppVersion(1, 2, 8));
    });

    test('returns null for invalid input (so callers fail open)', () {
      expect(AppVersion.tryParse(null), isNull);
      expect(AppVersion.tryParse(''), isNull);
      expect(AppVersion.tryParse('abc'), isNull);
    });
  });

  group('comparison (min-version semantics)', () {
    test('below minimum requires update', () {
      final current = AppVersion.tryParse('1.2.7')!;
      final min = AppVersion.tryParse('1.2.8')!;
      expect(current < min, isTrue);
    });

    test('at or above minimum does not', () {
      final min = AppVersion.tryParse('1.2.8')!;
      expect(AppVersion.tryParse('1.2.8')! < min, isFalse);
      expect(AppVersion.tryParse('1.3.0')! < min, isFalse);
      expect(AppVersion.tryParse('2.0.0')! < min, isFalse);
    });

    test('compares numerically, not lexically (2.10 > 2.9)', () {
      expect(
        AppVersion.tryParse('2.10.0')! > AppVersion.tryParse('2.9.0')!,
        isTrue,
      );
    });
  });
}

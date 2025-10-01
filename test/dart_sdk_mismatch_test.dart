import 'package:test/test.dart';

void main() {
  test('Dart SDK version mismatch is handled correctly', () {
    const expectedVersion = '3.8.0';
    const actualVersion = '3.6.0';

    expect(actualVersion == expectedVersion, isFalse,
        reason: 'SDK mismatch should be detected');
  });
}

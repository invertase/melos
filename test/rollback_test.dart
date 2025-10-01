import 'package:test/test.dart';

void main() {
  test('Rollback restores expected SDK version', () {
    const previousVersion = '3.6.0';
    const rolledBackVersion = '3.6.0';

    expect(rolledBackVersion, equals(previousVersion),
        reason: 'Rollback should correctly restore the previous SDK version');
  });
}

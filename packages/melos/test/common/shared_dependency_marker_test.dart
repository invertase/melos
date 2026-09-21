import 'package:melos/src/common/shared_dependency_marker.dart';
import 'package:test/test.dart';

void main() {
  group('applySharedDependencyMarkers', () {
    test('marks the shared entries of every section', () {
      const pubspec = '''
name: a

environment:
  sdk: ^3.9.0
  flutter: ">=3.0.0"

dependencies:
  collection: ^1.18.0
  path: ^1.9.0

dev_dependencies:
  test: any
''';

      expect(
        applySharedDependencyMarkers(
          pubspec,
          sharedKeys: {
            'environment': ['sdk'],
            'dependencies': ['collection', 'not_a_dependency'],
            'dev_dependencies': ['test'],
          },
        ),
        '''
name: a

environment:
  sdk: ^3.9.0 $sharedDependencyMarker
  flutter: ">=3.0.0"

dependencies:
  collection: ^1.18.0 $sharedDependencyMarker
  path: ^1.9.0

dev_dependencies:
  test: any $sharedDependencyMarker
''',
      );
    });

    test('marks the key of entries that span multiple lines', () {
      const pubspec = '''
name: a
dependencies:
  b:
    git: https://github.com/invertase/melos.git
  c:
''';

      expect(
        applySharedDependencyMarkers(
          pubspec,
          sharedKeys: {
            'dependencies': ['b', 'c'],
          },
        ),
        '''
name: a
dependencies:
  b: $sharedDependencyMarker
    git: https://github.com/invertase/melos.git
  c: $sharedDependencyMarker
''',
      );
    });

    test('keeps existing comments', () {
      const pubspec = '''
name: a
dependencies:
  collection: ^1.18.0 # Pinned.
''';

      expect(
        applySharedDependencyMarkers(
          pubspec,
          sharedKeys: {
            'dependencies': ['collection'],
          },
        ),
        '''
name: a
dependencies:
  collection: ^1.18.0 # Pinned. $sharedDependencyMarker
''',
      );
    });

    test('keeps the line endings and the missing trailing newline', () {
      const pubspec =
          'name: a\r\n'
          'dependencies:\r\n'
          '  collection: ^1.18.0\r\n'
          '  path: ^1.9.0';

      expect(
        applySharedDependencyMarkers(
          pubspec,
          sharedKeys: {
            'dependencies': ['collection', 'path'],
          },
        ),
        'name: a\r\n'
        'dependencies:\r\n'
        '  collection: ^1.18.0 $sharedDependencyMarker\r\n'
        '  path: ^1.9.0 $sharedDependencyMarker',
      );
    });

    test('is idempotent', () {
      const pubspec = '''
name: a
dependencies:
  collection: ^1.18.0
''';
      const sharedKeys = {
        'dependencies': ['collection'],
      };

      final marked = applySharedDependencyMarkers(
        pubspec,
        sharedKeys: sharedKeys,
      );

      expect(
        applySharedDependencyMarkers(marked, sharedKeys: sharedKeys),
        marked,
      );
    });

    test('removes the markers of entries that are no longer shared', () {
      const pubspec =
          '''
name: a
dependencies:
  collection: ^1.18.0 $sharedDependencyMarker
  path: ^1.9.0 $sharedDependencyMarker
''';

      expect(
        applySharedDependencyMarkers(
          pubspec,
          sharedKeys: {
            'dependencies': ['path'],
          },
        ),
        '''
name: a
dependencies:
  collection: ^1.18.0
  path: ^1.9.0 $sharedDependencyMarker
''',
      );
      expect(
        applySharedDependencyMarkers(pubspec, sharedKeys: {}),
        '''
name: a
dependencies:
  collection: ^1.18.0
  path: ^1.9.0
''',
      );
    });
  });
}

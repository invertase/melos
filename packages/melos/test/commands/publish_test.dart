import 'package:graphs/graphs.dart';
import 'package:melos/melos.dart';
import 'package:melos/src/common/utils.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec/pubspec.dart';
import 'package:test/expect.dart';
import 'package:test/scaffolding.dart';

final throwsCyclicError = throwsA(isA<CycleException>());

void main() {
  group('publish', () {
    group('sort packages', () {
      test('', () {
        //     b
        //   /   \
        // a       d
        //   \   /
        //     c
        //
        // e  -->  *f (external package)
        final packages = [
          _dummyPackage('a', deps: ['b', 'c']),
          _dummyPackage('b', deps: ['d']),
          _dummyPackage('c', deps: ['d']),
          _dummyPackage('d', deps: []),
          _dummyPackage('e', deps: ['f']),
        ]..shuffle();
        final packageNames = packages.map((el) => el.name).toList();
        sortPackagesTopologically(packages);

        final published = <String>{};
        for (final package in packages) {
          final dependencies = package.dependencies;
          for (final dependency in dependencies) {
            final isExternal = !packageNames.contains(dependency);
            final isPublished = published.contains(dependency);
            expect(isExternal || isPublished, isTrue);
          }
          published.add(package.name);
        }
      });

      test('w/ cyclic dependencies', () {
        final packages = [
          _dummyPackage('a', deps: ['b']),
          _dummyPackage('b', deps: ['a']),
        ];
        expect(
          () => sortPackagesTopologically(packages),
          returnsNormally,
        );
      });
    });
  });
}

Package _dummyPackage(String name, {List<String> deps = const []}) {
  return Package(
    devDependencies: [],
    dependencies: deps,
    dependencyOverrides: [],
    packageMap: {},
    name: name,
    path: '/',
    pathRelativeToWorkspace: '',
    version: Version(1, 0, 0),
    publishTo: null,
    pubSpec: const PubSpec(),
  );
}

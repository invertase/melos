import 'package:graphs/graphs.dart';
import 'package:melos/melos.dart';
import 'package:melos/src/commands/runner.dart';
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
        final packages = [
          _dummyPackage('a', deps: ['b', 'c']),
          _dummyPackage('b', deps: ['d']),
          _dummyPackage('c', deps: ['d']),
          _dummyPackage('d', deps: []),
        ]..shuffle();
        sortPackagesTopologically(packages);

        final previous = <String>{};
        for (final package in packages) {
          final dependencies = package.dependencies;
          expect(dependencies.every(previous.contains), isTrue);
          previous.add(package.name);
        }
      });

      test('w/ cyclic dependencies', () {
        final packages = [
          _dummyPackage('a', deps: ['b']),
          _dummyPackage('b', deps: ['a']),
        ];
        expect(
          () => sortPackagesTopologically(packages),
          throwsCyclicError,
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
    path: '',
    pathRelativeToWorkspace: '',
    version: Version(1, 0, 0),
    publishTo: null,
    pubSpec: const PubSpec(),
  );
}

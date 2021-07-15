/*
 * Copyright (c) 2016-present Invertase Limited & Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this library except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:io';

import 'package:path/path.dart';
import 'package:pub_semver/pub_semver.dart';

import 'mock_fs.dart';

/// Creates a mock workspace at [workspaceRoot], containing a `melos.yaml`
/// and a set of package folders as described by [packages].
///
/// The returned directory represents the workspace root.
Directory createMockWorkspaceFs({
  String workspaceName = 'monorepo',
  String workspaceRoot = '/melos_workspace',
  Iterable<String> workspacePackagesGlobs = const ['packages/**'],
  Iterable<MockPackageFs> packages = const [],
  bool setCwdToWorkspace = true,
  bool? intellij,
}) {
  assert(
    IOOverrides.current is MockFs,
    'Mock workspaces can only be created inside a mock filesystem',
  );

  // Create a `melos.yaml`
  _createMelosConfig(
    workspaceRoot,
    workspaceName,
    workspacePackagesGlobs,
    intellij: intellij,
  );

  // Sythesize a "package" (enough to satisfy our test requirements) for each
  // entry in `packages`
  for (final package in packages) {
    _createPackage(package, workspaceRoot);
    if (package.createExamplePackage) {
      _createPackage(package.examplePackage!, workspaceRoot);
    }
  }

  if (setCwdToWorkspace) {
    Directory.current = workspaceRoot;
  }

  return Directory(workspaceRoot);
}

void _createMelosConfig(
  String workspaceRoot,
  String workspaceName,
  Iterable<String> workspacePackagesGlobs, {
  required bool? intellij,
}) {
  final melosYaml = File(join(workspaceRoot, 'melos.yaml'));

  melosYaml.createSync(recursive: true);

  melosYaml.writeAsStringSync(
    '''
name: $workspaceName
packages:
${_yamlStringList(workspacePackagesGlobs)}
''',
  );

  if (intellij != null) {
    melosYaml.writeAsStringSync(
      '''
ide:
  intellij: $intellij
''',
      mode: FileMode.append,
    );
  }
}

void _createPackage(MockPackageFs package, String workspaceRoot) {
  final pubspec = StringBuffer();
  pubspec.writeln('name: ${package.name}');
  if (package.publishToNone) {
    pubspec.writeln('publish_to: none');
  }

  if (package.version != null) {
    pubspec.writeln('version: ${package.version}');
  }

  pubspec.writeln(
    '''
dependencies:
${_yamlMap(package.dependencyMap, indent: 2)}
''',
  );

  File(join(workspaceRoot, package.path, 'pubspec.yaml'))
    ..createSync(recursive: true)
    ..writeAsStringSync(pubspec.toString());
}

String _yamlStringList(Iterable<String> elements) {
  return elements.map((element) => '- $element').join('\n');
}

String _yamlMap(Map<String, String> map, {required int indent}) {
  final indentString = ' ' * indent;
  return map.entries.map((e) => '$indentString${e.key}: ${e.value}').join('\n');
}

/// Used to generate a package's on-disk representation via [createMockWorkspaceFs].
class MockPackageFs {
  MockPackageFs({
    required this.name,
    String? path,
    List<String>? dependencies,
    this.version,
    this.publishToNone = false,
    bool generateExample = false,
  })  : _path = path,
        dependencies = dependencies ?? const [],
        createExamplePackage = generateExample;

  /// Name of the package (must be a valid Dart package name)
  final String name;

  final Version? version;

  /// Workspace-root relative path
  String get path => _path ?? 'packages/$name';
  final String? _path;

  /// `true` if this package's yaml has a `publish_to: none` setting.
  final bool publishToNone;

  /// A list of package names this one depends on
  final List<String> dependencies;

  /// A mapping of dependency names to their versions (always "any")
  Map<String, String> get dependencyMap {
    return Map.fromEntries(dependencies.map((name) => MapEntry(name, 'any')));
  }

  /// `true` if an example package should be generated
  final bool createExamplePackage;

  /// Returns a file system description for this package's example
  MockPackageFs? get examplePackage {
    return createExamplePackage
        ? MockPackageFs(
            name: '${name}_example',
            path: join(path, 'example'),
            dependencies: [name],
            publishToNone: true,
          )
        : null;
  }
}

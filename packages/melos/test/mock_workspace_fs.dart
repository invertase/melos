import 'dart:io';

import 'package:melos/src/common/io.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';

import 'mock_fs.dart';

/// Creates a mock workspace at [workspaceRoot], containing a `melos.yaml` and a
/// set of package folders as described by [packages].
///
/// The returned directory represents the workspace root.
Directory createMockWorkspaceFs({
  String workspaceName = 'monorepo',
  String? workspaceRoot,
  Iterable<String> workspacePackagesGlobs = const ['packages/**'],
  Iterable<MockPackageFs> packages = const [],
  bool setCwdToWorkspace = true,
  bool? intellij,
}) {
  assert(
    IOOverrides.current is MockFs,
    'Mock workspaces can only be created inside a mock filesystem',
  );

  // ignore: parameter_assignments
  workspaceRoot =
      Platform.isWindows ? r'C:\melos_workspace' : '/melos_workspace';

  // Create a `melos.yaml`
  _createMelosConfig(
    workspaceRoot,
    workspaceName,
    workspacePackagesGlobs,
    intellij: intellij,
  );

  // Synthesize a "package" (enough to satisfy our test requirements) for each
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
  var contents = '''
name: $workspaceName
packages:
${_yamlStringList(workspacePackagesGlobs)}
''';

  if (intellij != null) {
    contents += '''
ide:
  intellij: $intellij
''';
  }

  writeTextFile(p.join(workspaceRoot, 'melos.yaml'), contents, recursive: true);
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

dev_dependencies:
${_yamlMap(package.devDependencyMap, indent: 2)}

dependency_overrides:
${_yamlMap(package.dependencyOverridesMap, indent: 2)}
''',
  );

  writeTextFile(
    p.join(workspaceRoot, package.path, 'pubspec.yaml'),
    pubspec.toString(),
    recursive: true,
  );
}

String _yamlStringList(Iterable<String> elements) {
  return elements.map((element) => '- $element').join('\n');
}

String _yamlMap(Map<String, String> map, {required int indent}) {
  final indentString = ' ' * indent;
  return map.entries.map((e) => '$indentString${e.key}: ${e.value}').join('\n');
}

/// Used to generate a package's on-disk representation via
/// [createMockWorkspaceFs].
class MockPackageFs {
  MockPackageFs({
    required this.name,
    String? path,
    List<String>? dependencies,
    List<String>? devDependencies,
    List<String>? dependencyOverrides,
    this.version,
    this.publishToNone = false,
    bool generateExample = false,
  })  : _path = path,
        dependencies = dependencies ?? const [],
        devDependencies = devDependencies ?? const [],
        dependencyOverrides = dependencyOverrides ?? const [],
        createExamplePackage = generateExample;

  /// Name of the package (must be a valid Dart package name)
  final String name;

  final Version? version;

  /// Workspace-root relative path
  String get path => _path ?? p.join('packages', name);
  final String? _path;

  /// `true` if this package's yaml has a `publish_to: none` setting.
  final bool publishToNone;

  /// A list of package names that are dependencies of this one.
  final List<String> dependencies;

  /// A list of package names that are dev dependencies of this one.
  final List<String> devDependencies;

  /// A list of package names that are dependency overrides of this one.
  final List<String> dependencyOverrides;

  /// A mapping of dependency names to their versions (always "any")
  Map<String, String> get dependencyMap =>
      Map.fromEntries(dependencies.map((name) => MapEntry(name, 'any')));

  /// A mapping of dev dependency names to their versions (always "any")
  Map<String, String> get devDependencyMap => Map.fromEntries(
        devDependencies.map((name) => MapEntry(name, 'any')),
      );

  /// A mapping of dependency overrides names to their versions (always "any")
  Map<String, String> get dependencyOverridesMap => Map.fromEntries(
        dependencyOverrides.map((name) => MapEntry(name, 'any')),
      );

  /// `true` if an example package should be generated
  final bool createExamplePackage;

  /// Returns a file system description for this package's example
  MockPackageFs? get examplePackage {
    return createExamplePackage
        ? MockPackageFs(
            name: '${name}_example',
            path: p.join(path, 'example'),
            dependencies: [name],
            publishToNone: true,
          )
        : null;
  }
}

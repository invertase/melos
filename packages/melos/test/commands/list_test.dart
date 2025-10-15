import 'dart:convert';

import 'package:melos/src/commands/runner.dart';
import 'package:melos/src/common/glob.dart';
import 'package:melos/src/package.dart';
import 'package:melos/src/workspace_config.dart';
import 'package:path/path.dart' as p;
import 'package:pub_semver/pub_semver.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:test/test.dart';

import '../matchers.dart';
import '../utils.dart';

void main() {
  late TestLogger logger;

  setUp(() => logger = TestLogger());

  group('melos list', () {
    group('with no format option', () {
      test(
        'logs public packages by default',
        () async {
          final workspaceDir = await createTemporaryWorkspace(
            workspacePackages: ['a', 'b'],
          );

          await createProject(workspaceDir, Pubspec('a'));
          await createProject(workspaceDir, Pubspec('b'));

          final logger = TestLogger();
          final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
            workspaceDir,
          );
          final melos = Melos(logger: logger, config: config);

          await melos.list();

          expect(
            logger.output,
            ignoringAnsii(
              '''
a
b
''',
            ),
          );
        },
      );

      test(
        'logs private packages by default',
        () async {
          final workspaceDir = await createTemporaryWorkspace(
            workspacePackages: ['a', 'b', 'c'],
          );

          await createProject(workspaceDir, Pubspec('a'));
          await createProject(workspaceDir, Pubspec('b'));
          await createProject(workspaceDir, Pubspec('c', publishTo: 'none'));

          final logger = TestLogger();
          final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
            workspaceDir,
          );
          final melos = Melos(logger: logger, config: config);

          await melos.list();

          expect(
            logger.output,
            ignoringAnsii(
              '''
a
b
c
''',
            ),
          );
        },
      );

      test(
        'applies package filters',
        () async {
          final workspaceDir = await createTemporaryWorkspace(
            workspacePackages: ['a', 'b', 'c'],
          );

          await createProject(workspaceDir, Pubspec('a'));
          await createProject(workspaceDir, Pubspec('b'));
          await createProject(workspaceDir, Pubspec('c'));

          final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
            workspaceDir,
          );
          final melos = Melos(logger: logger, config: config);

          await melos.list(
            packageFilters: PackageFilters(
              includePrivatePackages: true,
              ignore: [
                createGlob('b', currentDirectoryPath: workspaceDir.path),
              ],
            ),
          );

          expect(
            logger.output,
            ignoringAnsii(
              '''
a
c
''',
            ),
          );
        },
      );

      test(
        'supports long flag for extra information',
        () async {
          final workspaceDir = await createTemporaryWorkspace(
            workspacePackages: ['a', 'b', 'long_name'],
          );

          await createProject(
            workspaceDir,
            Pubspec('a', version: Version(1, 2, 3)),
          );
          await createProject(
            workspaceDir,
            Pubspec('b', dependencies: {'a': HostedDependency()}),
          );
          await createProject(workspaceDir, Pubspec('long_name'));

          final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
            workspaceDir,
          );
          final melos = Melos(logger: logger, config: config);

          await melos.list(
            long: true,
          );

          expect(
            logger.output,
            ignoringAnsii(
              '''
a         1.2.3 packages/a
b         0.0.0 packages/b         PRIVATE
long_name 0.0.0 packages/long_name PRIVATE
''',
            ),
          );
        },
      );

      test(
        'supports relative flag for relative paths',
        () async {
          final workspaceDir = await createTemporaryWorkspace(
            workspacePackages: const ['a', 'b', 'c'],
          );

          await createProject(workspaceDir, Pubspec('a'));
          await createProject(workspaceDir, Pubspec('b'));
          await createProject(workspaceDir, Pubspec('c'));

          final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
            workspaceDir,
          );
          final melos = Melos(logger: logger, config: config);
          await melos.list(
            relativePaths: true,
          );

          expect(
            logger.output,
            ignoringAnsii(
              '''
packages/a
packages/b
packages/c
''',
            ),
          );
        },
      );
    });

    group('parsable', () {
      test(
        'relativePaths flag prints relative paths only if true',
        () async {
          final workspaceDir = await createTemporaryWorkspace(
            workspacePackages: ['a', 'b', 'c'],
          );

          await createProject(workspaceDir, Pubspec('a'));
          await createProject(workspaceDir, Pubspec('b'));
          await createProject(workspaceDir, Pubspec('c'));

          final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
            workspaceDir,
          );
          final melos = Melos(logger: logger, config: config);
          await melos.list(
            kind: ListOutputKind.parsable,
            relativePaths: true,
          );

          expect(
            logger.output,
            ignoringAnsii(
              '''
packages/a
packages/b
packages/c
''',
            ),
          );
        },
      );

      test(
        'full package path is printed by default if relativePaths is false or '
        'not set',
        () async {
          final workspaceDir = await createTemporaryWorkspace(
            workspacePackages: ['a', 'b', 'c'],
          );

          final packageDirs = [
            await createProject(workspaceDir, Pubspec('a')),
            await createProject(workspaceDir, Pubspec('b')),
            await createProject(workspaceDir, Pubspec('c')),
          ];

          final packagePaths = packageDirs
              .map((package) => p.join(workspaceDir.path, package.path))
              .map(p.canonicalize);

          final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
            workspaceDir,
          );
          final melos = Melos(logger: logger, config: config);
          await melos.list(
            kind: ListOutputKind.parsable,
          );

          expect(
            logger.output,
            ignoringAnsii(
              '''
${packagePaths.join('\n')}
''',
            ),
          );
        },
      );
    });

    group('graph', () {
      test(
        'reports all dependencies in workspace',
        () async {
          final workspaceDir = await createTemporaryWorkspace(
            workspacePackages: ['a', 'b', 'c', 'd'],
          );

          await createProject(workspaceDir, Pubspec('a'));
          await createProject(workspaceDir, Pubspec('b'));
          await createProject(workspaceDir, Pubspec('c'));
          await createProject(
            workspaceDir,
            Pubspec(
              'd',
              dependencies: {'a': HostedDependency()},
              devDependencies: {'b': HostedDependency()},
              dependencyOverrides: {'c': HostedDependency()},
            ),
          );

          final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
            workspaceDir,
          );
          final melos = Melos(logger: logger, config: config);
          await melos.list(
            kind: ListOutputKind.graph,
          );

          expect(
            logger.output,
            '''
{
  "a": [],
  "b": [],
  "c": [],
  "d": [
    "a",
    "b",
    "c"
  ]
}
''',
          );
        },
      );
    });

    group('json', () {
      test(
        'reports all dependencies in workspace',
        () async {
          final workspaceDir = await createTemporaryWorkspace(
            workspacePackages: ['a', 'b', 'c', 'd'],
          );

          await createProject(workspaceDir, Pubspec('a'));
          await createProject(workspaceDir, Pubspec('b'));
          await createProject(workspaceDir, Pubspec('c'));
          await createProject(
            workspaceDir,
            Pubspec(
              'd',
              dependencies: {'a': HostedDependency()},
              devDependencies: {'b': HostedDependency()},
              dependencyOverrides: {'c': HostedDependency()},
            ),
          );

          final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
            workspaceDir,
          );
          final melos = Melos(logger: logger, config: config);
          await melos.list(
            kind: ListOutputKind.json,
            long: true,
          );
          final json = (jsonDecode(logger.output) as List<Object?>)
              .cast<Map<String, Object?>>();

          expect(
            json.map(
              (pkg) => {
                'name': pkg['name'],
                'dependencies': pkg['dependencies'],
                'dependents': pkg['dependents'],
              },
            ),
            [
              {
                'name': 'a',
                'dependencies': <String>[],
                'dependents': ['d'],
              },
              {
                'name': 'b',
                'dependencies': <String>[],
                'dependents': ['d'],
              },
              {
                'name': 'c',
                'dependencies': <String>[],
                'dependents': ['d'],
              },
              {
                'name': 'd',
                'dependencies': ['a', 'b', 'c'],
                'dependents': <String>[],
              },
            ],
          );
        },
      );
    });

    group('gviz', () {
      test(
        'reports all dependencies in workspace',
        () async {
          final workspaceDir = await createTemporaryWorkspace(
            workspacePackages: ['a', 'b', 'c', 'd'],
          );

          await createProject(workspaceDir, Pubspec('a'));
          await createProject(workspaceDir, Pubspec('b'));
          await createProject(workspaceDir, Pubspec('c'));
          await createProject(
            workspaceDir,
            Pubspec(
              'd',
              dependencies: {'a': HostedDependency()},
              devDependencies: {'b': HostedDependency()},
              dependencyOverrides: {'c': HostedDependency()},
            ),
          );

          final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
            workspaceDir,
          );
          final melos = Melos(logger: logger, config: config);
          await melos.list(
            kind: ListOutputKind.gviz,
          );

          expect(
            logger.output,
            '''
digraph packages {
  size="10"; ratio=fill;
  a [shape="box"; color="#ff5307"];
  b [shape="box"; color="#e03cc2"];
  c [shape="box"; color="#fa533c"];
  d [shape="box"; color="#80dce6"];
  d -> a [style="filled"; color="#ff5307"];
  d -> b [style="dashed"; color="#e03cc2"];
  d -> c [style="dotted"; color="#fa533c"];
  subgraph "cluster packages" {
    label="packages";
    color="#6b4949";
    a;
    b;
    c;
    d;
  }
}
''',
          );
        },
      );
    });
    group('mermaid', () {
      test(
        'reports all dependencies in workspace',
        () async {
          final workspaceDir = await createTemporaryWorkspace(
            workspacePackages: ['a', 'b', 'c', 'd'],
          );

          await createProject(workspaceDir, Pubspec('a'));
          await createProject(workspaceDir, Pubspec('b'));
          await createProject(workspaceDir, Pubspec('c'));
          await createProject(
            workspaceDir,
            Pubspec(
              'd',
              dependencies: {'a': HostedDependency()},
              devDependencies: {'b': HostedDependency()},
              dependencyOverrides: {'c': HostedDependency()},
            ),
          );

          final config = await MelosWorkspaceConfig.fromWorkspaceRoot(
            workspaceDir,
          );
          final melos = Melos(logger: logger, config: config);
          await melos.list(
            kind: ListOutputKind.mermaid,
          );

          expect(logger.output, '''
graph TD
  a["a"]
  style a stroke:#ff5307
  b["b"]
  style b stroke:#e03cc2
  c["c"]
  style c stroke:#fa533c
  d["d"]
  style d stroke:#80dce6
  d --> a
  d -.-> b
  d -..-> c
  subgraph packages0 ["packages"]
    a
    b
    c
    d
  end
''');
        },
      );
    });
  });
}

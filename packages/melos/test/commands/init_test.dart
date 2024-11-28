import 'dart:io';

import 'package:melos/melos.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import '../utils.dart';

void main() {
  group('init', () {
    late TestLogger logger;
    late Directory tempDir;

    setUp(() async {
      logger = TestLogger();
      tempDir = await Directory.systemTemp.createTemp('melos_init_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('creates a new workspace with default settings', () async {
      final workspaceDir = Directory(p.join(tempDir.path, 'my_workspace'));
      final config = MelosWorkspaceConfig.emptyWith(
        name: 'my_workspace',
        path: tempDir.path,
      );
      final melos = Melos(logger: logger, config: config);

      await melos.init(
        'my_workspace',
        directory: workspaceDir.path,
        packages: [],
        useAppDir: true,
      );

      // Verify directory structure
      expect(workspaceDir.existsSync(), isTrue);
      expect(
        Directory(p.join(workspaceDir.path, 'packages')).existsSync(),
        isTrue,
      );
      expect(Directory(p.join(workspaceDir.path, 'apps')).existsSync(), isTrue);

      // Verify melos.yaml content
      final melosYaml = loadYaml(
        File(p.join(workspaceDir.path, 'melos.yaml')).readAsStringSync(),
      ) as YamlMap;
      expect(melosYaml['name'], equals('my_workspace'));
      expect(melosYaml['packages'], equals(['apps/*', 'packages/*']));

      // Verify pubspec.yaml content
      final pubspecYaml = loadYaml(
        File(p.join(workspaceDir.path, 'pubspec.yaml')).readAsStringSync(),
      ) as YamlMap;
      expect(pubspecYaml['name'], equals('my_workspace'));
      expect(
        (pubspecYaml['environment'] as YamlMap)['sdk'],
        contains('>='),
      );
      expect(
        (pubspecYaml['dev_dependencies'] as YamlMap)['melos'],
        contains('^'),
      );

      // Verify logger output
      expect(
        logger.output,
        contains(
          'Initialized Melos workspace in ${workspaceDir.path}',
        ),
      );
    });

    test('creates a workspace with custom packages', () async {
      final workspaceDir = Directory(p.join(tempDir.path, 'custom_workspace'));
      final config = MelosWorkspaceConfig.emptyWith(
        name: 'custom_workspace',
        path: tempDir.path,
      );
      final melos = Melos(logger: logger, config: config);

      await melos.init(
        'custom_workspace',
        directory: workspaceDir.path,
        packages: ['custom/*', 'plugins/**'],
        useAppDir: false,
      );

      final melosYaml = loadYaml(
        File(p.join(workspaceDir.path, 'melos.yaml')).readAsStringSync(),
      ) as YamlMap;
      expect(melosYaml['packages'], equals(['custom/*', 'plugins/**']));
    });

    test('creates workspace in current directory when directory is "."',
        () async {
      final config = MelosWorkspaceConfig.emptyWith(
        name: 'melos_init_test_',
        path: tempDir.path,
      );
      final melos = Melos(logger: logger, config: config);

      final originalDir = Directory.current;
      try {
        Directory.current = tempDir;

        await melos.init(
          '.',
          directory: '.',
          packages: [],
          useAppDir: true,
        );

        // Verify files were created in current directory
        expect(File('melos.yaml').existsSync(), isTrue);
        expect(File('pubspec.yaml').existsSync(), isTrue);
        expect(Directory('packages').existsSync(), isTrue);
        expect(Directory('apps').existsSync(), isTrue);

        final melosYaml =
            loadYaml(File('melos.yaml').readAsStringSync()) as YamlMap;
        expect(melosYaml['name'], equals(p.basename(tempDir.path)));
      } finally {
        Directory.current = originalDir;
      }
    });

    test('throws error if target directory already exists', () async {
      final workspaceDir = Directory(p.join(tempDir.path, 'existing_workspace'))
        ..createSync();
      final config = MelosWorkspaceConfig.emptyWith(
        name: 'existing_workspace',
        path: tempDir.path,
      );
      final melos = Melos(logger: logger, config: config);

      expect(
        () => melos.init(
          'existing_workspace',
          directory: workspaceDir.path,
          packages: [],
          useAppDir: false,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'Directory ${workspaceDir.path} already exists',
          ),
        ),
      );
    });

    test('creates workspace without apps directory when useAppDir is false',
        () async {
      final workspaceDir = Directory(p.join(tempDir.path, 'no_apps_workspace'));
      final config = MelosWorkspaceConfig.emptyWith(
        name: 'no_apps_workspace',
        path: tempDir.path,
      );
      final melos = Melos(logger: logger, config: config);

      await melos.init(
        'no_apps_workspace',
        directory: workspaceDir.path,
        packages: [],
        useAppDir: false,
      );

      expect(
        Directory(p.join(workspaceDir.path, 'apps')).existsSync(),
        isFalse,
      );

      final melosYaml = loadYaml(
        File(p.join(workspaceDir.path, 'melos.yaml')).readAsStringSync(),
      ) as YamlMap;
      expect(melosYaml['packages'], equals(['packages/*']));
    });
  });
}

import 'dart:async';
import 'dart:io';

import 'package:melos/melos.dart';
import 'package:melos/src/common/environment_variable_key.dart';
import 'package:melos/src/common/io.dart';
import 'package:melos/src/common/platform.dart';
import 'package:melos/src/sdk_launcher.dart';
import 'package:path/path.dart' as p;
import 'package:platform/platform.dart' show FakePlatform;
import 'package:test/test.dart';

import 'mock_env.dart';
import 'utils.dart';

final _pathSeparator = Platform.isWindows ? ';' : ':';

FakePlatform _fakePlatform({
  required Map<String, String> environment,
  Uri? script,
  String? resolvedExecutable,
  List<String> executableArguments = const [],
}) {
  return FakePlatform(
    operatingSystem: Platform.operatingSystem,
    environment: environment,
    script: script,
    resolvedExecutable: resolvedExecutable,
    executableArguments: executableArguments,
  );
}

T _withPlatform<T>(FakePlatform platform, T Function() body) {
  return runZoned(body, zoneValues: {currentPlatformZoneKey: platform});
}

void main() {
  group('resolveLaunchSdkPath', () {
    Future<Directory> createWorkspace({String? sdkPath}) {
      return createTemporaryWorkspace(
        workspacePackages: ['a'],
        configBuilder: (path) => MelosWorkspaceConfig(
          path: path,
          name: 'test_workspace',
          packages: const [],
          sdkPath: sdkPath,
        ),
      );
    }

    test('returns null outside of a workspace', () async {
      final directory = createTestTempDir();

      expect(await resolveLaunchSdkPath([], current: directory), isNull);
    });

    test('returns null when no sdk path is configured', () async {
      final workspace = await createWorkspace();

      expect(await resolveLaunchSdkPath([], current: workspace), isNull);
    });

    test(
      'resolves sdkPath from the root pubspec relative to the workspace',
      () async {
        final workspace = await createWorkspace(sdkPath: '.fvm/flutter_sdk');

        expect(
          await resolveLaunchSdkPath([], current: workspace),
          p.join(workspace.path, '.fvm', 'flutter_sdk'),
        );
      },
    );

    test('finds the workspace root from a nested directory', () async {
      final workspace = await createWorkspace(sdkPath: '.fvm/flutter_sdk');
      final packageDirectory = Directory(
        p.join(workspace.path, 'packages', 'a'),
      );

      expect(
        await resolveLaunchSdkPath([], current: packageDirectory),
        p.join(workspace.path, '.fvm', 'flutter_sdk'),
      );
    });

    test(
      'the environment variable has precedence over the root pubspec',
      withMockPlatform(
        () async {
          final workspace = await createWorkspace(sdkPath: '.fvm/flutter_sdk');

          expect(
            await resolveLaunchSdkPath([], current: workspace),
            p.join(workspace.path, 'env_sdk'),
          );
        },
        platform: _fakePlatform(
          environment: {EnvironmentVariableKey.melosSdkPath: 'env_sdk'},
        ),
      ),
    );

    test(
      'the command line option has precedence over the environment variable',
      withMockPlatform(
        () async {
          final workspace = await createWorkspace(sdkPath: '.fvm/flutter_sdk');

          expect(
            await resolveLaunchSdkPath(
              ['--sdk-path', 'command_sdk', 'bootstrap'],
              current: workspace,
            ),
            p.join(workspace.path, 'command_sdk'),
          );
          expect(
            await resolveLaunchSdkPath(
              ['--verbose', '--sdk-path=command_sdk', 'bootstrap'],
              current: workspace,
            ),
            p.join(workspace.path, 'command_sdk'),
          );
        },
        platform: _fakePlatform(
          environment: {EnvironmentVariableKey.melosSdkPath: 'env_sdk'},
        ),
      ),
    );

    test('returns null when the special value "auto" is used', () async {
      final workspace = await createWorkspace(sdkPath: '.fvm/flutter_sdk');

      expect(
        await resolveLaunchSdkPath(
          ['--sdk-path', 'auto', 'bootstrap'],
          current: workspace,
        ),
        isNull,
      );
    });

    test('keeps absolute sdk paths as is', () async {
      final absoluteSdkPath = p.normalize(p.absolute('sdks', 'flutter'));
      final workspace = await createWorkspace(sdkPath: absoluteSdkPath);

      expect(
        await resolveLaunchSdkPath([], current: workspace),
        absoluteSdkPath,
      );
    });
  });

  group('planSdkRelaunch', () {
    late Directory sdkDirectory;
    late String sdkBinPath;

    setUp(() {
      sdkDirectory = createTestTempDir();
      sdkBinPath = p.join(sdkDirectory.path, 'bin');
      ensureDir(sdkBinPath);
    });

    const arguments = ['bootstrap', '--no-enforce-lockfile'];
    final script = Uri.file(p.absolute('bin', 'melos.dart-3.9.0.snapshot'));
    final executable = p.absolute('sdk', 'bin', 'dart');

    test('returns null when the sdk has no bin directory', () {
      final platform = _fakePlatform(
        environment: {EnvironmentVariableKey.path: '/usr/bin'},
        script: script,
        resolvedExecutable: executable,
      );

      expect(
        _withPlatform(
          platform,
          () => planSdkRelaunch(
            arguments,
            sdkPath: p.join(sdkDirectory.path, 'missing'),
          ),
        ),
        isNull,
      );
    });

    test(
      'returns null when the sdk bin directory is already first on the PATH',
      () {
        final platform = _fakePlatform(
          environment: {
            EnvironmentVariableKey.path: '$sdkBinPath$_pathSeparator/usr/bin',
          },
          script: script,
          resolvedExecutable: executable,
        );

        expect(
          _withPlatform(
            platform,
            () => planSdkRelaunch(arguments, sdkPath: sdkDirectory.path),
          ),
          isNull,
        );
      },
    );

    test('relaunches the running script with the sdk first on the PATH', () {
      final platform = _fakePlatform(
        environment: {
          EnvironmentVariableKey.path: '/usr/bin',
          'HOME': '/home/user',
        },
        script: script,
        resolvedExecutable: executable,
        executableArguments: [
          '--resolved_executable_name=$executable',
          '--executable_name=$executable',
          '--packages=.dart_tool/package_config.json',
          '--enable-asserts',
        ],
      );

      final relaunch = _withPlatform(
        platform,
        () => planSdkRelaunch(arguments, sdkPath: sdkDirectory.path),
      );

      expect(relaunch, isNotNull);
      expect(relaunch!.executable, executable);
      expect(relaunch.arguments, [
        '--packages=.dart_tool/package_config.json',
        '--enable-asserts',
        script.toFilePath(),
        ...arguments,
      ]);
      expect(relaunch.environment, {
        EnvironmentVariableKey.path: '$sdkBinPath$_pathSeparator/usr/bin',
      });
    });

    test('uses the same PATH key as the parent environment', () {
      final platform = _fakePlatform(
        environment: {'Path': '/usr/bin'},
        script: script,
        resolvedExecutable: executable,
      );

      final relaunch = _withPlatform(
        platform,
        () => planSdkRelaunch(arguments, sdkPath: sdkDirectory.path),
      );

      expect(relaunch!.environment.keys, ['Path']);
      expect(relaunch.environment['Path'], startsWith(sdkBinPath));
    });

    test('does not pass the script to a standalone executable', () {
      final standaloneExecutable = p.absolute('melos', 'bin', 'melos');
      final platform = _fakePlatform(
        environment: {EnvironmentVariableKey.path: '/usr/bin'},
        script: Uri.file(standaloneExecutable),
        resolvedExecutable: standaloneExecutable,
      );

      final relaunch = _withPlatform(
        platform,
        () => planSdkRelaunch(arguments, sdkPath: sdkDirectory.path),
      );

      expect(relaunch!.executable, standaloneExecutable);
      expect(relaunch.arguments, arguments);
    });

    test('returns null when the running script is not a file', () {
      final platform = _fakePlatform(
        environment: {EnvironmentVariableKey.path: '/usr/bin'},
        script: Uri.parse('data:application/dart;charset=utf-8,void%20main'),
        resolvedExecutable: executable,
      );

      expect(
        _withPlatform(
          platform,
          () => planSdkRelaunch(arguments, sdkPath: sdkDirectory.path),
        ),
        isNull,
      );
    });
  });
}

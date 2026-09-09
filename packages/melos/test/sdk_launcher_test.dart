import 'dart:io';

import 'package:cli_launcher/cli_launcher.dart';
import 'package:melos/melos.dart';
import 'package:melos/src/common/environment_variable_key.dart';
import 'package:melos/src/common/io.dart';
import 'package:melos/src/sdk_launcher.dart';
import 'package:path/path.dart' as p;
import 'package:platform/platform.dart' show FakePlatform;
import 'package:test/test.dart';

import 'mock_env.dart';
import 'utils.dart';

FakePlatform _platformWithEnvironment(Map<String, String> environment) {
  return FakePlatform(
    operatingSystem: Platform.operatingSystem,
    environment: environment,
  );
}

void main() {
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

  /// Creates an SDK directory with a `bin` directory at [sdkPath], resolved
  /// relative to [workspace], and returns its absolute path.
  String createSdk(Directory workspace, String sdkPath) {
    final absoluteSdkPath = p.join(workspace.path, sdkPath);
    ensureDir(p.join(absoluteSdkPath, 'bin'));
    return absoluteSdkPath;
  }

  group('resolveLaunchSdkPath', () {
    test('returns null without a workspace root', () {
      expect(resolveLaunchSdkPath([], workspaceRoot: null), isNull);
    });

    test('returns null when no sdk path is configured', () async {
      final workspace = await createWorkspace();

      expect(resolveLaunchSdkPath([], workspaceRoot: workspace), isNull);
    });

    test(
      'resolves sdkPath from the root pubspec relative to the workspace',
      () async {
        final workspace = await createWorkspace(sdkPath: '.fvm/flutter_sdk');
        final sdkPath = createSdk(workspace, '.fvm/flutter_sdk');

        expect(resolveLaunchSdkPath([], workspaceRoot: workspace), sdkPath);
      },
    );

    test(
      'the environment variable has precedence over the root pubspec',
      withMockPlatform(
        () async {
          final workspace = await createWorkspace(sdkPath: '.fvm/flutter_sdk');
          createSdk(workspace, '.fvm/flutter_sdk');
          final envSdkPath = createSdk(workspace, 'env_sdk');

          expect(
            resolveLaunchSdkPath([], workspaceRoot: workspace),
            envSdkPath,
          );
        },
        platform: _platformWithEnvironment({
          EnvironmentVariableKey.melosSdkPath: 'env_sdk',
        }),
      ),
    );

    test(
      'the command line option has precedence over the environment variable',
      withMockPlatform(
        () async {
          final workspace = await createWorkspace(sdkPath: '.fvm/flutter_sdk');
          createSdk(workspace, '.fvm/flutter_sdk');
          createSdk(workspace, 'env_sdk');
          final commandSdkPath = createSdk(workspace, 'command_sdk');

          expect(
            resolveLaunchSdkPath(
              ['--sdk-path', 'command_sdk', 'bootstrap'],
              workspaceRoot: workspace,
            ),
            commandSdkPath,
          );
          expect(
            resolveLaunchSdkPath(
              ['--verbose', '--sdk-path=command_sdk', 'bootstrap'],
              workspaceRoot: workspace,
            ),
            commandSdkPath,
          );
        },
        platform: _platformWithEnvironment({
          EnvironmentVariableKey.melosSdkPath: 'env_sdk',
        }),
      ),
    );

    test('returns null when the special value "auto" is used', () async {
      final workspace = await createWorkspace(sdkPath: '.fvm/flutter_sdk');
      createSdk(workspace, '.fvm/flutter_sdk');

      expect(
        resolveLaunchSdkPath(
          ['--sdk-path', 'auto', 'bootstrap'],
          workspaceRoot: workspace,
        ),
        isNull,
      );
    });

    test('keeps absolute sdk paths as is', () async {
      final sdkDirectory = createTestTempDir();
      ensureDir(p.join(sdkDirectory.path, 'bin'));
      final workspace = await createWorkspace(sdkPath: sdkDirectory.path);

      expect(
        resolveLaunchSdkPath([], workspaceRoot: workspace),
        sdkDirectory.path,
      );
    });

    test('returns null when the sdk has no bin directory', () async {
      final workspace = await createWorkspace(sdkPath: '.fvm/flutter_sdk');

      expect(resolveLaunchSdkPath([], workspaceRoot: workspace), isNull);
    });
  });

  group('resolveLocalLaunchConfig', () {
    test('uses the lock file root of the local installation', () async {
      final workspace = await createWorkspace(sdkPath: '.fvm/flutter_sdk');
      final sdkPath = createSdk(workspace, '.fvm/flutter_sdk');
      final context = LaunchContext(
        directory: Directory(p.join(workspace.path, 'packages', 'a')),
        localInstallation: ExecutableInstallation(
          name: ExecutableName('melos'),
          isSelf: false,
          packageRoot: workspace,
        ),
      );

      final config = await resolveLocalLaunchConfig(['bootstrap'], context);

      expect(config.sdkPath, sdkPath);
    });

    test('has no sdk path without a local installation', () async {
      final context = LaunchContext(directory: createTestTempDir());

      final config = await resolveLocalLaunchConfig(['bootstrap'], context);

      expect(config.sdkPath, isNull);
    });
  });
}

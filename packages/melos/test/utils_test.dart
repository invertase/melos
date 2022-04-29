import 'package:melos/src/common/utils.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

import 'utils.dart';

void main() {
  group('pubCommandExecArgs', () {
    test('no sdk path specified', () {
      final workspace = VirtualWorkspaceBuilder('').build();

      expect(
        pubCommandExecArgs(
          workspace: workspace,
          useFlutter: true,
        ),
        ['flutter', 'pub'],
      );
      expect(
        pubCommandExecArgs(
          workspace: workspace,
          useFlutter: false,
        ),
        [if (isPubSubcommand(workspace: workspace)) 'dart', 'pub'],
      );
    });

    test('with sdk path specified', () {
      final sdkPath = join('flutter_sdks', 'stable');
      final workspace = VirtualWorkspaceBuilder('', sdkPath: sdkPath).build();

      expect(
        pubCommandExecArgs(
          workspace: workspace,
          useFlutter: true,
        ),
        [join(sdkPath, 'bin', 'flutter'), 'pub'],
      );
      expect(
        pubCommandExecArgs(
          workspace: workspace,
          useFlutter: false,
        ),
        [join(sdkPath, 'bin', 'dart'), 'pub'],
      );
    });
  });
}

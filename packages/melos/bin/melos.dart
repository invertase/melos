import 'dart:io';

import 'package:melos/src/command_runner.dart';
import 'package:melos/src/common/exception.dart';
import 'package:melos/src/workspace_configs.dart';

Future<void> main(List<String> arguments) async {
  try {
    final config = await MelosWorkspaceConfig.fromDirectory(Directory.current);
    await MelosCommandRunner(config).run(arguments);
  } on MelosException catch (err) {
    stderr.writeln(err.toString());
    exitCode = 1;
  } catch (err) {
    exitCode = 1;
    rethrow;
  }
}

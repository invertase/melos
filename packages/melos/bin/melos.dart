import 'dart:io';

import 'package:melos/src/command_runner.dart';
import 'package:melos/src/common/exception.dart';
import 'package:melos/src/common/logger.dart';

void main(List<String> arguments) {
  try {
    MelosCommandRunner().run(arguments);
  } on MelosException catch (err) {
    logger.stderr(err.toString());
    exitCode = 1;
  } catch (err) {
    exitCode = 1;
    rethrow;
  }
}

import 'dart:io' show Platform;
import 'package:melos/src/command_runner.dart';

void main(List<String> arguments) {
  if (!Platform.script.toString().contains('.pub-cache')) {
    print('\n\n  >  USING LOCAL DEV COPY OF MELOS  <  \n\n');
  }
  MelosCommandRunner.instance.run(arguments);
}

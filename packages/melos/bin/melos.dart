import 'dart:io';

import 'package:cli_launcher/cli_launcher.dart';
import 'package:melos/src/command_runner.dart';

Future<void> main(List<String> arguments) async {
  // Bypass cli_launcher if --no-pub is specified to skip its automatic pub get
  if (arguments.contains('--no-pub')) {
    return melosEntryPoint(arguments, LaunchContext(directory: Directory.current));
  }
  
  return launchExecutable(
    arguments,
    LaunchConfig(
      name: ExecutableName('melos'),
      launchFromSelf: false,
      entrypoint: melosEntryPoint,
    ),
  );
}

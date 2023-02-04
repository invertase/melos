import 'package:cli_launcher/cli_launcher.dart';
import 'package:melos/src/command_runner.dart';

Future<void> main(List<String> arguments) async => launchExecutable(
      arguments,
      LaunchConfig(
        name: ExecutableName('melos'),
        launchFromSelf: false,
        entrypoint: melosEntryPoint,
      ),
    );

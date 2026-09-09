import 'package:cli_launcher/cli_launcher.dart';
import 'package:melos/src/command_runner.dart';
import 'package:melos/src/sdk_launcher.dart';

Future<void> main(List<String> arguments) async {
  if (await relaunchWithConfiguredSdk(arguments)) {
    return;
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

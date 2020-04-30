import 'package:melos_cli/melos_cli.dart';
import 'package:cli_util/cli_logging.dart';

main(List<String> arguments) {
  if (arguments.contains('-v')) {
    arguments.removeAt(arguments.indexOf('-v'));
    logger = new Logger.verbose();
  }
  commandRunner.run(arguments);
}

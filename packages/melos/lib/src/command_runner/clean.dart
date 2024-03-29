import '../commands/runner.dart';
import 'base.dart';

class CleanCommand extends MelosCommand {
  CleanCommand(super.config) {
    setupPackageFilterParser();
  }

  @override
  final String name = 'clean';

  @override
  final String description = 'Clean this workspace and all packages. '
      'This deletes the temporary pub & ide files such as ".packages" & '
      '".flutter-plugins". Supports all package filtering options.';

  @override
  Future<void> run() async {
    final melos = Melos(logger: logger, config: config);

    await melos.clean(
      global: global,
      packageFilters: parsePackageFilters(config.path),
    );
  }
}

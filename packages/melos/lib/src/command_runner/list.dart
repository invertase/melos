import '../commands/runner.dart';
import '../common/list_output_kind.dart';
import '../common/utils.dart';
import 'base.dart';

/// Command line options for commands that print a list of packages.
mixin PackageListOutputOptions on MelosCommand {
  void setupPackageListOutputParser() {
    argParser.addFlag(
      'long',
      abbr: 'l',
      negatable: false,
      help: 'Show extended information.',
    );
    argParser.addFlag(
      'parsable',
      abbr: 'p',
      negatable: false,
      help: 'Show parsable output instead of columnified view.',
    );
    argParser.addFlag(
      'relative',
      abbr: 'r',
      negatable: false,
      help:
          'When printing output, use package paths relative to the root of the '
          'workspace.',
    );
    argParser.addFlag(
      'json',
      negatable: false,
      help: 'Show information as a JSON array.',
    );
    argParser.addFlag(
      'graph',
      negatable: false,
      help: 'Show dependency graph as a JSON-formatted adjacency list.',
    );
    argParser.addFlag(
      'gviz',
      negatable: false,
      help: 'Show dependency graph in Graphviz DOT language.',
    );
    argParser.addFlag(
      'mermaid',
      negatable: false,
      help: 'Show dependency graph in Mermaid Diagram.',
    );
  }

  bool? get long => argResults!.optional('long') as bool?;

  bool? get relativePaths => argResults!.optional('relative') as bool?;

  /// The output format requested on the command line, or `null` when none was
  /// requested and the one configured in `command/list` should be used.
  ListOutputKind? get outputKind {
    if (argResults!['mermaid'] as bool) {
      return ListOutputKind.mermaid;
    }
    if (argResults!['gviz'] as bool) {
      return ListOutputKind.gviz;
    }
    if (argResults!['graph'] as bool) {
      return ListOutputKind.graph;
    }
    if (argResults!['json'] as bool) {
      return ListOutputKind.json;
    }
    if (argResults!['parsable'] as bool) {
      return ListOutputKind.parsable;
    }
    return null;
  }
}

class ListCommand extends MelosCommand with PackageListOutputOptions {
  ListCommand(super.config) {
    setupPackageFilterParser();
    setupPackageListOutputParser();
    argParser.addFlag(
      'cycles',
      negatable: false,
      help: 'Find cycles in package dependencies in the workspace.',
    );
  }

  @override
  final String name = 'list';

  @override
  final List<String> aliases = ['ls'];

  @override
  final String description =
      'List local packages in various output formats. Supports all package '
      'filtering options.';

  @override
  final String invocation = 'melos list';

  @override
  ListOutputKind? get outputKind =>
      argResults!['cycles'] as bool ? ListOutputKind.cycles : super.outputKind;

  @override
  Future<void> run() async {
    final melos = Melos(logger: logger, config: config);

    return melos.list(
      long: long,
      global: global,
      packageFilters: parsePackageFilters(config.path),
      relativePaths: relativePaths,
      kind: outputKind,
    );
  }
}

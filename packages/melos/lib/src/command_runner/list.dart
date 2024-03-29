import '../commands/runner.dart';
import 'base.dart';

class ListCommand extends MelosCommand {
  ListCommand(super.config) {
    setupPackageFilterParser();
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
  Future<void> run() async {
    final long = argResults!['long'] as bool;
    final parsable = argResults!['parsable'] as bool;
    final json = argResults!['json'] as bool;
    final relative = argResults!['relative'] as bool;
    final graph = argResults!['graph'] as bool;
    final gviz = argResults!['gviz'] as bool;
    final cycles = argResults!['cycles'] as bool;

    final melos = Melos(logger: logger, config: config);

    var kind = ListOutputKind.column;

    if (parsable) kind = ListOutputKind.parsable;
    if (json) kind = ListOutputKind.json;
    if (graph) kind = ListOutputKind.graph;
    if (gviz) kind = ListOutputKind.gviz;
    if (cycles) kind = ListOutputKind.cycles;

    return melos.list(
      long: long,
      global: global,
      packageFilters: parsePackageFilters(config.path),
      relativePaths: relative,
      kind: kind,
    );
  }
}

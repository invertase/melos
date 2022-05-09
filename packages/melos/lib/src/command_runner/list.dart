/*
 * Copyright (c) 2016-present Invertase Limited & Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this library except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

import '../commands/runner.dart';
import '../workspace_configs.dart';
import 'base.dart';

class ListCommand extends MelosCommand {
  ListCommand(MelosWorkspaceConfig config) : super(config) {
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
          'When printing output, use package paths relative to the root of the workspace.',
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
  }

  @override
  final String name = 'list';

  @override
  final List<String> aliases = ['ls'];

  @override
  final String description =
      'List local packages in various output formats. Supports all package filtering options.';

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

    final melos = Melos(logger: logger, config: config);

    var kind = ListOutputKind.column;

    if (parsable) kind = ListOutputKind.parsable;
    if (json) kind = ListOutputKind.json;
    if (graph) kind = ListOutputKind.graph;
    if (gviz) kind = ListOutputKind.gviz;

    return melos.list(
      long: long,
      global: global,
      filter: parsePackageFilter(config.path),
      relativePaths: relative,
      kind: kind,
    );
  }
}

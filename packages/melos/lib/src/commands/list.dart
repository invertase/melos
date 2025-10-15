part of 'runner.dart';

// TODO find better names
enum ListOutputKind { json, parsable, graph, gviz, mermaid, column, cycles }

mixin _ListMixin on _Melos {
  Future<void> list({
    GlobalOptions? global,
    bool long = false,
    bool relativePaths = false,
    PackageFilters? packageFilters,
    ListOutputKind kind = ListOutputKind.column,
  }) async {
    final workspace = await createWorkspace(
      global: global,
      packageFilters: packageFilters,
    );

    switch (kind) {
      case ListOutputKind.graph:
        return _listGraph(workspace);
      case ListOutputKind.parsable:
        return _listParsable(
          workspace,
          long: long,
          relativePaths: relativePaths,
        );
      case ListOutputKind.column:
        return _listColumn(
          workspace,
          long: long,
          relativePaths: relativePaths,
        );
      case ListOutputKind.json:
        return _listJson(
          workspace,
          relativePaths: relativePaths,
          long: long,
        );
      case ListOutputKind.gviz:
        return _listGviz(workspace);
      case ListOutputKind.mermaid:
        return _listMermaid(workspace);
      case ListOutputKind.cycles:
        return _listCyclesInDependencies(workspace);
    }
  }

  void _listGraph(MelosWorkspace workspace) {
    final jsonGraph = <String, List<String>>{};
    for (final package in workspace.filteredPackages.values) {
      jsonGraph[package.name] = package.allDependenciesInWorkspace.keys
          .toList();
    }

    const encoder = JsonEncoder.withIndent('  ');
    logger.stdout(encoder.convert(jsonGraph));
  }

  void _listColumn(
    MelosWorkspace workspace, {
    required bool long,
    required bool relativePaths,
  }) {
    if (workspace.filteredPackages.values.isEmpty) {
      logger.warning(
        'No packages were found with the current filters.',
        label: false,
      );
      logger.hint(
        'If this is unexpected, try running the command again with a reduced '
        'number of filters applied.',
      );
      return;
    }

    if (long) {
      final table = listAsPaddedTable(
        workspace.filteredPackages.values
            .map(
              (package) => [
                package.name,
                AnsiStyles.green(package.version.toString()),
                AnsiStyles.gray(printablePath(package.pathRelativeToWorkspace)),
                if (package.isPrivate) AnsiStyles.red('PRIVATE'),
              ],
            )
            .cast<List<String>>()
            .toList(),
      );
      logger.stdout(table);
      return;
    }

    for (final package in workspace.filteredPackages.values) {
      final output = relativePaths
          ? printablePath(package.pathRelativeToWorkspace)
          : package.name;
      logger.stdout(output);
    }
  }

  void _listParsable(
    MelosWorkspace workspace, {
    required bool relativePaths,
    required bool long,
  }) {
    for (final package in workspace.filteredPackages.values) {
      final packagePath = relativePaths
          ? printablePath(package.pathRelativeToWorkspace)
          : package.path;
      if (long) {
        logger.stdout(
          <Object>[
            packagePath,
            package.name,
            package.version,
            if (package.isPrivate) 'PRIVATE',
          ].join(':'),
        );
      } else {
        logger.stdout(packagePath);
      }
    }
  }

  void _listJson(
    MelosWorkspace workspace, {
    required bool relativePaths,
    required bool long,
  }) {
    final jsonArrayItems = <Map<String, Object?>>[];

    for (final package in workspace.filteredPackages.values) {
      final packagePath = relativePaths
          ? printablePath(package.pathRelativeToWorkspace)
          : package.path;

      final jsonObject = {
        'name': package.name,
        'version': package.version.toString(),
        'private': package.isPrivate,
        'location': packagePath,
        'type': package.type.index,
      };

      if (long) {
        jsonObject.addAll({
          'flutter_package': package.isFlutterPackage,
          'flutter_app': package.isFlutterApp,
          'flutter_plugin': package.isFlutterPlugin,
          'dependencies': package.allDependenciesInWorkspace.keys.toList(),
          'dependents': package.allDependentsInWorkspace.keys.toList(),
        });

        if (package.isFlutterApp) {
          jsonObject.addAll({
            'flutter_app_supports_android': package.flutterAppSupportsAndroid,
            'flutter_app_supports_linux': package.flutterAppSupportsLinux,
            'flutter_app_supports_macos': package.flutterAppSupportsMacos,
            'flutter_app_supports_ios': package.flutterAppSupportsIos,
            'flutter_app_supports_web': package.flutterAppSupportsWeb,
            'flutter_app_supports_windows': package.flutterAppSupportsWindows,
          });
        }

        if (package.isFlutterPlugin) {
          jsonObject.addAll({
            'flutter_plugin_supports_android':
                package.flutterPluginSupportsAndroid,
            'flutter_plugin_supports_linux': package.flutterPluginSupportsLinux,
            'flutter_plugin_supports_macos': package.flutterPluginSupportsMacos,
            'flutter_plugin_supports_ios': package.flutterPluginSupportsIos,
            'flutter_plugin_supports_web': package.flutterPluginSupportsWeb,
            'flutter_plugin_supports_windows':
                package.flutterPluginSupportsWindows,
          });
        }
      }

      jsonArrayItems.add(jsonObject);
    }

    const encoder = JsonEncoder.withIndent('  ');
    logger.stdout(encoder.convert(jsonArrayItems));
  }

  void _listGviz(MelosWorkspace workspace) {
    String toHex(int color) {
      final colorString = color.toRadixString(16);

      return [if (colorString.length == 1) '0', colorString].join();
    }

    String getColor(String name) {
      final random = Random(name.hashCode);

      final r = random.nextInt(256);
      final g = random.nextInt(256);
      final b = random.nextInt(256);

      return [
        '#',
        toHex(r),
        toHex(g),
        toHex(b),
      ].join();
    }

    final buffer = <String>[];

    buffer.add('digraph packages {');
    buffer.add('  size="10"; ratio=fill;');

    for (final package in workspace.filteredPackages.values) {
      buffer.add(
        '  ${package.name} [shape="box"; color="${getColor(package.name)}"];',
      );
    }

    for (final package in workspace.filteredPackages.values) {
      for (final dep in package.dependenciesInWorkspace.values) {
        buffer.add(
          '  ${package.name} -> ${dep.name} '
          '[style="filled"; color="${getColor(dep.name)}"];',
        );
      }

      for (final dep in package.devDependenciesInWorkspace.values) {
        buffer.add(
          '  ${package.name} -> ${dep.name} '
          '[style="dashed"; color="${getColor(dep.name)}"];',
        );
      }

      for (final dep in package.dependencyOverridesInWorkspace.values) {
        buffer.add(
          '  ${package.name} -> ${dep.name} '
          '[style="dotted"; color="${getColor(dep.name)}"];',
        );
      }
    }

    final groupedPackages = workspace.filteredPackages.values
        .fold<Map<String, List<Package>>>({}, (grouped, package) {
          final namespace = p.dirname(package.pathRelativeToWorkspace);

          grouped.putIfAbsent(namespace, () => []);
          grouped[namespace]!.add(package);

          return grouped;
        });

    groupedPackages.forEach((namespace, packagesInGroup) {
      buffer.add('  subgraph "cluster $namespace" {');
      buffer.add('    label="$namespace";');
      buffer.add('    color="${getColor(namespace)}";');

      for (final package in packagesInGroup) {
        buffer.add('    ${package.name};');
      }

      buffer.add('  }');
    });

    buffer.add('}');

    logger.stdout(buffer.join('\n'));
  }

  void _listMermaid(MelosWorkspace workspace) {
    String toHex(int color) {
      final colorString = color.toRadixString(16);

      return [if (colorString.length == 1) '0', colorString].join();
    }

    String getColor(String name) {
      final random = Random(name.hashCode);

      final r = random.nextInt(256);
      final g = random.nextInt(256);
      final b = random.nextInt(256);

      return [
        '#',
        toHex(r),
        toHex(g),
        toHex(b),
      ].join();
    }

    String sanitizeNodeName(String name) {
      // Mermaid requires node names to be valid identifiers
      // Replace special characters with underscores
      return name.replaceAll(RegExp('[^a-zA-Z0-9_]'), '_');
    }

    final buffer = <String>[];

    buffer.add('graph TD');

    // Add node definitions with colors
    for (final package in workspace.filteredPackages.values) {
      final sanitizedName = sanitizeNodeName(package.name);
      final color = getColor(package.name);
      buffer.add(
        '  $sanitizedName["${package.name}"]',
      );
      buffer.add(
        '  style $sanitizedName stroke:$color',
      );
    }

    // Add dependencies
    for (final package in workspace.filteredPackages.values) {
      final sanitizedPackageName = sanitizeNodeName(package.name);

      // Regular dependencies (solid arrows)
      for (final dep in package.dependenciesInWorkspace.values) {
        final sanitizedDepName = sanitizeNodeName(dep.name);
        buffer.add(
          '  $sanitizedPackageName --> $sanitizedDepName',
        );
      }

      // Dev dependencies (dashed arrows)
      for (final dep in package.devDependenciesInWorkspace.values) {
        final sanitizedDepName = sanitizeNodeName(dep.name);
        buffer.add(
          '  $sanitizedPackageName -.-> $sanitizedDepName',
        );
      }

      // Dependency overrides (dotted arrows)
      for (final dep in package.dependencyOverridesInWorkspace.values) {
        final sanitizedDepName = sanitizeNodeName(dep.name);
        buffer.add(
          '  $sanitizedPackageName -..-> $sanitizedDepName',
        );
      }
    }

    // Add subgraphs for package groupings
    final groupedPackages = workspace.filteredPackages.values
        .fold<Map<String, List<Package>>>({}, (grouped, package) {
          final namespace = p.dirname(package.pathRelativeToWorkspace);

          grouped.putIfAbsent(namespace, () => []);
          grouped[namespace]!.add(package);

          return grouped;
        });

    var subgraphIndex = 0;
    groupedPackages.forEach((namespace, packagesInGroup) {
      if (packagesInGroup.length > 1) {
        final sanitizedNamespace = sanitizeNodeName(namespace);
        buffer.add(
          '  subgraph $sanitizedNamespace$subgraphIndex ["$namespace"]',
        );

        for (final package in packagesInGroup) {
          final sanitizedName = sanitizeNodeName(package.name);
          buffer.add('    $sanitizedName');
        }

        buffer.add('  end');
        subgraphIndex++;
      }
    });

    logger.stdout(buffer.join('\n'));
  }

  Future<void> _listCyclesInDependencies(MelosWorkspace workspace) async {
    final cycles = findCyclicDependenciesInWorkspace(
      workspace.filteredPackages.values.toList(),
    );

    if (cycles.isEmpty) {
      logger.stdout('🎉 No cycles in dependencies found.');
    } else {
      logger.stdout('🚨 ${cycles.length} cycles in dependencies found:');
      for (final cycle in cycles) {
        logger.stdout(
          '[ ${cycle.map((package) => package.name).join(' -> ')} ]',
        );
      }
      exitCode = 1;
    }
  }
}

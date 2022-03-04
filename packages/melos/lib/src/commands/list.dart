part of 'runner.dart';

// TODO find better names
enum ListOutputKind { json, parsable, graph, gviz, column }

mixin _ListMixin on _Melos {
  Future<void> list({
    bool showPrivatePackages = false,
    bool long = false,
    bool relativePaths = false,
    PackageFilter? filter,
    ListOutputKind kind = ListOutputKind.column,
  }) async {
    final workspace = await createWorkspace(filter: filter);

    switch (kind) {
      case ListOutputKind.graph:
        return _listGraph(workspace, showPrivatePackages: showPrivatePackages);
      case ListOutputKind.parsable:
        return _listParsable(
          workspace,
          long: long,
          relativePaths: relativePaths,
          showPrivatePackages: showPrivatePackages,
        );
      case ListOutputKind.column:
        return _listColumn(
          workspace,
          long: long,
          showPrivatePackages: showPrivatePackages,
        );
      case ListOutputKind.json:
        return _listJson(
          workspace,
          showPrivatePackages: showPrivatePackages,
          relativePaths: relativePaths,
          long: long,
        );
      case ListOutputKind.gviz:
        return _listGviz(workspace);
    }
  }

  void _listGraph(
    MelosWorkspace workspace, {
    required bool showPrivatePackages,
  }) {
    final jsonGraph = <String, List<String>>{};
    for (final package in workspace.filteredPackages.values) {
      if (!showPrivatePackages && package.isPrivate) {
        continue;
      }
      jsonGraph[package.name] = package.dependenciesInWorkspace.keys.toList();
    }

    const encoder = JsonEncoder.withIndent('  ');
    logger?.stdout(encoder.convert(jsonGraph));
  }

  void _listColumn(
    MelosWorkspace workspace, {
    required bool showPrivatePackages,
    required bool long,
  }) {
    if (workspace.filteredPackages.values.isEmpty) {
      logger?.stdout(
        AnsiStyles.yellow(
          'No packages were found with the current filters.',
        ),
      );
      logger?.stdout(
        AnsiStyles.gray(
          'Hint: if this is unexpected, '
          'try running the command again with a reduced number of filters applied.',
        ),
      );
      return;
    }

    if (long) {
      final table = listAsPaddedTable(
        workspace.filteredPackages.values
            .where((package) => !package.isPrivate || showPrivatePackages)
            .map(
              (package) => [
                package.name,
                AnsiStyles.green((package.version).toString()),
                AnsiStyles.gray(package.pathRelativeToWorkspace),
                if (package.isPrivate) AnsiStyles.red('PRIVATE')
              ],
            )
            .cast<List<String>>()
            .toList(),
      );
      logger?.stdout(table);
      return;
    }

    for (final package in workspace.filteredPackages.values) {
      if (!showPrivatePackages && package.isPrivate) continue;
      logger?.stdout(package.name);
    }
  }

  void _listParsable(
    MelosWorkspace workspace, {
    required bool showPrivatePackages,
    required bool relativePaths,
    required bool long,
  }) {
    for (final package in workspace.filteredPackages.values) {
      if (package.isPrivate && !showPrivatePackages) continue;
      final packagePath =
          relativePaths ? package.pathRelativeToWorkspace : package.path;
      if (long) {
        logger?.stdout(
          <Object>[
            packagePath,
            package.name,
            package.version,
            if (package.isPrivate) 'PRIVATE',
          ].join(':'),
        );
      } else {
        logger?.stdout(packagePath);
      }
    }
  }

  void _listJson(
    MelosWorkspace workspace, {
    required bool showPrivatePackages,
    required bool relativePaths,
    required bool long,
  }) {
    final jsonArrayItems = <Map<String, Object?>>[];

    for (final package in workspace.filteredPackages.values) {
      if (!showPrivatePackages && package.isPrivate) continue;
      final packagePath =
          relativePaths ? package.pathRelativeToWorkspace : package.path;

      final jsonObject = {
        'name': package.name,
        'version': package.version.toString(),
        'private': package.isPrivate,
        'location': packagePath,
        'type': package.type.index
      };

      if (long) {
        jsonObject.addAll({
          'flutter_package': package.isFlutterPackage,
          'flutter_app': package.isFlutterApp,
          'flutter_plugin': package.isFlutterPlugin,
          'dependencies': package.dependenciesInWorkspace.keys.toList(),
          'dependents': package.dependentsInWorkspace.keys.toList(),
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
    logger?.stdout(encoder.convert(jsonArrayItems));
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
          '  ${package.name} -> ${dep.name} [style="filled"; color="${getColor(dep.name)}"];',
        );
      }

      for (final dep in package.devDependenciesInWorkspace.values) {
        buffer.add(
          '  ${package.name} -> ${dep.name} [style="dashed"; color="${getColor(dep.name)}"];',
        );
      }
    }

    final groupedPackages = workspace.filteredPackages.values
        .fold<Map<String, List<Package>>>({}, (grouped, package) {
      final namespace = dirname(package.pathRelativeToWorkspace);

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

    logger?.stdout(buffer.join('\n'));
  }
}

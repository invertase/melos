import 'package:cli_util/cli_logging.dart';
import 'package:collection/collection.dart' hide stronglyConnectedComponents;
import 'package:graphs/graphs.dart';

import '../package.dart';

/// Sorts [packages] in topological order so they can be published without
/// errors.
///
/// Packages with inter-dependencies cannot be topologically sorted and will
/// be sorted by name length. This is a heuristic to better handle cyclic
/// dependencies in federated plugins.
void sortPackagesForPublishing(List<Package> packages) {
  final packageNames = packages.map((package) => package.name).toList();
  final graph = <String, Iterable<String>>{
    for (final package in packages)
      package.name: [
        ...package.dependencies.where(packageNames.contains),
        ...package.devDependencies.where(packageNames.contains),
      ],
  };
  final ordered =
      stronglyConnectedComponents(graph.keys, (package) => graph[package]!)
          .expand(
            (component) => component.sortedByCompare(
              (package) => package.length,
              (a, b) => b - a,
            ),
          )
          .toList();

  packages.sort((a, b) {
    return ordered.indexOf(a.name).compareTo(ordered.indexOf(b.name));
  });
}

/// Sorts [packages] in layered topological order so on each layer packages
/// are not dependent from each other.
/// Check against cyclic dependencies should be done separately.
List<List<Package>> sortPackagesForExecution(List<Package> packages) {
  final packageNames = packages.map((package) => package.name).toList();
  final packageMap = {for (final package in packages) package.name: package};
  final graph = <String, Iterable<String>>{
    for (final package in packages)
      package.name: [
        ...package.dependencies.where(packageNames.contains),
        ...package.devDependencies.where(packageNames.contains),
      ],
  };
  return stronglyConnectedComponents(graph.keys, (package) => graph[package]!)
      .map(
        (sortedPackageNames) =>
            sortedPackageNames.map((e) => packageMap[e]!).toList(),
      )
      .toList();
}

/// Filters [packageLayers] to contain only [executablePackages].
/// Empty layers are dropped.
List<List<Package>> whereOnlyExecutablePackages(
  List<List<Package>> packageLayers,
  List<Package> executablePackages,
) {
  final executablePackageNames = executablePackages.map(
    (package) => package.name,
  );
  return packageLayers
      .map(
        (packageLayer) => packageLayer
            .where((package) => executablePackageNames.contains(package.name))
            .toList(growable: false),
      )
      .where((layer) => layer.isNotEmpty)
      .toList(growable: false);
}

/// Returns a list of dependency cycles between [packages], taking into
/// account only workspace dependencies.
///
/// All dependencies between packages in the workspace are considered, including
/// `dev_dependencies` and `dependency_overrides`.
List<List<Package>> findCyclicDependenciesInWorkspace(List<Package> packages) {
  return stronglyConnectedComponents(
    packages,
    (package) => package.allDependenciesInWorkspace.values,
  ).where((component) => component.length > 1).map((component) {
    try {
      topologicalSort(
        component,
        (package) => package.allDependenciesInWorkspace.values,
      );
    } on CycleException<Package> catch (error) {
      return error.cycle;
    }
    throw StateError('Expected a cycle to be found.');
  }).toList();
}

void printCyclesInDependencies(List<List<Package>> cycles, Logger logger) {
  logger.stdout('🚨 ${cycles.length} cycles in dependencies found:');
  for (final cycle in cycles) {
    logger.stdout(
      '[ ${cycle.map((package) => package.name).join(' -> ')} ]',
    );
  }
}

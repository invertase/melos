import 'package.dart';
import 'workspace.dart';

/// Determines transitive relations between packages.
///
/// The relations computed by this class are cached.
class PackageGraph {
  PackageGraph(this._workspace);

  final MelosWorkspace _workspace;

  bool _graphComputed = false;
  final _transitiveDependenciesByPackage = <MelosPackage, Set<MelosPackage>>{};
  final _transitiveDependentsByPackage = <MelosPackage, Set<MelosPackage>>{};

  /// Calculates the set of packages that are transitive dependencies of [root].
  Set<MelosPackage> transitiveDependenciesForPackage(
    MelosPackage root,
  ) {
    if (_transitiveDependenciesByPackage.containsKey(root)) {
      return _transitiveDependenciesByPackage[root];
    }

    final visited = _transitiveDependenciesByPackage[root] = <MelosPackage>{};
    for (final package in root.allDependenciesInWorkspace) {
      visited
        ..add(package)
        ..addAll(transitiveDependenciesForPackage(package));
    }
    return visited.toSet();
  }

  /// Calculates the set of packages that are transitive dependents of [root].
  Set<MelosPackage> transitiveDependentsForPackage(MelosPackage root) {
    _computeTransitiveDependents();
    return _transitiveDependentsByPackage[root];
  }

  /// Computes transitive dependents for each package in the workspace.
  void _computeTransitiveDependents() {
    if (_graphComputed) return;

    // First we need the transitive dependencies
    _workspace.allPackages.forEach(transitiveDependenciesForPackage);

    // Invert the dependendencies to create the dependents graph
    for (final package in _workspace.allPackages) {
      _transitiveDependentsByPackage[package] ??= {};

      for (final dependency in _transitiveDependenciesByPackage[package]) {
        if (!_transitiveDependentsByPackage.containsKey(dependency)) {
          _transitiveDependentsByPackage[dependency] = {};
        }
        _transitiveDependentsByPackage[dependency].add(package);
      }
    }

    _graphComputed = true;
  }
}

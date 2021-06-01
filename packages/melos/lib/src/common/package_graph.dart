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
      return _transitiveDependenciesByPackage[root]!;
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
    return _transitiveDependentsByPackage[root]!;
  }

  /// Computes transitive dependents for each package in the workspace.
  void _computeTransitiveDependents() {
    if (_graphComputed) return;

    // First we need the transitive dependencies
    _workspace.allPackages!.forEach(transitiveDependenciesForPackage);

    // Invert the dependendencies to create the dependents graph
    for (final package in _workspace.allPackages!) {
      _transitiveDependentsByPackage[package] ??= {};

      for (final dependency in _transitiveDependenciesByPackage[package]!) {
        _transitiveDependentsByPackage.putIfAbsent(dependency, () => {});
        _transitiveDependentsByPackage[dependency]!.add(package);
      }
    }

    _graphComputed = true;
  }
}

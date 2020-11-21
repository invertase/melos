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

import 'dart:async';
import 'dart:io';

import 'package:args/args.dart';
import 'package:glob/glob.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:pool/pool.dart';
import 'package:yamlicious/yamlicious.dart';

import '../pub/pub_deps_list.dart';
import 'git.dart';
import 'package.dart';
import 'utils.dart' as utils;
import 'workspace_config.dart';
import 'workspace_state.dart';

MelosWorkspace currentWorkspace;

class MelosWorkspace {
  final String _name;

  String get name => _name;

  final String _path;

  String get path => _path;

  Map<String, Set<String>> _cacheDependencyGraph;

  final MelosWorkspaceConfig _config;

  MelosWorkspaceConfig get config => _config;

  final MelosWorkspaceState _state;

  MelosWorkspaceState get state => _state;

  List<MelosPackage> _packages;

  List<MelosPackage> _packagesNoScope;

  List<MelosPackage> get packages => _packages;

  List<MelosPackage> get packagesNoScope => _packagesNoScope;

  MelosWorkspace._(this._name, this._path, this._config, this._state);

  bool get isFlutterWorkspace {
    return packages.firstWhere((package) => package.isFlutterPackage,
            orElse: () => null) !=
        null;
  }

  static Future<MelosWorkspace> fromDirectory(Directory directory,
      {@required ArgResults arguments}) async {
    final workspaceConfig = await MelosWorkspaceConfig.fromDirectory(directory);
    if (workspaceConfig == null) {
      return null;
    }

    final workspaceState = await MelosWorkspaceState.fromDirectory(directory);
    return MelosWorkspace._(workspaceConfig.name, workspaceConfig.path,
        workspaceConfig, workspaceState);
  }

  String get melosToolPath {
    return joinAll([path, '.melos_tool']);
  }

  Future<List<MelosPackage>> loadPackagesWithFilters(
      {List<String> scope,
      List<String> ignore,
      String since,
      List<String> dirExists,
      List<String> fileExists,
      bool skipPrivate,
      bool published}) async {
    if (_packages != null) return Future.value(_packages);
    final packageGlobs = _config.packages;

    var filterResult = Directory(_path)
        .list(recursive: true, followLinks: false)
        .where((file) {
      return file.path.endsWith('pubspec.yaml');
    }).where((file) {
      // Filter matching 'packages' config from melos.yaml
      // No 'package' glob patterns in 'melos.yaml' so skip all packages.
      if (packageGlobs.isEmpty) return false;
      final matchedPattern = packageGlobs.firstWhere((pattern) {
        return pattern.matches(file.path);
      }, orElse: () => null);
      return matchedPattern != null;
    }).asyncMap((entity) {
      // Convert into Package for further filtering
      return MelosPackage.fromPubspecPathAndWorkspace(entity, this);
    });

    if (ignore.isNotEmpty) {
      // Ignore packages filter.
      filterResult = filterResult.where((package) {
        final matchedPattern = ignore.firstWhere((pattern) {
          return Glob(pattern).matches(package.name);
        }, orElse: () => null);
        return matchedPattern == null;
      });
    }

    if (dirExists.isNotEmpty) {
      // Directory exists packages filter, multiple filters behaviour is 'AND'.
      filterResult = filterResult.where((package) {
        final dirExistsMatched = dirExists.where((dirExistsPath) {
          return Directory(join(package.path, dirExistsPath)).existsSync();
        });
        return dirExistsMatched.length == dirExists.length;
      });
    }

    if (fileExists.isNotEmpty) {
      // File exists packages filter.
      filterResult = filterResult.where((package) {
        final fileExistsMatched = fileExists.firstWhere((fileExistsPath) {
          // TODO(Salakar): Make replacer reusable, currently used in a few places.
          var _fileExistsPath =
              fileExistsPath.replaceAll('\$MELOS_PACKAGE_NAME', package.name);
          return File(join(package.path, _fileExistsPath)).existsSync();
        }, orElse: () => null);
        return fileExistsMatched != null;
      });
    }

    if (skipPrivate) {
      // Whether we should skip packages with 'publish_to: none' set.
      filterResult = filterResult.where((package) {
        return !package.isPrivate;
      });
    }

    _packages = await filterResult.toList();

    // --published / --no-published
    if (published != null) {
      var pool = Pool(10);
      var packagesFilteredWithPublishStatus = <MelosPackage>[];
      await pool.forEach<MelosPackage, void>(_packages, (package) {
        return package.getPublishedVersions().then((versions) async {
          var isOnPubRegistry = versions.contains(package.version);
          if (published == false && !isOnPubRegistry) {
            return packagesFilteredWithPublishStatus.add(package);
          }
          if (published == true && isOnPubRegistry) {
            return packagesFilteredWithPublishStatus.add(package);
          }
        });
      }).drain();
      _packages = packagesFilteredWithPublishStatus;
    }

    // --since
    if (since != null) {
      var pool = Pool(10);
      var packagesFilteredWithGitCommitsSince = <MelosPackage>[];
      await pool.forEach<MelosPackage, void>(_packages, (package) {
        return gitCommitsForPackage(package, since: since)
            .then((commits) async {
          if (commits.isNotEmpty) {
            packagesFilteredWithGitCommitsSince.add(package);
          }
        });
      }).drain();
      _packages = packagesFilteredWithGitCommitsSince;
    }

    _packages.sort((a, b) {
      return a.name.compareTo(b.name);
    });

    // We filter scopes last so we can keep a track of packages prior to scope filter,
    // this is used for melos version to bump dependant package versions without scope filtering them out.
    if (scope.isNotEmpty) {
      _packagesNoScope = List.from(_packages);
      // Scoped packages filter.
      _packages = _packages.where((package) {
        final matchedPattern = scope.firstWhere((pattern) {
          return Glob(pattern).matches(package.name);
        }, orElse: () => null);
        return matchedPattern != null;
      }).toList();
    } else {
      _packagesNoScope = _packages;
    }

    return _packages;
  }

  /// Builds a dependency graph of dependencies and their dependents in this workspace.
  Future<Map<String, Set<String>>> getDependencyGraph() async {
    if (_cacheDependencyGraph != null) {
      return _cacheDependencyGraph;
    }

    List<String> pubDepsExecArgs = ['--style=list', '--dev'];
    final pubListCommandOutput = await Process.run(
      isFlutterWorkspace
          ? 'flutter'
          : utils.isPubSubcommand()
              ? 'dart'
              : 'pub',
      isFlutterWorkspace
          ? ['pub', 'deps', '--', ...pubDepsExecArgs]
          : [if (utils.isPubSubcommand()) 'pub', 'deps', ...pubDepsExecArgs],
      runInShell: true,
      workingDirectory: melosToolPath,
    );

    final pubDepList = PubDepsList.parse(pubListCommandOutput.stdout as String);
    final allEntries = pubDepList.allEntries;
    final allEntriesMap = allEntries.map((entry, map) {
      return MapEntry(entry.name, map);
    });

    void addNestedEntries(Set entriesSet) {
      var countBefore = entriesSet.length;
      var entriesSetClone = Set.from(entriesSet);

      entriesSetClone.forEach((entryName) {
        var depsForEntry = allEntriesMap[entryName];
        if (depsForEntry != null && depsForEntry.isNotEmpty) {
          depsForEntry.forEach((dependentName, _) {
            entriesSet.add(dependentName);
          });
        }
      });

      if (countBefore != entriesSet.length) {
        addNestedEntries(entriesSet);
      }
    }

    Map<String, Set<String>> dependencyGraphFlat = {};

    allEntries.forEach((entry, dependencies) {
      var entriesSet = <String>{};
      if (dependencies.isNotEmpty) {
        dependencies.forEach((dependentName, _) {
          entriesSet.add(dependentName);
        });
      }
      addNestedEntries(entriesSet);
      dependencyGraphFlat[entry.name] = entriesSet;
    });

    _cacheDependencyGraph = dependencyGraphFlat;
    return dependencyGraphFlat;
  }

  /// Execute a command in the root of this workspace.
  Future<int> exec(List<String> execArgs, {bool onlyOutputOnError = false}) {
    final environment = {
      'MELOS_ROOT_PATH': path,
    };

    return utils.startProcess(execArgs,
        environment: environment,
        workingDirectory: path,
        onlyOutputOnError: onlyOutputOnError);
  }

  /// Execute a command in the .melos_tool directory of this workspace.
  Future<int> execInMelosToolPath(List<String> execArgs,
      {bool onlyOutputOnError = false}) {
    final environment = {
      'MELOS_ROOT_PATH': path,
    };

    return utils.startProcess(execArgs,
        environment: environment,
        workingDirectory: melosToolPath,
        onlyOutputOnError: onlyOutputOnError);
  }

  Future<void> linkPackages() async {
    await getDependencyGraph();
    await Future.forEach(packages, (MelosPackage package) {
      return package.linkPackages(this);
    });
  }

  void clean({bool cleanPackages = true}) {
    if (Directory(melosToolPath).existsSync()) {
      Directory(melosToolPath).deleteSync(recursive: true);
    }
    if (cleanPackages) {
      packages.forEach((MelosPackage package) {
        package.clean();
      });
    }
  }

  Future<void> generatePubspecFile() async {
    var workspacePubspec = {};
    var workspaceName = config.name ?? 'MelosWorkspace';

    workspacePubspec['name'] = workspaceName;
    workspacePubspec['version'] = config.version ?? '0.0.0';
    workspacePubspec['publish_to'] = 'none';
    workspacePubspec['dependencies'] = Map.from(config.dependencies);
    workspacePubspec['dev_dependencies'] = Map.from(config.devDependencies);
    workspacePubspec['dependency_overrides'] = {};
    workspacePubspec['environment'] = Map.from(config.environment);

    packages.forEach((MelosPackage plugin) {
      var pluginRelativePath = utils.relativePath(plugin.path, melosToolPath);
      workspacePubspec['dependencies'][plugin.name] = {
        'path': pluginRelativePath,
      };
      workspacePubspec['dependency_overrides'][plugin.name] = {
        'path': pluginRelativePath,
      };

      // TODO(salakar): this is a hacky work around for dev deps - look at using
      //                `pub cache add` etc and manually generating file:// links
      var devDependencies = plugin.devDependencies;
      plugin.devDependencies.keys.toSet().forEach((name) {
        var linkedPackageExists = packages.firstWhere((package) {
          return package.name == name;
        }, orElse: () {
          return null;
        });
        if (linkedPackageExists == null) {
          workspacePubspec['dev_dependencies'][name] = devDependencies[name];
        }
      });
    });

    var header = '# Generated file - do not modify or commit this file.';
    var pubspecYaml = '$header\n${toYamlString(workspacePubspec)}';

    await File(utils.pubspecPathForDirectory(Directory(melosToolPath)))
        .create(recursive: true);
    await File(utils.pubspecPathForDirectory(Directory(melosToolPath)))
        .writeAsString(pubspecYaml);
  }
}

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

import 'dart:io';

import 'package:yamlicious/yamlicious.dart';

import 'utils.dart';

var _header = '''# This file tracks workspace state.
# Used by Melos tooling to assess current state of the workspace and
# for package versioning.
#
# This file should be version controlled and should not be manually edited.
''';

// TODO MelosWorkspaceState currently not in use.
// TODO MelosWorkspaceState currently not in use.
// TODO MelosWorkspaceState currently not in use.
class MelosWorkspaceState {
  final File _stateFile;
  final Map _currentState;

  MelosWorkspaceState._(this._stateFile, this._currentState);

  String get gitSince {
    return this['git.since'] as String;
  }

  set gitSince(String commitSha) {
    this['git.since'] = commitSha;
  }

  T _get<T>(String key) {
    dynamic temp = _currentState;
    List<String> keys = key.split('.');
    for (var i = 0; i < keys.length; i++) {
      var key = keys[i];
      if (temp == null || !(temp is Map) || !(temp as Map).containsKey(key)) {
        return null;
      }
      temp = temp[key];
    }
    return temp as T;
  }

  void _set(String key, String value) {
    var i = 0;
    var keys = key.split('.');
    var len = keys.length - 1;
    var currentTarget = _currentState;

    while (i < len) {
      var key = keys[i++];
      if (currentTarget[key] == null || !(currentTarget[key] is Map)) {
        currentTarget[key] = {};
      }
      currentTarget = Map.from(currentTarget[key] as Map);
    }
    if (value == null) {
      currentTarget.remove(keys[i]);
    } else {
      currentTarget[keys[i]] = value;
    }

    _persistSync();
  }

  void _persistSync() {
    var pubspecYaml = '$_header\n${toYamlString(_currentState)}';
    if (!_stateFile.existsSync()) {
      _stateFile.createSync(recursive: true);
    }
    _stateFile.writeAsStringSync(pubspecYaml);
  }

  dynamic operator [](String field) => _get<String>(field);

  operator []=(String field, String value) => _set(field, value);

  static Future<MelosWorkspaceState> fromDirectory(Directory directory) async {
    final melosStatePath = melosStatePathForDirectory(directory);
    var stateContents = await loadYamlFile(melosStatePath);

    return MelosWorkspaceState._(
        File(melosStatePath), Map.from(stateContents ??= {}));
  }
}

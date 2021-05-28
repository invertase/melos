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

import 'workspace_script.dart';

List<String> _lifecycleScriptNames = [
  'postclean',
  'preversion',
  'postversion',
  'postbootstrap',
  'version',
];

/// A representation of a "scripts" configuration in a "melos.yaml" file.
class MelosWorkspaceScripts {
  MelosWorkspaceScripts(this._scriptsMapDefinition);

  final Map<String, Object?> _scriptsMapDefinition;

  /// Returns whether a script exists by name.
  bool exists(String name) {
    return _scriptsMapDefinition[name] != null;
  }

  /// Returns a list of script names.
  List<String> get names =>
      List<String>.from(_scriptsMapDefinition.keys)..sort();

  /// Returns a list of script names excluding lifecycle related scripts e.g. "postversion".
  List<String> get namesExcludingLifecycles =>
      List<String>.from(_scriptsMapDefinition.keys)
          .where((name) => !_lifecycleScriptNames.contains(name))
          .toList()
            ..sort();

  /// Get a MelosScript for a script by name.
  MelosScript? script(String name) {
    if (_scriptsMapDefinition[name] == null) {
      return null;
    }
    return MelosScript.fromDefinition(name, _scriptsMapDefinition[name]);
  }
}

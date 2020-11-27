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

class MelosWorkspaceScripts {
  final Map _scriptsMapDefinition;

  MelosWorkspaceScripts(this._scriptsMapDefinition);

  bool exists(String name) {
    return _scriptsMapDefinition[name] != null;
  }

  List<String> get names => List<String>.from(_scriptsMapDefinition.keys);

  MelosScript script(String name) {
    if (_scriptsMapDefinition[name] == null) {
      return null;
    }
    return MelosScript.fromDefinition(name, _scriptsMapDefinition[name]);
  }
}

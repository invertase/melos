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
import 'package:ansi_styles/ansi_styles.dart';

import 'logger.dart';
import 'utils.dart';

Map<String, dynamic> _validateSelectPackageOptions(
  String scriptName,
  Map<String, dynamic> selectPackageOptions,
) {
  Map<String, dynamic> result = {};

  List<String> _asStringList(String optionName, dynamic value) {
    if (value == null) return [];
    if (value is String) return [value];
    if (value is List) return List<String>.from(value);
    logger.stderr(AnsiStyles.red(
      'Select package option "$optionName" in script "$scriptName" is invalid, option should be either a string or a list of strings.',
    ));
    exit(1);
  }

  String _asString(String optionName, dynamic value) {
    if (value is String) return value;
    logger.stderr(AnsiStyles.red(
      'Select package option "$optionName" in script "$scriptName" is invalid, option should be a string value.',
    ));
    exit(1);
  }

  bool _asBool(String optionName, dynamic value) {
    if (value is bool) return value;
    logger.stderr(AnsiStyles.red(
      'Select package option "$optionName" in script "$scriptName" is invalid, option should be a bool value.',
    ));
    exit(1);
  }

  // String or List
  result[filterOptionScope] = _asStringList(
    filterOptionScope,
    selectPackageOptions[filterOptionScope],
  );
  result[filterOptionIgnore] = _asStringList(
    filterOptionIgnore,
    selectPackageOptions[filterOptionIgnore],
  );
  result[filterOptionDirExists] = _asStringList(
    filterOptionDirExists,
    selectPackageOptions[filterOptionDirExists],
  );
  result[filterOptionFileExists] = _asStringList(
    filterOptionFileExists,
    selectPackageOptions[filterOptionFileExists],
  );

  // String
  if (selectPackageOptions.containsKey(filterOptionSince)) {
    result[filterOptionSince] = _asString(
      filterOptionSince,
      selectPackageOptions[filterOptionSince],
    );
  }

  // bool
  if (selectPackageOptions.containsKey(filterOptionNoPrivate)) {
    result[filterOptionNoPrivate] = _asBool(
      filterOptionNoPrivate,
      selectPackageOptions[filterOptionNoPrivate],
    );
  }
  if (selectPackageOptions.containsKey(filterOptionPublished)) {
    result[filterOptionPublished] = _asBool(
      filterOptionPublished,
      selectPackageOptions[filterOptionPublished],
    );
  }

  return result;
}

class MelosScript {
  final String name;
  final String run;

  final String description;
  final Map<String, String> env;
  final Map<String, dynamic> selectPackageOptions;
  final bool shouldPromptForPackageSelection;

  MelosScript._(
    this.name,
    this.run, {
    this.description,
    this.env,
    this.selectPackageOptions,
    this.shouldPromptForPackageSelection = false,
  });

  static MelosScript fromDefinition(String name, dynamic definition) {
    if (definition is String) {
      return MelosScript._(
        name,
        definition,
        env: {},
        selectPackageOptions: _validateSelectPackageOptions(
          name,
          Map<String, dynamic>.from({}),
        ),
      );
    }

    if (!(definition is Map)) {
      throw Error();
    }

    Map definitionMap = definition as Map;
    String runCommand = definitionMap['run'] as String;
    if (runCommand == null) {
      // TODO better error message
      print('Script $name missing "run" property.');
      exit(1);
    }

    String description = definitionMap['description'] as String;
    Map<String, String> env = Map<String, String>.from(
      definitionMap['env'] as Map ?? {},
    );

    Map<String, dynamic> selectPackageOptions = _validateSelectPackageOptions(
      name,
      Map<String, dynamic>.from(
        definitionMap[scriptOptionSelectPackage] as Map ?? {},
      ),
    );

    return MelosScript._(
      name,
      definitionMap['run'] as String,
      description: description,
      env: env,
      selectPackageOptions: definitionMap.containsKey(scriptOptionSelectPackage)
          ? selectPackageOptions
          : null,
      shouldPromptForPackageSelection:
          definitionMap.containsKey(scriptOptionSelectPackage),
    );
  }
}

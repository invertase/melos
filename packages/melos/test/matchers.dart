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
 */

import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:melos/src/common/validation.dart';
import 'package:melos/src/package.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

Matcher packageNamed(dynamic matcher) => _PackageNameMatcher(matcher);

Matcher ignoringAnsii(Object? matcher) {
  return _IgnoringAnsii(matcher);
}

class _IgnoringAnsii extends CustomMatcher {
  _IgnoringAnsii(Object? matcher)
      : super('String ignoring Ansii', 'String', matcher);

  @override
  Object? featureValueOf(covariant String actual) {
    return actual.replaceAll(RegExp(r'\x1b\[[0-9;]*m'), '');
  }
}

class _PackageNameMatcher extends CustomMatcher {
  _PackageNameMatcher(dynamic matcher)
      : super('package named', 'name', matcher);

  @override
  Object? featureValueOf(Object? actual) => (actual! as Package).name;
}

const containsDuplicates = _ContainsDuplicatesMatcher();

class _ContainsDuplicatesMatcher extends Matcher {
  const _ContainsDuplicatesMatcher();

  @override
  Description describe(Description description) =>
      description.add('contains duplicates');

  @override
  bool matches(dynamic item, Map matchState) {
    if (item is Iterable) {
      final seen = <dynamic>{};
      for (final element in item) {
        if (seen.contains(element)) {
          return true;
        }
        seen.add(element);
      }

      return false;
    }
    return false;
  }
}

TypeMatcher<MelosConfigException> isMelosConfigException({
  Object? message,
}) {
  var matcher = isA<MelosConfigException>();

  if (message != null) {
    matcher = matcher.having((e) => e.message, 'message', message);
  }

  return matcher;
}

Matcher throwsMelosConfigException({Object? message}) {
  return throwsA(isMelosConfigException(message: message));
}

final Matcher fileExists = _FileExists();

class _FileExists extends Matcher {
  _FileExists();

  @override
  bool matches(Object? item, Map matchState) {
    final io.File file;
    if (item is File) {
      file = item;
    } else if (item is String) {
      file = io.File(p.normalize(item));
    } else {
      matchState['fileExists.invalidItem'] = true;
      return false;
    }

    if (file.existsSync()) {
      return true;
    }

    return false;
  }

  @override
  Description describe(Description description) =>
      description.add('file exists');

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (matchState['fileExists.invalidItem'] == true) {
      return mismatchDescription.add('is not a reference to a file');
    }

    return mismatchDescription.add('does not exist');
  }
}

Matcher fileContents(Object? matcher) => _FileContents(wrapMatcher(matcher));

class _FileContents extends Matcher {
  _FileContents(this._matcher);

  final Matcher _matcher;

  @override
  bool matches(Object? item, Map matchState) {
    final io.File file;
    if (item is File) {
      file = item;
    } else if (item is String) {
      file = io.File(p.normalize(item));
    } else {
      matchState['fileContents.invalidItem'] = true;
      return false;
    }

    if (!file.existsSync()) {
      matchState['fileContents.fileMissing'] = true;
      return false;
    }

    final contents = file.readAsStringSync();
    if (_matcher.matches(contents, matchState)) {
      return true;
    }
    addStateInfo(
      matchState,
      <String, String>{'fileContents.contents': contents},
    );
    return false;
  }

  @override
  Description describe(Description description) =>
      description.add('file with contents that ').addDescriptionOf(_matcher);

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (matchState['fileContents.invalidItem'] == true) {
      return mismatchDescription.add('is not a reference to a file');
    }

    if (matchState['fileContents.fileMissing'] == true) {
      return mismatchDescription.add('does not exist');
    }

    final contents = matchState['fileContents.contents'] as String;
    mismatchDescription.add('contains ').addDescriptionOf(contents);

    final innerDescription = StringDescription();
    _matcher.describeMismatch(
      contents,
      innerDescription,
      matchState['state'] as Map,
      verbose,
    );
    if (innerDescription.length > 0) {
      mismatchDescription.add(' which ').add(innerDescription.toString());
    }

    return mismatchDescription;
  }
}

Matcher yaml(Object? matcher) => _Yaml(wrapMatcher(matcher));

class _Yaml extends Matcher {
  _Yaml(this._matcher);

  final Matcher _matcher;

  @override
  bool matches(Object? item, Map matchState) {
    final String yamlString;
    if (item is String) {
      yamlString = item;
    } else {
      matchState['yaml.invalidItem'] = true;
      return false;
    }

    Object? value;
    try {
      value = loadYaml(yamlString);
    } catch (e, s) {
      matchState['yaml.error'] = e;
      matchState['yaml.stack'] = s;
      return false;
    }

    if (_matcher.matches(value, matchState)) {
      return true;
    }
    addStateInfo(
      matchState,
      <String, Object?>{'yaml.value': value},
    );
    return false;
  }

  @override
  Description describe(Description description) => description
      .add('is valid Yaml string with parsed value that ')
      .addDescriptionOf(_matcher);

  @override
  Description describeMismatch(
    Object? item,
    Description mismatchDescription,
    Map matchState,
    bool verbose,
  ) {
    if (matchState['yaml.invalidItem'] == true) {
      return mismatchDescription.add(' must be a String');
    }

    final error = matchState['yaml.error'] as Object?;
    final stack = matchState['yaml.stack'] as StackTrace?;
    if (error != null) {
      return mismatchDescription
          .add('could not be parsed: \n')
          .addDescriptionOf(error)
          .add('\n')
          .add(stack.toString());
    }

    final value = matchState['yaml.value'] as Object?;
    mismatchDescription.add('has the parsed value ').addDescriptionOf(value);

    final innerDescription = StringDescription();
    _matcher.describeMismatch(
      value,
      innerDescription,
      matchState['state'] as Map,
      verbose,
    );
    if (innerDescription.length > 0) {
      mismatchDescription.add(' which ').add(innerDescription.toString());
    }

    return mismatchDescription;
  }
}

Matcher yamlFile(Object? matcher) => fileContents(yaml(matcher));

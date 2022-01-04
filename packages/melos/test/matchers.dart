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

import 'package:melos/src/common/validation.dart';
import 'package:melos/src/package.dart';
import 'package:test/test.dart';

Matcher packageNamed(dynamic matcher) => _PackageNameMatcher(matcher);

Matcher equalsIgnoringAnsii(String str) {
  return _EqualsIgnoringAnsii(str);
}

class _EqualsIgnoringAnsii extends CustomMatcher {
  _EqualsIgnoringAnsii(String str)
      : super('String ignoring Ansii', 'String', str);

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

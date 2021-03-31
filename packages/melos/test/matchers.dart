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

import 'package:melos/src/common/package.dart';
import 'package:test/test.dart';

Matcher packageNamed(dynamic matcher) => _PackageNameMatcher(matcher);

class _PackageNameMatcher extends CustomMatcher {
  _PackageNameMatcher(matcher) : super('package named', 'name', matcher);
  @override
  Object featureValueOf(Object actual) => (actual as MelosPackage).name;
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

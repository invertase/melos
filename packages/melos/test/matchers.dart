// ignore_for_file: strict_raw_type

import 'dart:io' as io;

import 'package:ansi_styles/ansi_styles.dart';
import 'package:file/file.dart';
import 'package:melos/src/common/validation.dart';
import 'package:melos/src/package.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// Resolve flaky test in linux environments
Matcher ignoringDependencyMessages(String expected) {
  return predicate(
    (actual) {
      final normalizedActual = actual
          .toString()
          .split('\n')
          .where(
            (line) =>
                !line.startsWith('Resolving dependencies...') &&
                !line.startsWith('Downloading packages...') &&
                !line.startsWith('Got dependencies!') &&
                // Removes lines like "  pub_updater 0.4.0 (0.5.0 available)"
                !(line.startsWith('  ') && line.contains(' available)')) &&
                !line.contains(
                  'newer versions incompatible with dependency constraints',
                ) &&
                !line.startsWith(
                  'Try `dart pub outdated` for more information.',
                ),
          )
          .join('\n');
      return ignoringAnsii(expected).matches(normalizedActual, {});
    },
    'ignores dependency resolution messages',
  );
}

Matcher packageNamed(Object? matcher) => _PackageNameMatcher(matcher);

Matcher ignoringAnsii(Object? matcher) {
  return _IgnoringAnsii(matcher);
}

class _IgnoringAnsii extends CustomMatcher {
  _IgnoringAnsii(Object? matcher)
      : super('String ignoring Ansii', 'String', matcher);

  @override
  Object? featureValueOf(covariant String actual) {
    return AnsiStyles.strip(actual);
  }
}

class _PackageNameMatcher extends CustomMatcher {
  _PackageNameMatcher(Object? matcher)
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
  bool matches(Object? item, Map matchState) {
    if (item is Iterable) {
      final seen = <Object?>{};
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

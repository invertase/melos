import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:string_scanner/string_scanner.dart';

class PubDependencyList extends VersionedEntry {
  PubDependencyList._(
    super.other,
    this.sdks,
    this.sections,
  ) : super.copy();

  factory PubDependencyList.parse(String input) {
    final scanner = StringScanner(input);

    final sdks = <String, Version>{};

    void scanSdk() {
      scanner.expect(_sdkLine, name: 'SDK');
      final entry = VersionedEntry.fromMatch(scanner.lastMatch!);
      assert(!sdks.containsKey(entry.name));
      sdks[entry.name] = entry.version;
    }

    do {
      scanSdk();
    } while (scanner.matches(_sdkLine));

    scanner.expect(_sourcePackageLine, name: 'Source package');
    final sourcePackage = VersionedEntry.fromMatch(scanner.lastMatch!);

    final sections =
        <String, Map<VersionedEntry, Map<String, VersionConstraint>>>{};

    while (scanner.scan(_emptyLine)) {
      final section = _scanSection(scanner);
      sections[section.key] = section.value;
    }

    assert(scanner.isDone, '${scanner.position} of ${input.length}');

    return PubDependencyList._(
      sourcePackage,
      sdks,
      sections,
    );
  }

  static final _sdkLine = RegExp(r'(\w+) SDK (.+)\n');
  static final _sourcePackageLine = RegExp('($_pkgName) (.+)\n');
  static final _emptyLine = RegExp(r'\n');

  final Map<String, Version> sdks;
  final Map<String, Map<VersionedEntry, Map<String, VersionConstraint>>>
  sections;

  Map<VersionedEntry, Map<String, VersionConstraint>> get allEntries =>
      CombinedMapView(sections.values);
}

const _identifierRegExp = r'[a-zA-Z_]\w*';
const _pkgName = '$_identifierRegExp(?:\\.$_identifierRegExp)*';
final _sectionHeaderLine = RegExp(r'([a-zA-Z ]+):\n');
final _usageLine = RegExp('- ($_pkgName) (.+)\n');
final _depLine = RegExp('  - ($_pkgName) (.+)\n');

MapEntry<String, Map<VersionedEntry, Map<String, VersionConstraint>>>
_scanSection(StringScanner scanner) {
  scanner.expect(_sectionHeaderLine, name: 'section header');
  final header = scanner.lastMatch![1]!;

  final entries = <VersionedEntry, Map<String, VersionConstraint>>{};

  void scanUsage() {
    scanner.expect(_usageLine, name: 'dependency');
    final entry = VersionedEntry.fromMatch(scanner.lastMatch!);
    assert(!entries.containsKey(entry));

    final deps = entries[entry] = {};

    while (scanner.scan(_depLine)) {
      deps[scanner.lastMatch![1]!] = VersionConstraint.parse(
        scanner.lastMatch![2]!,
      );
    }
  }

  do {
    scanUsage();
  } while (scanner.matches(_usageLine));

  return MapEntry(header, entries);
}

@immutable
class VersionedEntry {
  const VersionedEntry(this.name, this.version);

  VersionedEntry.copy(VersionedEntry other)
    : name = other.name,
      version = other.version;

  factory VersionedEntry.fromMatch(Match match) {
    return VersionedEntry(
      match[1]!,
      Version.parse(match[2]!),
    );
  }

  final String name;
  final Version version;

  @override
  bool operator ==(Object other) =>
      other is VersionedEntry && name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => '$name @ $version';
}

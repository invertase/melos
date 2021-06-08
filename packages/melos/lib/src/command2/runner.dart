import '../common/workspace_config.dart';

// TODO find better names
enum ListOutputKind { json, parsable, graph, gviz, column }

class Melos {
  Future<void> run({
    String? scriptName,
    bool noSelect = false,
    PackageFilter? filter,
  }) async {}

  Future<void> bootstrap({
    PackageFilter? filter,
  }) async {}

  Future<void> clean({
    PackageFilter? filter,
  }) async {}

  Future<void> exec({
    PackageFilter? filter,
    int concurrency = 5,
    bool failFast = false,
  }) async {}

  Future<void> list({
    // all
    bool showPrivatePackages = false,
    // long
    bool verbose = false,
    PackageFilter? filter,
    ListOutputKind kind = ListOutputKind.column,
  }) async {}

  Future<void> publish({
    PackageFilter? filter,
    bool dryRun = true,
    bool gitTagVersion = true,
    // yes
    bool force = false,
  }) async {}

  Future<void> version({
    PackageFilter? filter,
    bool asPrerelease = false,
    bool asStableRelease = false,
    bool generateChangelog = true,
    bool updateDependentConstraints = true,
    bool updateDependentVersions = true,
    bool gitTag = true,
    String? message,
    bool force = false,
    // all
    bool showPrivatePackages = false,
    String? preId,
  }) async {}
}

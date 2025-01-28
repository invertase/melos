part of 'runner.dart';

mixin _InitMixin on _Melos {
  Future<void> init(
    String workspaceName, {
    required String directory,
    required List<String> packages,
    required bool useAppDir,
  }) async {
    late final String qualifiedWorkspaceName;
    if (workspaceName == '.') {
      qualifiedWorkspaceName = p.basename(Directory.current.absolute.path);
    } else {
      qualifiedWorkspaceName = workspaceName;
    }

    final isCurrentDir = directory == '.';
    final dir = Directory(directory);
    if (!isCurrentDir && dir.existsSync()) {
      throw StateError('Directory $directory already exists');
    } else {
      dir.createSync(recursive: true);
      Directory(p.join(dir.absolute.path, 'packages')).createSync();
      if (useAppDir) {
        Directory(p.join(dir.absolute.path, 'apps')).createSync();
      }
    }

    final dartVersion = utils.currentDartVersion('dart');
    final packages = await PackageMap.resolvePackages(
      workspacePath: dir.path,
      packages: [Glob('packages/**'), if (useAppDir) Glob('apps/**')],
      ignore: [],
      categories: {},
      logger: logger,
    );

    final pubspecYaml = <String, dynamic>{
      'name': qualifiedWorkspaceName,
      'environment': {
        'sdk': '>=$dartVersion <${dartVersion.major + 1}.0.0',
      },
      'dev_dependencies': {
        'melos': '^$melosVersion',
      },
      'workspace': packages.values.map((p) => p.path).toList(),
      'melos': '',
    };

    final pubspecFile = File(p.join(dir.absolute.path, 'pubspec.yaml'));

    pubspecFile.writeAsStringSync(
      // YamlEditor adds empty strings and empty lists to the pubspec.yaml file
      // if the value is empty. This is a workaround to remove them.
      (YamlEditor('')..update([], pubspecYaml))
          .toString()
          .replaceFirst('""', '')
          .replaceFirst('[]', ''),
    );

    logger.log(
      'Initialized Melos workspace in ${dir.path}.\n'
      'Run the following commands to bootstrap the workspace when you have created some packages and/or apps:\n'
      '${isCurrentDir ? '' : '  cd ${dir.path}\n'}'
      '  melos bootstrap',
    );
  }
}

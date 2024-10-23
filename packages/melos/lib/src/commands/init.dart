part of 'runner.dart';

mixin _InitMixin on _Melos {
  Future<void> init(
    String workspaceName, {
    required String directory,
    required List<String> packages,
    required String project,
    bool useRecommendedStructure = false,
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
    } else if (!isCurrentDir) {
      dir.createSync(recursive: true);
    }

    final dartVersion = utils.currentDartVersion('dart');
    final melosYaml = <String, dynamic>{
      'name': qualifiedWorkspaceName,
      if (useRecommendedStructure) 'packages': ['apps/**', 'packages/**'],
      if (packages.isNotEmpty) 'packages': packages,
    };
    final pubspecYaml = <String, dynamic>{
      'name': project,
      'environment': {
        'sdk': '>=$dartVersion <${dartVersion.major + 1}.0.0',
      },
      'dev_dependencies': {
        'melos': '^$melosVersion',
      },
    };

    final melosFile = File(p.join(dir.absolute.path, 'melos.yaml'));
    final pubspecFile = File(p.join(dir.absolute.path, 'pubspec.yaml'));

    melosFile.writeAsStringSync(
      (YamlEditor('')..update([], melosYaml)).toString(),
    );
    pubspecFile.writeAsStringSync(
      (YamlEditor('')..update([], pubspecYaml)).toString(),
    );

    logger.log(
      'Initialized Melos workspace in ${dir.path}\n'
      'Run the following commands to bootstrap the workspace:\n'
      '  cd ${dir.path}\n'
      '  melos bootstrap',
    );
  }
}

import 'dart:io';

import 'package:melos_cli/src/common/utils.dart' as utils;

class FlutterPlugin {
  Map _yamlContents;

  String _name;

  String get name => _name;

  String _path;

  String get path => _path;

  FlutterPlugin(this._name, this._path, this._yamlContents);

  static FlutterPlugin fromDirectory(Directory pluginDirectory) {
    String pluginYamlPath =
    utils.pluginYamlPathForPluginDirectory(pluginDirectory);
    Map yamlFileContents = utils.loadYamlFileSync(pluginYamlPath);
    String pluginName = yamlFileContents['name'];
    return FlutterPlugin(pluginName, pluginDirectory.path, yamlFileContents);
  }
}

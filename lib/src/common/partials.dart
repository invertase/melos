String workspaceImlContentRoot = '''
      <content url="file://\$MODULE_DIR\$/__pluginRelativePath__">
        <excludeFolder url="file://\$MODULE_DIR\$/__pluginRelativePath__/.dart_tool" />
        <excludeFolder url="file://\$MODULE_DIR\$/__pluginRelativePath__/.pub" />
        <excludeFolder url="file://\$MODULE_DIR\$/__pluginRelativePath__/build" />
        <excludeFolder url="file://\$MODULE_DIR\$/__pluginRelativePath__/android" />
        <excludeFolder url="file://\$MODULE_DIR\$/__pluginRelativePath__/ios" />
        <excludeFolder url="file://\$MODULE_DIR\$/__pluginRelativePath__/example" />
      </content>
''';

String workspacePubspec = '''
name: "workspace_stub"
description: "A stub workspace."
version: "0.0.1"
dependencies: 
  flutter: 
    sdk: "flutter"
environment: 
  flutter: ">=1.12.13+hotfix.4 <2.0.0"
  sdk: ">=2.0.0-dev.28.0 <3.0.0"
''';

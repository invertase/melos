#!/bin/bash

pub global activate --source=path .
echo "::add-path::$HOME/.pub-cache/bin"
echo "::add-path::$GITHUB_WORKSPACE/_flutter/.pub-cache/bin"
echo "::add-path::$GITHUB_WORKSPACE/_flutter/bin/cache/dart-sdk/bin"
# We need to manually pub get in melos to allow it to work first time
# as we're using melos source to bootstrap itself 
cd packages/melos && pub get && cd .. && cd ..

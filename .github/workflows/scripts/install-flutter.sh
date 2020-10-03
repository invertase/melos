#!/bin/bash

BRANCH=$1

git clone https://github.com/flutter/flutter.git --depth 1 -b $BRANCH _flutter
echo "::add-path::$GITHUB_WORKSPACE/_flutter/bin"
echo "::add-path::$HOME/.pub-cache/bin"
echo "::add-path::$GITHUB_WORKSPACE/_flutter/.pub-cache/bin"
echo "::add-path::$GITHUB_WORKSPACE/_flutter/bin/cache/dart-sdk/bin"
#!/bin/bash

BRANCH=$1

cd $HOME
git clone https://github.com/flutter/flutter.git --depth 1 -b $BRANCH _flutter
echo "::add-path::$HOME/_flutter/bin"
echo "::add-path::$HOME/.pub-cache/bin"
echo "::add-path::$HOME/_flutter/.pub-cache/bin"
echo "::add-path::$HOME/_flutter/bin/cache/dart-sdk/bin"
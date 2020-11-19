#!/bin/bash

BRANCH=$1

cd $HOME
git clone https://github.com/flutter/flutter.git --depth 1 -b $BRANCH _flutter
echo "$HOME/_flutter/bin" >> $GITHUB_PATH
echo "$HOME/.pub-cache/bin" >> $GITHUB_PATH
echo "$HOME/_flutter/.pub-cache/bin" >> $GITHUB_PATH
echo "$HOME/_flutter/bin/cache/dart-sdk/bin" >> $GITHUB_PATH
#!/bin/bash

pub global activate --source=path .
echo "::add-path::$HOME/.pub-cache/bin"
echo "::add-path::$GITHUB_WORKSPACE/_flutter/.pub-cache/bin"
echo "::add-path::$GITHUB_WORKSPACE/_flutter/bin/cache/dart-sdk/bin"

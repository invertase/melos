#!/bin/bash

dart pub global activate --source="path" . --executable="melos" --overwrite
melos bootstrap

#!/bin/bash

dart pub global activate --source="path" packages/melos --executable="melos" --overwrite
melos bootstrap

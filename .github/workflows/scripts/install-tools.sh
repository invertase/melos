#!/bin/bash

cd packages/melos
pub get
pub global activate --source=path .
cd ../..
melos bootstrap

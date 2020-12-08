---
title: Getting Started
description: Learn how to start using Melos in your project
---
# Getting Started

Melos requires a few one-off steps to be completed before you can start using it.

## Installation

Melos can be installed as a global package via [pub.dev](https://pub.dev/):

```bash
pub global activate melos
```

### Setup

To setup your project to use Melos, create a `melos.yaml` file in the root of the project.

> New project? Use `melos init` to initialize the file and an empty `packages` directory.

Within the `melos.yaml` file, add `name` and `packages` fields:

```yaml
name: my_project

packages:
  - packages/**
```

The `packages` list should contain paths to the individual packages within your project. Each path
can be defined using the [glob](https://docs.python.org/3/library/glob.html) pattern expansion format.

## Bootstrapping

Once installed & setup, Melos needs to be bootstrapped. Bootstrapping has 2 primary roles:

1. Installing all package dependencies (internally using `pub get`).
2. Locally linking any packages together.

### Why do I need to bootstrap?

In normal projects, packages can be linked by providing a `path` within the `pubspec.yaml`. This works for small
projects however presents a problem at scale. Packages cannot be published with a locally defined path, meaning
once you're ready to publish your packages you'll need to manually update all of the packages `pubspec.yaml` files
with the versions. If your packages are also tightly coupled (dependencies of each other), you'll also have to manually
check which versions should be updated. Even with a small number of packages this can become a long and error-prone task.

Melos solves this problem by overriding local files which the Dart analyzer uses to read packages from. If a local package
exists (defined in the `melos.yaml` file) and a different local package has it listed as a dependency, it will be linked
regardless of whether a version has been specified.

## Next steps

Once successfully bootstrapped, you can develop your packages side-by-side with changes to a single package immediately reflecting
across other dependant packages. 

Melos also provides other helpful features such as running scripts across all packages. For example, to create a script which analyzes
all packages source code for errors (using [tuneup.dart](https://pub.dev/packages/tuneup)), add a new `script` item in your `melos.yaml`:

```yaml
name: my_project

packages:
  - packages/**

scripts:
  analyze: melos exec -- pub global run tuneup check
```

Then execute the command by running `melos run analyze`.

If you're looking for some inspiration as to what scripts can help with, check out the
[FlutterFire repository](https://github.com/FirebaseExtended/flutterfire/blob/master/melos.yaml).
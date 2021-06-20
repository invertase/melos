---
title: Configure the melos command using the `melos.yaml` file
description: Let's see everything that the `melos.yaml` file can do.
---

Projects can optionally create a `melos.yaml` file at the project root. This file allows
configuring the behavior of the `melos` command, such as:

- changing the list of packages in the project
- defining scripts that later can be executed with `melos run`
- configure IDE-specific integrations

## `name` (required)

The name of this project, and is used for IDE documentation and logging purpose.

```yaml
name: My Awesome Project
```

## `packages` (required)

A list of paths on where to find the different packages in the project. The list can be
of specific paths or a [glob](https://docs.python.org/3/library/glob.html) pattern expansion format.

```yaml
packages:
  - packages/**
  - ext/some_other_package
```

## `ignore`

A list of paths to exclude from the previously defined `packages`.

The following will accept all packages in the `packages` folder but exclude their examples:

```yaml
packages:
  - packages/**

ignore:
  - packages/*/example
```

## `ide`: IDE documentation

## `commands`: Platform-specific overrides

## `scripts`

A list of commands that can be executed with `melos run`.

```yaml
scripts:
  # Defines a `melos run analyze` with no description
  analyze: dart analyze .
  # Defines a `melos run format` with a description
  format:
    run: dart format .
    description: "Formats dart files"
```

You can see the list of all scripts defined in a Melos project with the command `melos run`:

```
$ melos run
Select a script to run in this workspace:

1) analyze
2) format
    └> Formats dart files
```

See the documentation about [`melos run`]() for more information.

### Pre/Post Melos life-cycle hooks

On top of defining custom commands, you can also listen to Melos life-cycles
by using pre-defined script name.


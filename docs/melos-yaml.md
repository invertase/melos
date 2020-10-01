# melos.yaml

Every project requires a `melos.yaml` project in the root. The below outlines
all of the specific fields and their purpose.

## `name`

The name of this project, using for display purposes within IO environments and IDEs.

```yaml
name: My Awesome Project
```

## `versioning`

The versioning configuration used by Melos for some commands (such as `version`).

## `packages`

A list of local packages Melos will use to execute commands against.  The list can be
of specific paths or a [glob](https://docs.python.org/3/library/glob.html) pattern expansion format.

```yaml
packages:
  - packages/**
  - ext/some_other_package
```

## `scripts`

TODO


## `dev_dependencies`

TODO

## `environment`

TODO

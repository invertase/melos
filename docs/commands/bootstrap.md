---
title: Bootstrap Command
description: "Learn more about the `bootstrap` command in Melos."
---

# Bootstrap Command

This command initializes the workspace, links local packages together and installs remaining package dependencies.

```bash
melos bootstrap
# or
melos bs
```

Bootstrapping has two primary functions:

1. Installing all package dependencies (internally using `pub get`).
2. Locally linking any packages together via path dependency overrides _without having to edit your pubspec.yaml_.

## Why is bootstrapping required?

In normal projects, packages can be linked by providing a `path` within the `pubspec.yaml`. This works for small
projects however presents a problem at scale. Packages cannot be published with a locally defined path, meaning
once you're ready to publish your packages you'll need to manually update all of the packages `pubspec.yaml` files
with the versions. If your packages are also tightly coupled (dependencies of each other), you'll also have to manually
check which versions should be updated. Even with a small number of packages this can become a long and error-prone task.

Melos solves this problem by overriding local files which the Dart analyzer uses to read packages from. If a local package
exists (defined in the `melos.yaml` file) and a different local package has it listed as a dependency, it will be linked
regardless of whether a version has been specified.

### Benefits

- All local packages in the repository can be interlinked by Melos to point to their local directories rather than 'remote' _without pubspec.yaml modifications_.
  - **Example Scenario**: In a repository, package `A` depends on package `B`. Both packages `A` & `B` exist in the monorepo. However if you `pub get` inside package `A`, `pub` will retrieve package `B` from the pub.dev registry as it's unaware of `B` existing locally. However with Melos, it's aware that package `B` exists locally too so it will generate the various pub files to point to a relative path in the local repository.
    - If you wanted to use pub you could of course define a dependency override in the pubspec of package `A` that sets a path for package `B` but then you'd have to do this manually every time and then manually remove it again when you want to publish or even commit your changes. This doesn't scale well and doesn't help with making a repository contributor friendly. [FlutterFire](https://github.com/FirebaseExtended/flutterfire) for example has over 40 packages with various interlinking levels (try run `melos list --graph` to see it's local dependency graph).
      - This can also get phenomenally worse for example say if we introduce package `C` that package `B` depends on but package `C` then also depends on `A`.
- Interlinking highlights dart/analyzer issues early.
  - **Example Scenario**: Package `A` relies on package `B` from the same mono repo. Package `B` gets a minor API change. Via `pub get` on package `A` the dart analyzer and IDEs report no issues with the package as it installed package `B` from the remote pub registry and not local (which hasn't been published yet). With Melos, the dart analyzer / IDEs would highlight this issue immediately since local versions are used. The same applies for non-breaking deprecations, package `A` wouldn't show there was a deprecated API in use without being interlinked through Melos.
- Interlinking allows working on new, not yet published (or private) packages easily, without defining dependency overrides.

## Combining with filters

Bootstrap supports [all package filtering options](/filters), therefore if you wanted to you could bootstrap only a specific subset of your packages, for example:

```bash
# Only bootstrap packages that have
# changed since the main branch.
melos bootstrap --since="main"
```

## Adding a postboostrap lifecycle script

Melos supports various command lifecycle hooks that can be defined in your `melos.yaml`.

For example, if you needed to run something such as a build runner automatically after `melos bootstrap` is ran, you can add a
`postbootstrap` script:

```yaml
# melos.yaml
# ...
scripts:
  postbootstrap: dart pub run build_runner build
# ...
```

This is useful to ensure any local project requirements, such as generated files being built, are met when anyone is working on
your mono repo code base, e.g. external contributors.

<p align="center">
  <img src="https://static.invertase.io/assets/melos-logo.png" alt="Melos" /> <br /><br />
  <span>A tool for managing Dart projects with multiple packages.</span>
</p>

---

> ⚠️ Note: this project is still in active development.

---

- [About](#about)
- [Getting Started](#getting-started)
- [Commands](#commands)

---

## About

Splitting up large code bases into separate independently versioned packages
is extremely useful for code sharing. However, making changes across many
repositories is _messy_ and difficult to track, and testing across repositories
gets complicated really fast.

To solve these (and many other) problems, some projects will organize their
code bases into multi-package repositories (sometimes called [monorepos](https://en.wikipedia.org/wiki/Monorepo))

<p align="center">
  <img src="https://user-images.githubusercontent.com/5347038/82810703-0c28de80-9e87-11ea-888b-4b0b14c8e658.png" />
</p>

**Melos is a tool that optimizes the workflow around managing multi-package
repositories with git and Pub.**

### What does a Melos repo look like?

There's actually very little to it. You have a file structure that looks like this:

```
my-melos-repo/
  melos.yaml
  packages/
    package-1/
      pubspec.yaml
    package-2/
      pubspec.yaml
```

### What can Melos do?

The three primary commands in Melos are `melos bootstrap`, `melos version` & `melos publish`.

- `bootstrap` will link local packages in the repo together and install any remaining package dependencies.
- `version` bump packages versions (and their dependents) and generate changelogs using the conventional commits specification.
- `publish` will help publish any locally updated packages that are not yet on the Pub registry.

## Getting Started

Let's start by installing Melos as a global package via [Pub](https://pub.dev/).

```
pub global activate melos
```

### New Projects

> ⚠️ `init` support is still a work in progress

To initialize a new Melos project run the following:

```
mkdir my-melos-repo && cd $_
melos init
```

This will create a `melos.yaml` configuration file as well as a `packages` folder, so your folder should now look like this:

```
my-melos-repo/
  packages/
  melos.yaml
```

### Existing Projects

To use Melos in an existing monorepo create a `melos.yaml` file in the root ofr your project.

**Sample file**:

```yaml
name: flutterfire

packages:
  - packages/**

scripts:
  analyze: melos exec -- pub global run tuneup check
  postbootstrap: tuneup --version || pub global activate tuneup
  postclean: melos exec -- rm -rf ./build ./android/.gradle ./ios/.symlinks ./ios/Pods ./android/.idea ./.idea

dev_dependencies:
  pedantic: ^1.8.0
```

### Commands

Full commands list and args can be viewed by running `melos --help`.

---

#### `bootstrap`

> Initialize the workspace, link local packages together and install remaining package dependencies.

Supports all package filtering options.

**Example:**

```
melos bootstrap --ignore="*example*"
```

**Output:**

```
$ melos bootstrap
   └> /Users/mike/Documents/Projects/Flutter/ff_internal

Bootstrapping project...               SUCCESS
Linking project packages...            SUCCESS

Packages:
  • cloud_firestore
    └> ./packages/cloud_firestore/cloud_firestore
  • cloud_firestore_platform_interface
    └> ./packages/cloud_firestore/cloud_firestore_platform_interface
  • cloud_firestore_web
    └> ./packages/cloud_firestore/cloud_firestore_web
  • cloud_functions
    └> ./packages/cloud_functions/cloud_functions
  • cloud_functions_example

...

 -> 39 plugins bootstrapped
```

---

#### `clean`

> Clean this workspace and all packages. This deletes the temporary pub files such as ".packages" & ".flutter-plugins"

**Example:**

```
melos clean
```

---

#### `exec`

> Run a script by name defined in the workspace `melos.yaml` config file.

**Example:** Running `tuneup` analyzer in all packages

```
melos exec -- pub global run tuneup check
```

**Output:**

```
$ melos exec --
   └> pub global run tuneup check
       └> RUNNING (in 39 packages)

[cloud_firestore]: Checking project cloud_firestore...
[cloud_firestore_platform_interface]: Checking project cloud_firestore_platform_interface...
[cloud_functions_example]: Checking project cloud_functions_example...
[cloud_firestore_web]: Checking project cloud_firestore_web...
[cloud_functions]: Checking project cloud_functions...
...
```

---

#### `run`

> Execute an arbitrary command in each package.

**Example:** Running a script named `analyze` that is defined in `melos.yaml`

```
melos run analyze
```

**`melos.yaml`**:

```yaml
name: flutterfire
packages:
  - packages/**
scripts:
  analyze: melos exec -- pub global run tuneup check
  # ...
```

**Output:**

```
$ melos run analyze
   └> melos exec -- pub global run tuneup check
       └> RUNNING

$ melos exec --
   └> pub global run tuneup check
       └> RUNNING (in 39 packages)

[cloud_firestore]: Checking project cloud_firestore...
[cloud_functions_example]: Checking project cloud_functions_example...
[cloud_firestore_platform_interface]: Checking project cloud_firestore_platform_interface...
[cloud_firestore_web]: Checking project cloud_firestore_web...
[cloud_functions]: Checking project cloud_functions...

...
```

---

## Lerna

This project is heavily inspired by [Lerna](https://lerna.js.org/).

## README Badge

Using Melos? Add a README badge to show it off:

[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)

```markdown
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)
```

## License

- See [LICENSE](/LICENSE)

---

<p>
  <img align="left" width="75px" src="https://static.invertase.io/assets/invertase-logo-small.png">
  <p align="left">
    Built and maintained with 💛 by <a href="https://invertase.io">Invertase</a>.
  </p>
  <p align="left">
    <a href="https://invertase.link/discord"><img src="https://img.shields.io/discord/295953187817521152.svg?style=flat-square&colorA=7289da&label=Chat%20on%20Discord" alt="Chat on Discord"></a>
    <a href="https://twitter.com/invertaseio"><img src="https://img.shields.io/twitter/follow/invertaseio.svg?style=flat-square&colorA=1da1f2&colorB=&label=Follow%20on%20Twitter" alt="Follow on Twitter"></a>
  </p>
</p>

---

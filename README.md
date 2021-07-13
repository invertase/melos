<p align="center">
  <img src="https://static.invertase.io/assets/melos-logo.png" alt="Melos" /> <br /><br />
  <span>A tool for managing Dart projects with multiple packages, inspired by <a href="https://lerna.js.org">Lerna</a>.</span>
</p>

<p align="center">
  <a href="https://github.com/invertase/melos#readme-badge"><img src="https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square" alt="Melos" /></a>
  <a href="https://docs.page"><img src="https://img.shields.io/badge/powered%20by-docs.page-34C4AC.svg?style=flat-square" alt="docs.page" /></a>
</p>


<p align="center">
  <a href="https://melos.invertase.dev">Documentation</a> &bull; 
  <a href="https://github.com/invertase/melos/blob/master/LICENSE">License</a>
</p>

## Install

```bash
dart pub global activate melos
```

### About 

Splitting up large code bases into separate independently versioned packages is extremely useful for code sharing. However, making changes across many repositories is messy and difficult to track, and testing across repositories gets complicated really fast.

To solve these (and many other) problems, some projects will organize their code bases into multi-package repositories (sometimes called [monorepos](https://en.wikipedia.org/wiki/Monorepohttps://en.wikipedia.org/wiki/Monorepo)).

**Melos is a tool that optimizes the workflow around managing multi-package repositories with git and Pub.**

### What can Melos do? 

- 🔗 Link local packages in your workspace together without adding dependency overrides.
- 📦 Automatically version, create changelogs and publish your packages using [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/).
- 📜 Pre-define advanced custom scripts for your workspace in your melos.yaml configuration to use via `melos run [scriptName]`. Anyone contributing to your workspace can just run melos run to be prompted to select a script from a list with descriptions of each script.
  - Scripts can even [prompt to select a package](https://github.com/invertase/melos/pull/34) to run against with pre-defined filters.
- ⚡ Execute commands across your packages easily with melos exec -- command here with additional concurrency and fail-fast options.
  - [Environment variables](https://github.com/invertase/melos/issues/3) containing various information about the current package and the workspace are available in each execution.
  - Can be combined with all package filters.
- 🎯 Many advanced package filtering options allowing you to target specific packages or groups of packages in your workspace.
- ♨️ Advanced support for IntelliJ IDEs with automatic creation of [run configurations for workspace defined scripts and more](https://github.com/invertase/melos/issues/9) on workspace boostrap.
  - Vscode code doesn't require advanced integration to work.
## Local development setup

To setup and use this melos mono repo locally for the purposes of contributing, clone it and run the following commands from the root of the repository:

```bash
# Remove previous instances of melos:
dart pub global deactivate melos

# Activate 'melos' from path:
dart pub global activate --source="path" . --executable="melos"

# Confirm you now using a local development version:
melos --help
# You should now see a banner printed at the top of the help output similar to:
# ---------------------------------------------------------
# | You are running a local development version of melos. |
# ---------------------------------------------------------
```

## README Badge

Using Melos? Add a README badge to show it off:

[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)

```markdown
[![melos](https://img.shields.io/badge/maintained%20with-melos-f700ff.svg?style=flat-square)](https://github.com/invertase/melos)
```

---

<p align="center">
  <a href="https://invertase.io/?utm_source=readme&utm_medium=footer&utm_campaign=melos">
    <img width="75px" src="https://static.invertase.io/assets/invertase/invertase-rounded-avatar.png">
  </a>
  <p align="center">
    Built and maintained by <a href="https://invertase.io/?utm_source=readme&utm_medium=footer&utm_campaign=melos">Invertase</a>.
  </p>
</p>

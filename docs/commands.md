---
title: Commands
description: Descriptions and examples of the available Melos CLI commands
---
# Commands

Commands can be run from the root of a project using Melos.

## bootstrap (bs)

Bootstraps the project by installing and linking project dependencies.

```bash
melos bootstrap
melos bs
```

Packages defined in the `melos.yaml` `packages` field will be locally linked whilst other dependencies
will be automatically installed via `flutter pub get`.

## clean

Cleans up the current project workspace.

```bash
melos clean
```

Deletes any temporary pub related files and build artifacts (such as iOS Pods, Android builds etc).

This command is useful for when you feel something within your project is being cached and want to start fresh. Once
executed, you'll need to rerun the `bootstrap` command again for Melos to work.

## exec

Execute an arbitrary command in each package. 

```bash
melos exec
# e.g. melos exec -- pub global run tuneup check
```

### concurrency (-c)

Defines the max concurrency value of how many packages will execute the command in at any one time. Defaults to `5`.

```bash
# Set a 1 concurrency
melos exec -c 1 -- pub global run tuneup check
```

### --fail-fast

Whether exec should fail fast and not execute the script in further packages if the script fails in a individual package.
Defaults to `false`.

```bash
# Fail fast
melos exec --fail-fast -- pub global run tuneup check
```

## list

List information about the local packages.

```bash
melos list
```

### --long (-l)

Show extended/verbose information. Defaults to `false`.

```bash
melos list --long
melos list -l
```

### --all (-a)

Show private packages that are hidden by default. Defaults to `false`.

```bash
melos list --all
melos list -a
```

### --parsable (-p)

Show parsable output instead of columnified view. Defaults to `false`.

```bash
melos list --parsable
melos list -p
```

### --json

Show information as a JSON array. Defaults to `false`.

```bash
melos list --json
```

### --graph

Show dependency graph as a JSON-formatted adjacency list. Defaults to `false`.

### --gviz

Show dependency graph in Graphviz DOT language. Defaults to `false`.

```bash
melos list --graph
```

## publish

Publish any unpublished packages or package versions in your repository to pub.dev. `dry-run` is enabled by default.

```bash
melos publish
```

### --dry-run

Flags whether or not to publish the packages as a dry run (validate but do not publish). Defaults to `true`.

```bash
# Publish packages with dry run
melos publish --dry-run

# Publish packages without dry run
melos publish --no-dry-run
```

Use `--no-dry-run` to disable.

## run

Run a script by name defined in the workspace `melos.yaml` config file.

```bash
melos run <name>
```

## init

Initializes Melos in a project.

```bash
melos init
```

A `melos.yaml` file and empty `packages/` directory will be generated.

## version

Automatically version and generate changelogs for all packages. Supports all Melos filtering flags.

```bash
melos version
```

> To learn more, visit the [Automated Releases](automated-releases.md) documentation.

### --prerelease (-p)

Version any packages with changes as a prerelease. Cannot be combined with graduate flag. Defaults to `false`.

```bash
melos version --prerelease
melos version -p
```

### --graduate (-g)

Graduate current prerelease versioned packages to stable versions, e.g. "0.10.0-dev.1" becomes "0.10.0". Cannot be combined with prerelease flag. Defaults to `false`.

```bash
melos version --graduate
melos version -g
```

### --changelog (-c)

Update CHANGELOG.md files (based on conventional commit messages). Defaults to `true`.

```bash
melos version --changelog
melos version -c
```

Use `--no-changelog` to disable.

### --git-tag-version (-t)

Update CHANGELOG.md files (based on conventional commit messages). Defaults to `true`.

```bash
melos version --git-tag-version
melos version -t
```

Use `--no-git-tag-version` to disable.

## Global options

Each Melos command can be used alongside the following global commands:

### --help (-h)

Prints usage information about a command.

```bash
melos --help
melos bootstrap -h
```

### --verbose (-v)

Enable verbose logging. Defaults to `false`.

```bash
melos bootstrap -v
```

### --no-private

Exclude private packages (`publish_to: none`). They are included by default.

```bash
melos bootstrap --no-private
```

### --published

Filter packages where the current local package version exists on pub.dev.

```bash
melos bootstrap --no-private
```

Use `--no-published` to filter packages that have not had their current version published yet.

### --scope

Include only packages with names matching the given glob. This option can be repeated.

```bash
# Run `flutter build ios` on all packages with "example" in the package name
melos exec --scope="*example*" -- flutter build ios
```

### --ignore

Exclude packages with names matching the given glob. This option can be repeated.

```bash
# Run `flutter build ios` on all packages but ignore those whose packages names contain "internal"
melos exec --ignore="*internal*" -- flutter build ios
```

### --since

Only include packages that have been changed since the specified `ref`, e.g. a commit sha or git tag.

```bash
# Run `flutter build ios` on all packages but ignore those whose packages names contain "internal"
melos version --since=<commit hash>
```

### --dir-exists

Include only packages where a specific directory exists inside the package.

```bash
# Only bootstrap packages with an example directory
melos bootstrap --dir-exists="example"
```

### --file-exists

Include only packages where a specific file exists in the package.

```bash
# Only bootstrap packages with an README.md file
melos bootstrap --file-exists="README.md"
```

### --flutter

Filter packages where the package depends on the Flutter SDK.

```bash
melos exec --flutter -- flutter test
```

Use `--no-flutter` to filter packages that do not depend on the Flutter SDK.

### --depends-on

Include only packages that depend on specific dependencies.

```bash
melos exec --depends-on="flutter" --depends-on="firebase_core" -- flutter test
```
Use `--no-depends-on` to filter packages that do not depend on the given dependencies.

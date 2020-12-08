---
title: Automated Releases
description: Automate your workflow by versioning and publishing packages with Melos
---

# Automated Releases

Melos is able to automatically version, generate changelogs and publish to [pub.dev](https://pub.dev)
automatically. It's also intelligent enough to detect any package dependencies which require a new
version too.

Your Git project must be using [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/),
a widely used specification for commit messages which are readable by humans and machines. Melos parses
messages and detects exactly what sort of version upgrade is required.

### Not using Conventional Commits?

If an existing Git project is already established and does not use Conventional Commits, it is still
possible to adopt the convention and use Melos for future releases.

## Versioning

TODO:
- Scoping
- Major/minor/patches
- build versions
- dependency versioning
- bad commit messages?

## Publishing

To publish packages on [pub.dev](https://pub.dev) you must:

1. Have permission to publish all of the packages.
2. Be on a machine which is authenticated with Pub (read: not possible to publish via CIs).

> Internally, Melos uses `pub publish` to publish the packages.

Once you have [versioned](#versioning) your packages, run the publish command to check everything is good to go:

```dart
melos publish
```

By default, a dry-run is performed (nothing will be published).

Once satisfied with your pending releases, release them to [pub.dev](https://pub.dev):

```dart
melos publish --no-dry-run
```
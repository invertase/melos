---
name: melos-versioning
description: >-
  Use when versioning, generating changelogs or publishing packages with
  Melos: `melos version`, `melos publish`, Conventional Commits, build
  numbers, the `command/version` and `command/publish` configuration, fixed
  (lockstep) versioning, git tags, hot-fix releases and `melos cherry-pick`.
  Covers Melos 8.x.
---

# Melos versioning and publishing

`melos version` bumps package versions, writes changelogs, commits and tags.
`melos publish` publishes to pub.dev. Both support all package filters.

## Guidelines

- Never edit `version:` in a `pubspec.yaml` or a `CHANGELOG.md` by hand for
  a release. Let `melos version` do it, so that the tag, the changelog and the
  version stay consistent.
- Write Conventional Commits. Only `feat`, `fix`, `bug`, `perf`, `refactor`
  and `revert` trigger a release; `docs` is listed in the changelog but does
  not trigger one; `chore`, `ci`, `test` and others are ignored. A `!` after
  the type or a `BREAKING CHANGE:` footer causes a major bump.
- Commits are attributed to a package when they touch files inside its
  directory. Changes outside the packages, such as to the root
  `pubspec.yaml`, release nothing.
- `melos version` finds the commits since the latest release tag of the
  package, `<package>-v<version>` (plain `v<version>` for the root package
  and in fixed mode with `workspaceTag`). The tag of the current version is
  used when it exists, otherwise the highest existing tag, and without any
  tag the whole history. Keep the release tags reachable from the branch.
- Private packages (`publish_to: none`) are skipped unless `--all` is passed
  or `versionPrivatePackages: true` is configured. Applications need that.
- Always run `melos publish` first, it is a dry run by default. Publish for
  real with `melos publish --no-dry-run`.
- On CI, add `--yes` to skip the confirmation prompts, and push with
  `git push --follow-tags` afterwards.
- `melos version` runs `git pull --tags -f` first, which also merges the
  upstream of the branch. On a branch without an upstream, push it with
  `--set-upstream` or set `fetchTags: false`.
- Restrict releases to one branch with `command/version/branch: main`.

## Version bumps

| Change | `>= 1.0.0` | `< 1.0.0` |
| --- | --- | --- |
| breaking | major, `1.2.3` to `2.0.0` | minor, `0.1.2` to `0.2.0` |
| `feat` | minor, `1.2.3` to `1.3.0` | patch, `0.1.2` to `0.1.3` |
| other | patch, `1.2.3` to `1.2.4` | patch, `0.1.2` to `0.1.3` |

An integer build number is kept and incremented on every bump, so `1.2.3+45`
becomes `1.3.0+46`. Non-integer build metadata is dropped.

## Commands

```bash
melos version                              # Automatic, from Conventional Commits
melos version --yes                        # No confirmation prompt (CI)
melos version --prerelease --preid=beta    # 1.1.0-beta.0 style prereleases
melos version --graduate                   # 1.1.0-beta.3 to 1.1.0
melos version --all                        # Also version private packages
melos version --release-url                # Print prefilled release page links
melos version --no-git-tag-version         # Commit but do not tag
melos version --no-git-commit-version      # Neither commit nor tag
melos version --no-changelog
melos version --no-dependent-versions      # Do not patch-bump dependents
melos version --smart-dependents           # Only bump dependents whose constraints need it
melos version --group-commits              # Group changelog entries by type
melos version -m "chore(release): publish {new_package_versions}"

# Manual versioning, mixable with automatic versioning of the other packages
melos version my_package minor
melos version my_package 2.0.0
melos version -V my_package:patch -V other_package:1.0.0
melos version --ignore '*' -V my_package:major   # Only the manual one

melos publish                              # Dry run
melos publish --no-dry-run --yes           # Publish
melos publish --no-dry-run --git-tag-version   # Also create missing tags
melos publish --no-dry-run --server https://pub.example.dev
```

The first release of a repository that did not use Conventional Commits
before should be a manual version, so that the bump covers the unparsable
commits.

## Dependents

When a package is versioned, the constraints on it in the other workspace
packages are updated (`--no-dependent-constraints` disables it) and those
dependents get a patch bump with a changelog entry
(`--no-dependent-versions` disables it). `smartDependents: true` skips
dependents whose constraint already allows the new version. Dependents are
not filtered by the package filters.

## Configuration

```yaml
melos:
  repository: https://github.com/org/repo   # Needed for commit links
  command:
    version:
      branch: main                 # Refuse to version on other branches
      mode: independent            # or `fixed` for lockstep versioning
      workspaceTag: false          # Single v1.2.3 tag, fixed mode only
      linkToCommits: true          # Default when repository is set
      includeScopes: true
      includeCommitId: false
      workspaceChangelog: true     # Also write CHANGELOG.md in the root
      updateGitTagRefs: false      # Bump `ref:` of git dependencies on packages
      smartDependents: false
      releaseUrl: false
      fetchTags: true
      versionPrivatePackages: false
      message: |
        chore(release): publish packages

        {new_package_versions}
      changelogFormat:
        includeDate: false
        groupByType: false
      changelogCommitBodies:
        include: false
        onlyBreaking: true
      changelogs:                  # Extra aggregate changelogs
        - path: FOO_CHANGELOG.md
          description: Changes to the foo packages.
          packageFilters:
            scope: foo_*
      hooks:
        preCommit: dart run tool/sync_version.dart && git add lib/version.dart
    publish:
      dryRun: true
      gitTagVersion: false
      force: false
      skipValidation: false
      pubServer: https://pub.dev
```

Most `melos version` and `melos publish` options have a default here, but the
key is not always the camel cased option name: `--changelog` is
`updateChangelog`, `--dependent-constraints` is `updateDependentsConstraints`,
`--dependent-versions` is `updateDependentsVersions`, `--all` is
`versionPrivatePackages`, `--group-commits` is `changelogFormat/groupByType`
and `--yes` of `melos publish` is `force`. `--prerelease`, `--graduate` and
`--manual-version` have no key.

## Fixed (lockstep) versioning

With `mode: fixed`, every run bumps all packages to one version: the highest
current version, bumped by the most significant change in any package.
Unchanged packages get a changelog note. A manual version applies to all
packages. Enable `workspaceTag: true` to tag once per release as `v1.2.3`.

## Git hosted packages

Private packages can depend on each other through git tags. With
`updateGitTagRefs: true`, `melos version` rewrites
`ref: my_package-v1.0.0` to the new version in the dependents.

## Hot-fix releases from another branch

1. Branch from the release tag: `git checkout -b hot-fix/1.0.x my_package-v1.0.0`
   and push it with `--set-upstream`.
2. If `command/version/branch` is set, change it to the hot-fix branch name
   on that branch with a `chore:` commit.
3. Land the fix on `main`, then `melos cherry-pick <commit>` onto the hot-fix
   branch. Unlike `git cherry-pick`, it drops changelog, version and
   workspace constraint changes from the picked commits and skips release
   commits.
4. `melos version`, check the proposed version does not collide with one
   released from `main` (use `--manual-version` if it does).
5. `melos publish --no-dry-run` and `git push --follow-tags`.
6. Copy the new changelog section to `main` by hand with a `chore:` commit.

Never merge `main` into the hot-fix branch or pick its release commits, and
never merge the hot-fix branch back.

## Anti-patterns

- Bumping `version:` by hand and then running `melos version`: there is no
  tag for the hand-written version, so Melos falls back to the previous tag,
  bumps the version a second time and repeats the commits since that tag in
  the changelog.
- Expecting a `chore:` or `ci:` commit to release a package: it does not.
- Running `melos publish` and wondering why nothing was published: dry run
  is the default.
- Versioning an app without `--all` or `versionPrivatePackages`: private
  packages are skipped.
- `melos version --no-git-tag-version` to avoid a commit: it still commits.
  Use `--no-git-commit-version`.
- Using `melos version` in a workspace without `repository` and expecting
  commit links: set `repository`.

## References

- Automated releases:
  https://melos.invertase.dev/~melos-latest/guides/automated-releases
- Hot-fix releases:
  https://melos.invertase.dev/~melos-latest/guides/hot-fix-releases
- Version command: https://melos.invertase.dev/~melos-latest/commands/version
- Publish command: https://melos.invertase.dev/~melos-latest/commands/publish
- Cherry-pick command:
  https://melos.invertase.dev/~melos-latest/commands/cherry-pick

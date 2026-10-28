// What a fake agent leaves behind for each eval: an oracle that does the task
// right, in other words than the skills use, and a canary that does it the way
// the skills warn against. `reeval run --profile oracle-<eval>` must pass and
// `--profile canary-<eval>` must fail; see reeval.config.ts.
import type { ProfileDefaults } from 'reeval'
import { fakeHarness } from 'reeval/harness'
import { melos6Repo, melos8Repo, standaloneRepo } from './fixtures.ts'

type Fake = { files?: Record<string, string>; exec?: string }

const pubspecs = (files: Record<string, string>) =>
  Object.keys(files).filter((path) => path.endsWith('/pubspec.yaml'))

function profile({ files = {}, exec }: Fake): { defaults: ProfileDefaults } {
  return {
    defaults: {
      harness: fakeHarness({
        layout: 'claude-code',
        script: [[...(exec ? [{ exec }] : []), { write: files }, { reply: 'Done.' }]],
      }),
    },
  }
}

/** The standalone packages, each with `resolution: workspace`. */
const workspaceMembers = Object.fromEntries(
  pubspecs(standaloneRepo).map((path) => [path, `resolution: workspace\n${standaloneRepo[path]}`]),
)

const setup = {
  // A glob in `workspace:` (Dart 3.11+) and a melos section with only categories.
  oracle: {
    files: {
      ...workspaceMembers,
      'pubspec.yaml':
        'name: acme\npublish_to: none\n\nenvironment:\n  sdk: ^3.11.0\n\n' +
        'workspace:\n  - packages/*\n\n' +
        'dev_dependencies:\n  melos: ^8.10.0\n\n' +
        'melos:\n  categories:\n    tools:\n      - packages/acme_cli\n',
    },
  },
  // The Melos 6 layout: a melos.yaml with a packages list.
  canary: {
    files: {
      'pubspec.yaml':
        'name: acme\npublish_to: none\n\nenvironment:\n  sdk: ^3.9.0\n\n' +
        'dev_dependencies:\n  melos: ^8.10.0\n',
      'melos.yaml': 'name: acme\n\npackages:\n  - packages/**\n',
    },
  },
}

/** The Melos 6 packages, moved to the workspace. */
const migratedMembers = Object.fromEntries(
  pubspecs(melos6Repo).map((path) => [
    path,
    melos6Repo[path].replace('">=3.0.0 <4.0.0"', '^3.9.0\nresolution: workspace'),
  ]),
)

const migratedRoot =
  'name: acme_workspace\npublish_to: none\n\nenvironment:\n  sdk: ^3.9.0\n\n' +
  'workspace:\n  - packages/acme_cli\n  - packages/acme_core\n  - packages/acme_utils\n\n' +
  'dev_dependencies:\n  melos: ^8.0.0\n\n'

const migration = {
  // The exec options as flags of a nested `melos exec`.
  oracle: {
    exec: 'rm melos.yaml',
    files: {
      ...migratedMembers,
      'pubspec.yaml':
        migratedRoot +
        'melos:\n  scripts:\n' +
        '    analyze:\n      description: Analyze every package.\n' +
        '      exec:\n        command: dart analyze . --fatal-infos\n        concurrency: 1\n' +
        '    test:\n      description: Run the tests of every package that has any.\n' +
        '      run: melos exec -c 1 --fail-fast --dir-exists=test -- dart test\n',
    },
  },
  // The scripts moved over as they were: `run` next to an `exec` map.
  canary: {
    exec: 'rm melos.yaml',
    files: {
      ...migratedMembers,
      'pubspec.yaml':
        migratedRoot +
        'melos:\n  scripts:\n' +
        '    test:\n      run: dart test\n' +
        '      exec:\n        concurrency: 1\n        failFast: true\n' +
        '      packageFilters:\n        dirExists: test\n',
    },
  },
}

const generateScript = (body: string) => ({
  'pubspec.yaml': `${melos8Repo['pubspec.yaml']}    generate:\n${body}`,
})

const sources = {
  oracle: {
    files: generateScript(
      '      exec:\n        command: dart run tool/embed_assets.dart\n' +
        '        sources:\n          - assets/*.txt\n' +
        '      packageFilters:\n        fileExists: tool/embed_assets.dart\n',
    ),
  },
  // Runs in the right packages, every time.
  canary: {
    files: generateScript(
      '      exec: dart run tool/embed_assets.dart\n' +
        '      packageFilters:\n        dirExists: assets\n',
    ),
  },
}

/** `oracle-<eval>` and `canary-<eval>` profiles for every eval. */
export const fakeProfiles = Object.fromEntries(
  Object.entries({ setup, migration, sources }).flatMap(([name, fakes]) => [
    [`oracle-${name}`, profile(fakes.oracle)],
    [`canary-${name}`, profile(fakes.canary)],
  ]),
)

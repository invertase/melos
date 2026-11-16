import { DEFAULT_EGRESS_ALLOW, defineEnvironment, type Environment, type EvalOptions } from 'reeval'
import { docker } from 'reeval/sandbox'
import { melos6Repo, melos8Repo, standaloneRepo } from './fixtures.ts'

/** The Melos release whose skills the evals measure. */
const MELOS_VERSION = '8.10.0'

/**
 * Dart with Melos activated globally, like a developer's machine. The pub
 * cache is shared, so the agent (user `reeval`) runs the Melos that the image
 * build (root) activated, and the workspace's own Melos once it depends on it.
 * The pub cache also holds the skills that Melos ships, as it does for anyone
 * who has Melos installed.
 */
const dart = defineEnvironment('dart', {
  sandbox: docker({
    from: 'dart:3.13.7',
    id: 'dart',
    install: [
      `PUB_CACHE=/opt/pub-cache dart pub global activate melos ${MELOS_VERSION}`,
      'chmod -R a+rwX /opt/pub-cache',
      'ln -s /opt/pub-cache/bin/melos /usr/local/bin/melos',
    ],
  }),
  env: { PUB_CACHE: '/opt/pub-cache' },
  // pub.dev for `dart pub get`, not the Melos docs.
  egress: { allow: [...DEFAULT_EGRESS_ALLOW, 'pub.dev'] },
})

/** Three Dart packages that don't use Melos yet. */
export const standalone = dart.extendEnvironment('standalone', {
  files: standaloneRepo,
})

/** A workspace configured for Melos 6, in `melos.yaml`. */
export const melos6 = dart.extendEnvironment('melos-6', {
  files: melos6Repo,
})

/** A Melos 8 workspace, bootstrapped. */
export const melos8 = dart.extendEnvironment('melos-8', {
  files: melos8Repo,
  setup: [{ run: 'melos bootstrap', timeout: '5m' }],
})

/**
 * Runs an eval in `environment` and in the same environment with one of the
 * skills in `packages/melos/skills`, and reports the skill's lift. With the
 * skill, at least three attempts in four must pass.
 */
export function skillLift(environment: Environment, name: string): EvalOptions {
  const withSkill = environment.extendEnvironment(`${environment.name}+${name}`, ({ skill }) => ({
    skills: [skill.local(`../packages/melos/skills/${name}`)],
  }))
  return {
    compare: { baseline: environment, variants: [withSkill] },
    gate: { passRate: 0.75 },
  }
}

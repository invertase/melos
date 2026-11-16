import { evaluate, expect } from 'reeval'
import { melos, readYaml, script } from './checks.ts'
import { melos6, skillLift } from './environments.ts'

// Melos 7 moved the configuration into pub workspaces, and Melos 8 rejects a
// script that has both `run` and an `exec` map, the Melos 6 way to pass exec
// options. The prompt asks for the upgrade, not for either change.
evaluate(
  'upgrades a Melos 6 workspace to Melos 8 with the migration skill',
  skillLift(melos6, 'melos-migration'),
  async (c) => {
    await c.send('Upgrade this repository to the latest Melos.')

    expect.soft(await c.readFile('melos.yaml'), 'removes melos.yaml').toBeNull()
    await expect.soft(melos(c, 'bootstrap'), 'melos bootstrap succeeds').toSucceed()
    const lock = await readYaml(c, 'pubspec.lock')
    expect.soft(lock.packages?.melos?.version, 'locks Melos 8').toMatch(/^8\./)
    await expect.soft(melos(c, 'run test --no-select'), 'the test script runs').toSucceed()

    // One package at a time and stop at the first failure, as before: as
    // `exec` options, or as flags of a `melos exec` the script runs.
    const test = await script(c, 'test')
    const command = JSON.stringify(test)
    expect
      .soft(
        test.exec?.concurrency === 1 || /(-c|--concurrency)[ =]1\b/.test(command),
        'the test script keeps concurrency 1',
      )
      .toBe(true)
    expect
      .soft(
        test.exec?.failFast === true || command.includes('--fail-fast'),
        'the test script keeps failFast',
      )
      .toBe(true)
  },
)

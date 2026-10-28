import { evaluate, expect } from 'reeval'
import { melos, readYaml } from './checks.ts'
import { skillLift, standalone } from './environments.ts'

// Agents trained on Melos 6 and older write a melos.yaml with a `packages:`
// list, which Melos 7+ ignores without a word. The skill says the workspace is
// the root pubspec.yaml's `workspace:` and `melos:` section.
evaluate(
  'sets up a Melos workspace in pubspec.yaml with the workspace-setup skill',
  skillLift(standalone, 'melos-workspace-setup'),
  async (c) => {
    await c.send(
      'Set up Melos in this repository, so the three Dart packages in ' +
        'packages/ are managed as one monorepo.',
    )

    expect.soft(await c.readFile('melos.yaml'), 'no melos.yaml').toBeNull()
    const pubspec = await readYaml(c, 'pubspec.yaml')
    expect.soft(pubspec.dev_dependencies?.melos, 'melos is a root dev dependency').toBeDefined()
    await expect.soft(melos(c, 'bootstrap'), 'melos bootstrap succeeds').toSucceed()
    const list = await melos(c, 'list')
    expect
      .soft(list.stdout, 'melos finds every package')
      .toMatch(/(?=[\s\S]*\bacme_core\b)(?=[\s\S]*\bacme_cli\b)(?=[\s\S]*\bacme_utils\b)/)
  },
)

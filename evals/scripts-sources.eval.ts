import { evaluate, expect } from 'reeval'
import { melos, script } from './checks.ts'
import { melos8, skillLift } from './environments.ts'

const generate = 'run generate --no-select'
const ran = (output: string, name: string) =>
  new RegExp(`embed_assets: wrote \\d+ assets for ${name}\\b`).test(output)

// `exec.sources` (Melos 8.9) skips the packages whose matching files didn't
// change since the script last succeeded there. It's newer than any model's
// training data, so only the skill can tell the agent it exists.
evaluate(
  'skips packages with unchanged assets with the scripts skill',
  skillLift(melos8, 'melos-scripts'),
  async (c) => {
    await c.send(
      'Add a Melos script named `generate` that runs ' +
        '`dart run tool/embed_assets.dart` in every package that has that ' +
        'tool. The tool is slow on our real assets, so `melos run generate` ' +
        "should skip the packages whose assets haven't changed since it " +
        'last ran there.',
    )

    // Before the checks below touch an asset.
    expect
      .soft(c, 'leaves the tools and assets alone')
      .not.toHaveChanged(['packages/*/tool/**', 'packages/*/assets/**'])

    await expect.soft(melos(c, generate), 'the script runs').toSucceed()
    for (const name of ['acme_core', 'acme_cli']) {
      expect
        .soft(
          await c.readFile(`packages/${name}/lib/src/assets.g.dart`),
          `embeds the assets of ${name}`,
        )
        .toContain('const assets')
    }

    const again = await melos(c, generate)
    expect
      .soft(
        ran(again.stdout, 'acme_core') || ran(again.stdout, 'acme_cli'),
        'a second run skips both packages',
      )
      .toBe(false)

    await c.exec('echo "Usage: acme [--loud] [name]" > packages/acme_cli/assets/usage.txt')
    const changed = await melos(c, generate)
    expect
      .soft(
        ran(changed.stdout, 'acme_cli') && !ran(changed.stdout, 'acme_core'),
        'reruns only the package whose assets changed',
      )
      .toBe(true)
    expect
      .soft(await c.readFile('packages/acme_cli/lib/src/assets.g.dart'), 'embeds the new asset')
      .toContain('--loud')

    expect.soft((await script(c, 'generate')).exec?.sources, 'uses exec.sources').toBeDefined()
  },
)

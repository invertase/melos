# Melos skill evals

Do the [agent skills](../packages/melos/skills) that ship with `melos` help a
coding agent use Melos? Each eval gives Claude Code the same task in the same
repository, with and without one skill, four attempts a side, and
[reeval](https://github.com/invertase/reeval) reports the lift.

| Eval | Skill | What only the skill tells the agent |
| --- | --- | --- |
| `workspace-setup` | `melos-workspace-setup` | Melos 7+ reads the root `pubspec.yaml` (`workspace:` and `melos:`), not `melos.yaml`, which it ignores without a word. |
| `migration` | `melos-migration` | Upgrading from Melos 6 means pub workspaces, and Melos 8 rejects `run` next to an `exec` options map. |
| `scripts-sources` | `melos-scripts` | `exec.sources` (Melos 8.9) skips the packages whose files didn't change since the script last ran. |

The checks are deterministic: they run `melos bootstrap`, `melos list` and the
scripts the agent wrote, and read the YAML it left. No judge. With the skill,
at least three attempts in four must pass.

The sandbox is `dart:3.13.7` with Melos 8.10.0 activated globally. Its egress
allows pub.dev and the package registries, not the Melos docs. The pub cache
holds the skills Melos ships, as it does on any machine with Melos 8.10, so the
agent without the skill can still find them there.

## Run

```bash
npm ci
npx reeval run --dry-run       # the plan: 3 evals, 6 cells, 24 attempts
npx reeval doctor              # needs Docker and ANTHROPIC_API_KEY in .env.local
npx reeval image build
npx reeval run                 # or `--profile smoke`: one attempt per arm
```

`npx reeval run migration` runs one eval. Results land in `.reeval/runs/`;
`npx reeval studio` shows each attempt's transcript and diff.

## Changing an eval

Each eval has an oracle (a fake agent that does the task right) and a canary
(one that does it the way the skill warns against). They run in the real
sandbox with no keys. After changing an eval or its checks, the oracle must
pass and the canary must fail:

```bash
npx reeval run --profile oracle-setup workspace-setup     # exit 0
npx reeval run --profile canary-setup workspace-setup     # exit 1
npx reeval run --profile oracle-migration migration
npx reeval run --profile canary-migration migration
npx reeval run --profile oracle-sources scripts-sources
npx reeval run --profile canary-sources scripts-sources
```

The fake agents are in `fakes.ts`, the starting repositories in `fixtures.ts`.

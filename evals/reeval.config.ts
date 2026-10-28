// Do the agent skills in packages/melos/skills help a coding agent use Melos?
// Each eval runs a task with and without one skill. These run real agents and
// cost money; see README.md.
import { defineConfig } from 'reeval'
import { claudeCode } from 'reeval/harness'
import { fakeProfiles } from './fakes.ts'

export default defineConfig({
  include: ['*.eval.ts'],
  harness: claudeCode({ model: 'claude-sonnet-5-5' }), // needs ANTHROPIC_API_KEY
  timeout: '15m',
  // reeval analyze, on the harness's key.
  analysis: { model: 'anthropic/claude-haiku-5-5' },
  profiles: {
    // One attempt per arm: checks that the evals run, not a lift verdict.
    smoke: { limit: { runs: 1 } },
    // Fake agents in the real sandbox, no keys: oracles pass, canaries fail.
    ...fakeProfiles,
  },
})

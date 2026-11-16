import type { AttemptContext } from 'reeval'
import { parse } from 'yaml'

/**
 * Runs the globally activated Melos, which hands over to the workspace's own
 * version when the root pubspec.yaml depends on Melos. `--no-select` on `run`
 * skips the package prompt of scripts with `packageFilters`.
 */
export function melos(c: AttemptContext, args: string) {
  return c.exec(`melos ${args}`, { retries: 1 })
}

/** A YAML file in the workspace, parsed, or `{}` when it's missing or invalid. */
export async function readYaml(c: AttemptContext, path: string): Promise<Record<string, any>> {
  try {
    return parse((await c.readFile(path)) ?? '') ?? {}
  } catch {
    return {}
  }
}

/** The Melos script `name` from the root pubspec.yaml, or `{}`. */
export async function script(c: AttemptContext, name: string) {
  const pubspec = await readYaml(c, 'pubspec.yaml')
  const value = pubspec.melos?.scripts?.[name]
  return typeof value === 'object' && value ? value : {}
}

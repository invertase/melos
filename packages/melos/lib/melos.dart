// TODO(rrousselGit): export a Dart API for using Melos
// This requires a bit of refactoring, to remove the `exit()` calls.
// Ideally, it shouldn't expose the raw CommandRunner, so that we can make
// type-safe commands, with `await melos.publish(yes: true)` or similar.

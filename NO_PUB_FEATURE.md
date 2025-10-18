# --no-pub Feature Implementation

This document describes the implementation of the `--no-pub` global flag for Melos.

## Feature Description

The `--no-pub` flag allows users to skip automatic `pub get` calls at both the cli_launcher level and within Melos commands, which can significantly improve performance on limited machines or when dependencies are already resolved.

## Implementation Details

### Files Modified

1. **`bin/melos.dart`**

   - Added bypass logic to detect `--no-pub` flag
   - Calls `melosEntryPoint` directly when `--no-pub` is specified, skipping cli_launcher's automatic `pub get`
   - **Future**: Will use `LocalLaunchConfig(skipPubGet: true)` when cli_launcher is updated

2. **`lib/src/common/utils.dart`**

   - Added `globalOptionNoPub` constant

3. **`lib/src/global_options.dart`**

   - Added `noPub` field to `GlobalOptions` class
   - Updated constructor, `toJson()`, `operator==`, `hashCode`, and `toString()` methods

4. **`lib/src/command_runner.dart`**

   - Added `--no-pub` flag to argument parser with help text

5. **`lib/src/command_runner/base.dart`**

   - Updated `_parseGlobalOptions()` to parse the `noPub` flag

6. **`lib/src/commands/bootstrap.dart`**

   - Modified bootstrap logic to skip `pub get` when `--no-pub` is specified
   - Added appropriate logging message

7. **`packages/melos/test/commands/bootstrap_no_pub_test.dart`**

   - Added comprehensive tests for the new functionality

8. **`CHANGELOG.md`**
   - Added feature entry

## Usage

```bash
# Skip all pub get calls (cli_launcher + Melos internal)
melos --no-pub bootstrap

# Skip pub get for any command
melos --no-pub list --cycles

# Normal bootstrap (runs pub get)
melos bootstrap
```

## Benefits

- **Complete pub get bypass**: Skips both cli_launcher's automatic `pub get` and Melos internal calls
- **Performance**: Significantly reduces command startup and execution time
- **Limited Resources**: Essential for machines with limited processing power or slow internet
- **CI/CD**: Useful in environments where dependencies are pre-resolved
- **Development**: Speeds up iterative development workflows
- **Offline usage**: Enables working without internet connectivity

## Technical Implementation

### Current Implementation (Bypass Method)

1. **cli_launcher bypass**: Detects `--no-pub` and calls `melosEntryPoint` directly, skipping cli_launcher's automatic `pub get`
2. **Melos level**: Checks `global?.noPub` flag in commands to skip internal `pub get` calls

### Future Implementation (When cli_launcher is Updated)

1. **cli_launcher level**: Will use `LocalLaunchConfig(skipPubGet: true)` to prevent automatic `pub get` on startup
2. **Melos level**: Same - checks `global?.noPub` flag in commands

### Affected Commands

The `--no-pub` flag affects:

- **All commands**: Skips cli_launcher's startup `pub get`
- **bootstrap command**: Skips internal `pub get` execution
- **Future commands**: Any command that might call `pub get` internally

## Testing

### Current Status ✅

- **Flag recognition**: `melos --no-pub --help` shows the flag
- **cli_launcher bypass**: No automatic `pub get` when using `--no-pub`
- **Bootstrap integration**: Skips internal `pub get` calls
- **Performance**: Faster execution without redundant `pub get`

### Unit Tests

The implementation includes tests that verify:

- The flag is properly parsed and stored in `GlobalOptions`
- Bootstrap skips `pub get` when `--no-pub` is provided
- Bootstrap runs `pub get` normally when `--no-pub` is not provided
- Appropriate logging messages are displayed

## Dependencies

- Currently works with existing `cli_launcher` version using bypass method
- Future enhancement: `cli_launcher` with `LocalLaunchConfig.skipPubGet` support from [blaugold/cli_launcher#10](https://github.com/blaugold/cli_launcher/pull/10)

## Migration Plan for cli_launcher Update

When cli_launcher is updated with `skipPubGet` support:

1. **Update `bin/melos.dart`**:
   ```dart
   // Replace current bypass with:
   resolveLocalLaunchConfig: (arguments) async {
     if (arguments.contains('--no-pub')) {
       return LocalLaunchConfig(skipPubGet: true);
     }
     return null;
   },
   ```

2. **Remove bypass logic** (the `if (arguments.contains('--no-pub'))` block)
3. **Update dependencies** in `pubspec.yaml` to new cli_launcher version
4. **Test functionality** remains the same

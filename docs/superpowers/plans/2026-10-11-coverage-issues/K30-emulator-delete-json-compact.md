# `emulator delete --json` prints compact one-line JSON while every sibling `--json` is pretty-printed

Severity: contract
Component: cli
Platforms: android (Android-only command)
Rows: AND-146 (android)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Matrix AND-146 (help emulator_delete.txt): valid JSON naming the deleted AVD. The content is right; the format should
match the other `--json` outputs, which all go through `JSONOutput.string` (pretty-printed, sorted keys): `emulator
ensure`, `emulator sessions`, `emulator teardown`.

## Actual
Same invocation pair (AND-007/01.out):
```
{
  "created" : true,
  "name" : "cov-android-2",
  "state" : "Shutdown"
}
...
{"deleted":true,"name":"cov-android-2"}
```
The AVD is deleted (`avdmanager list avd` no longer lists it).

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_SESSION_ID=fix-k30; unset GRANTIVA_API_KEY
cd /tmp
grantiva emulator ensure --name fix-k30 --no-boot --json
grantiva emulator delete --name fix-k30 --json
```

## Evidence
- findings/evidence/cov-android/AND-007/01.out (line 9 is the delete document), AND-007/commands.txt
- Row pointer: findings/evidence/cov-android/AND-146/commands.txt

## Suspected cause
`Sources/GrantivaCLI/EmulatorCommand.swift:77-78` builds the document with
`JSONSerialization.data(withJSONObject: ["name": name, "deleted": true], options: [.sortedKeys])` instead of
`JSONOutput.string` (Sources/GrantivaCore/Output/JSONOutput.swift:13), which the sibling commands use.

## Acceptance criteria
- `emulator delete --json` prints the same document pretty-printed with sorted keys, byte-for-byte in the style of
  `JSONOutput.string` (`{\n  "deleted" : true,\n  "name" : "fix-k30"\n}`).
- Errors (refusals) are unchanged.
- GrantivaCLITests (EmulatorCommandTests or OutputStreamContractTests): the delete JSON equals
  `JSONOutput.string` of an equivalent Encodable; optionally a contract test that no command under `Sources/GrantivaCLI`
  calls `JSONSerialization.data` for `--json` output.

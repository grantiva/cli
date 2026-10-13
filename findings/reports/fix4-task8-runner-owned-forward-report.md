# Task 8 runner owned-forward cleanup report

## Result

Implemented L83 in runner commit `6b3c206a5c2590c8384c5a01077a9bf932c83be4` on `fix4/owned-forward-cleanup` from binding base `ff68658f73e4b6d9d94897d99ad1a0a270a105b7`.

Draft PR: https://github.com/grantiva/runner/pull/27

`StopUIAutomator2` and `StopDeviceLabDriver` no longer remove a local TCP endpoint merely because its number equals the driver's remote/device port (`6790` or `6791`). Both paths still remove the exact socket forward and allocated local TCP port recorded on the `AndroidDevice`, clear the recorded fields, remove their local socket/PID files, and preserve the pre-existing device-scoped default-socket cleanup.

## Production regression

Added `pkg/device/forward_cleanup_test.go`. Its fake executor is installed through the existing `execCommand` seam and records the actual argv emitted by both production stop methods. For each driver the test models three active endpoints:

- the tracked owned `localfilesystem:` socket;
- the tracked allocated local TCP endpoint (`tcp:16790` or `tcp:16791`);
- an unrelated endpoint whose local number equals the driver's remote port (`tcp:6790` or `tcp:6791`).

The test proves the two tracked endpoints are removed, the unrelated same-number endpoint remains, and a second cleanup is idempotent and does not broaden cleanup scope.

Baseline red evidence is in `findings/evidence/fix4-83/red-02/` (exit 1). It records both destructive production calls:

- `adb -s owned-device forward --remove tcp:6790`
- `adb -s owned-device forward --remove tcp:6791`

The first capture directory, `red-01/`, is intentionally retained and incomplete: the capture wrapper used zsh's read-only `status` variable after the test ran. Per the never-overwrite rule, the complete retry was written to `red-02/`. The red test file was untracked, so the generic `git diff` digest in `red-02/diff-hash.txt` is the empty-patch digest; the test file content represented by that run has SHA-256 `e7618c283ea825a33c169188d22b09377b4c382e56d35c9071095cc47071fb66`, and the raw failing argv/output is preserved.

Green focused evidence is in `findings/evidence/fix4-83/green-focused-01/` (exit 0). The pre-commit complete-device-suite and vet captures are in `device-tests-01/` and `vet-device-01/` (both exit 0). Their working diff SHA-256 is `4ae9dc21be0a5f21eab0ffc4ec981be252768955d8c99520d2101a9929331902`; as above, that generic digest excludes the then-untracked test file.

## Exact committed-source validation

The final required checks were repeated after commit with the binding literal session value. Both used source hash `6b3c206a5c2590c8384c5a01077a9bf932c83be4`, a clean working-tree diff digest `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`, API keys unset, `GRANTIVA_SESSION_ID=fix4-83`, and separate fresh `GRANTIVA_RUNNER_HOME` / `MAESTRO_RUNNER_HOME` directories. Before/after home inventories are identical. Earlier successful captures using `sessionfix4-83` remain preserved but are superseded by these literal-session attempts.

| Check | Evidence | UTC interval | Exit |
|---|---|---|---:|
| `go test -count=1 ./pkg/device` | `findings/evidence/fix4-83/postcommit-device-tests-session-fix4-83-01/` | 2026-10-13 18:01:19–18:01:28 | 0 |
| `go vet ./pkg/device` | `findings/evidence/fix4-83/postcommit-vet-device-session-fix4-83-01/` | 2026-10-13 18:01:36–18:01:37 | 0 |

The commit patch SHA-256 (`git diff ff68658f..6b3c206`) is `974f78e7d4bd4fd45b35337d2237a4694c0046d855a933fde6236290247f1a07`.

## Self-review

The production change deletes only the two unconditional remote-number removals. It introduces no remove-all fallback, process kill, lifecycle change, driver start change, CLI edit, version change, tag, release, or merge. The regression calls the production stop methods rather than duplicating cleanup logic.

## Remaining gates owned by the controller

- Independent review of runner PR 27 and CI completion before merge/live work.
- Live owned control `tcp:6790 -> tcp:16790` must survive healthy stock, foreground-ready SIGINT, and normal foreground stop while runner/CLI-owned forwards and sessions disappear after each.
- Merge is not performed by this task.
- After runner merge, build the controller-owned fresh both-architecture `.15` CLI package, run full CLI tests/CI, and repeat exact final-candidate smoke coverage. No tag or release.

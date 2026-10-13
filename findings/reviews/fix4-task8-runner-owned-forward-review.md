# Task 8 runner owned-forward cleanup independent review

Review base: `ff68658f73e4b6d9d94897d99ad1a0a270a105b7`.
Reviewed head: `6b3c206a5c2590c8384c5a01077a9bf932c83be4`.
Scope: L83 runner ownership fix, its production-path regression, and the corrected raw evidence. This was a static, device-free review. No tests were rerun, no source or device was changed, and no subagent was used.

## Verdict

**APPROVED for the scoped L83 source change.** No blocking, important, or minor source finding was identified in the reviewed diff. The implementation is the minimal ownership correction required by the binding brief: each stop path retains cleanup of its recorded socket and allocated local TCP endpoint while removing only the unconditional deletion inferred from the driver's remote port number.

This approval is not live acceptance or merge/release approval. Current-head CI, controller-owned live lifecycle proof, runner merge, the fresh both-architecture `.15` CLI package, and final-candidate validation remain outstanding gates.

## Source and ownership review

- `StopUIAutomator2` no longer issues unconditional `adb -s <serial> forward --remove tcp:6790`.
- `StopDeviceLabDriver` no longer issues unconditional removal of `tcp:DeviceLabDriverPort` (`tcp:6791`).
- Both paths still remove the exact `localfilesystem:` endpoint held in their driver-specific tracked socket field, remove the corresponding socket/PID files, clear that field, remove the exact tracked allocated TCP port, and clear that port field.
- Existing device-scoped default-socket cleanup remains intact. There is no forward enumeration, remove-all fallback, broad process kill, start-path change, CLI change, version change, tag, release, or merge in the commit.
- The committed regression uses the existing `execCommand`/`withFakeExec` seam and calls the actual production stop methods for both drivers. It models a tracked socket, a tracked allocated TCP endpoint, and a distinct unrelated endpoint whose local number equals the driver's remote port. It proves both tracked endpoints are removed and the unrelated endpoint survives the initial and repeated cleanup calls.
- The repeat call runs after the production methods have cleared their tracked fields, so it exercises the idempotent state-reset path while retaining the unrelated endpoint. Continuing default-socket removal on repeat is preserved pre-existing behavior and is within the brief.

The full reviewed commit is limited to three files: two five-line deletions in production and the 103-line regression. `git diff --check` is clean. The source worktree is clean at the reviewed head, and the local branch is aligned with `grantiva/fix4/owned-forward-cleanup`.

## Red/green and provenance review

The baseline capture `findings/evidence/fix4-83/red-02/` records source `ff68658f73e4b6d9d94897d99ad1a0a270a105b7`, exit 1, and failures for both production paths. Its argv log shows the tracked socket and allocated TCP cleanup followed by the destructive unrelated calls `tcp:6790` and `tcp:6791`. Although the regression was untracked during this capture and therefore absent from the generic clean-diff digest, the committed test file hashes to the report's separately recorded SHA-256 `e7618c283ea825a33c169188d22b09377b4c382e56d35c9071095cc47071fb66`. The incomplete `red-01/` capture remains preserved and is not presented as the authoritative red result.

The corrected final captures are authoritative:

- `postcommit-device-tests-session-fix4-83-01/`: `go test -count=1 ./pkg/device`, source `6b3c206a5c2590c8384c5a01077a9bf932c83be4`, literal session `fix4-83`, exit 0.
- `postcommit-vet-device-session-fix4-83-01/`: `go vet ./pkg/device`, the same source and literal session, exit 0.

Both record the clean-tree digest `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`, API variables unset in the captured argv, separate fresh runner homes, matching empty before/after inventories, cwd, timestamps, stdout/stderr, and exit status. The actual base-to-head patch hashes to the reported SHA-256 `974f78e7d4bd4fd45b35337d2237a4694c0046d855a933fde6236290247f1a07`. Earlier successful `sessionfix4-83` captures are correctly retained and superseded rather than rewritten.

## Remaining gates and scope boundary

The controller still owns live proof that unrelated `tcp:6790 -> tcp:16790` survives healthy stock completion, foreground-ready SIGINT, and normal foreground stop while owned forwards and sessions disappear. PR 27 CI and review policy must complete before merge. After runner merge, the controller must build and validate the fresh both-architecture `.15` CLI package and run the specified final-candidate coverage. The separate L84 broad CLI cleanup concern is outside this runner diff and is neither fixed nor regressed by this approval.

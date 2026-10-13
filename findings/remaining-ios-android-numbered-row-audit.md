# Remaining IOS/AND numbered-row evidence audit

Scope: read-only audit of the currently ungraded `IOS-*` and `AND-*` base IDs against retained round-3 evidence. Candidate source is `release-main` at `8f2cff67`; no quarantined `cov2-ios` artifact is used. The pre-import `cov3-ios` top-level groups are used only when `PROVENANCE.md` explicitly allows the named group; none is needed for the one complete join below.

## Complete join ready for grading

### IOS-059

`cov3-ios-attempt54/` is an exact, fresh five-repeat execution of two concurrent runs on U1 and U2 using `01-browse.yaml` and `05-category.yaml`. `failed-pairs.txt` is empty; every `pair-{1..5}/{u1,u2}.exit.txt` is `0`. The paired stderr streams identify different WDA ports (8511 and 8174) and different device/session paths, and `device-homes-before.txt` / `device-homes-after.txt` preserve the per-UDID homes. This satisfies both-exit-zero, distinct-port/session, and per-UDID-home clauses. The prior scoped review in `findings/ios54-55b-android-k110-review.md` reached the same conclusion.

Evidence root: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt54/`.

## Priority IOS rows that are not complete joins

| ID | Retained evidence | Exact remaining gap |
|---|---|---|
| IOS-090 | Attempt 32 proves both U1/U2 booted and a config-selected U1 session; attempts 44/56 preserve plain screen names such as `Deep Links.png`. | No retained capture establishes that U2 was untouched across the exact config-selected `diff capture --no-build` command. Join is partial. |
| IOS-107 | Attempt 16c request 14 proves ordered script execution including `wait: 1` and point-valued `tap_xy`, but its first tap is `Gesture Lab` and it adds `swipe`. Attempt 7b separately taps `Favorites`. | No single eligible request uses the literal matrix array `tap Favorites`, `wait 1`, `tap_xy`. Do not combine different requests into the exact-input claim. |
| IOS-086 | Current attempts prove live keep-alive hierarchy paths, but no located eligible command is the exact `runner dump-hierarchy --udid ...` fallback without a prior `runner start`. | Exact fallback invocation/result remains needed. The quarantined `cov2-ios/IOS-086` directory is ineligible. |
| IOS-060 | Attempt 20 proves lease creation/retention/release for one detached session. | It does not run a second same-UDID `run` and therefore does not preserve the required immediate owner-PID/freeing-command refusal. |
| IOS-064 | Attempt 30 preserves success, failure, and interrupted `--logs` modes and post-process snapshots. | Its own `signal.json` says the active log-stream process was not observed. The outputs can support content/cleanup joins, but the whole row should retain the existing qualified assessment rather than be newly inferred from filenames. |

## Other missing IOS rows: smallest missing observation

The lifecycle/destructive group IOS-014/015/016/017/018/020/121/122/147/148/149/155 still needs its exact owned-device setup and before/after ledger or process observations. IOS-042/043 need the IPA simulator/device-build variants. IOS-044 needs the paired installed/uninstalled `--no-build` sequence. IOS-123/124/126 need their exact bundle-ID/README precedence fixtures. IOS-052/053/054/057/088/089/139 need the exact two-session, dead-session, Ctrl-C, or ownership variants. IOS-095 needs the subtle-colour threshold pair. IOS-132/133 need the exact screens snapshot/report-layout variants. IOS-136 needs the two requested frame timestamps while flow 10 runs. IOS-150 needs ten alert runs. IOS-153 needs byte comparisons across all three JSON verbosity modes. No full-row verdict is supported by the inspected retained artifacts for these rows.

## Android numbered rows

No newly complete `AND-*` row was found in the inspected missing set.

* AND-057 has an exact hierarchy command, but `AND-057-before.txt` and `AND-057-after.txt` both contain an existing `tcp:<port> tcp:6790` forward for the target device. They do not prove that a local 6790 forward existed only for the command; keep the row ungraded.
* AND-087 has an eligible unchanged capture, but the missing-set evidence located here does not contain the required changed-pixel and JSON legs together. Keep it partial.
* AND-080 needs the detached-start boot plus held UIAutomator2 and persisted port in `session.json`; AND-101 needs exact MCP module/variant/emulator build and run with APK product path; AND-122 needs each docs/android.md keep-alive example and its promised output. No complete exact join was located.
* AND-011/013/015/016/017/018/058/068/100/110/115 require their respective force/refusal, timeout, externally-owned-emulator, dead-session, restore-after-kill, MCP lifecycle, documentation-example, or boot-wait runtime variants. Source or nearby lifecycle evidence alone does not close them.

## B2-K33 and X-024 scoped review

The fresh Android root is `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B2-K33-X024-verbose-processes-rerun2/` and reports `failures=0`.

For B2-K33 `[android]`, `run-verbose/stderr.log` contains the `adb logcat` start at line 20, runner start at line 59, runner `exit 0` at line 148, and logcat `stopped by SIGTERM` at line 171. `record-verbose/stderr.log` contains the Android `screenrecord` start and `exit 0` at lines 5-6. Neither plain stderr contains debug `$`/terminal lifecycle records. The exact-head source bundle identifies `ChildProcess`/subprocess logging code and tests, but it is broad; it does not by itself demonstrate a dedicated captured-logger assertion for every named long-running process. The fresh runtime does fully support the Android runner/logcat/screenrecord and plain-suppression clauses. Secret-redaction and the shared semantic-test clause must remain joined from previously reviewed exact-head source evidence, not inferred from these logs.

For X-024, Android exact flow 08 emits `[log]` prefixed lines interleaved with runner narration in both `run-plain/stderr.log` and `run-verbose/stderr.log`. The inspected iOS attempt 30 logging command uses `99-crash.yaml`, not flow 08. Therefore the Android half/form is supported, but the explicit cross-platform flow-08 comparison is not closed by attempt 30. A current eligible iOS flow-08 `--logs` capture is still required unless another already-reviewed artifact is identified with that exact input.


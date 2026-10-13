# Android B-A07.1 logs/SIGINT review

## Verdict

**PASS.** `B-A07.1-B2-K88-logs-tty-sigint-rerun1` directly satisfies the exact matrix criterion. This review does not assess or grade `B2-K88`.

## Evidence mapping

- `run/command.json` records the exact current-candidate command: `run --platform android --device emulator-5554 --no-build --logs --flow .maestro/11-slow.yaml --report-dir ...`.
- The command ran under a real PTY. `run/transcript.txt` visibly reaches Setup, Execution, the `11-slow` flow, and live runner progress. This establishes that SIGINT targeted an active `run --logs` reproduction rather than an early argument/configuration error.
- `run/processes-during.txt` contains the row-owned logger process `adb -s emulator-5554 logcat --uid=10217 -v time ...`; `run/decoded.json` identifies that exact matching process and records `logcatPresentDuring: true`.
- `run/exit.txt` is exactly `130`.
- `run/processes-after.txt` contains no matching `adb ... logcat`; `run/decoded.json` records an empty `matchingAfter` list and `noNewLogcatAfter: true`.

The wrapper's overall nonzero status does not undermine the row. Its two false assertions concern optional narration proxies (`runnerOutputStreamed` and `sigintNarration`) that B-A07.1 does not require. The binding criterion is narrowly “no `adb ... logcat` process remains after exit 130,” and the raw process inventories prove that directly.

Evidence root: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B-A07.1-B2-K88-logs-tty-sigint-rerun1/`.

# Android stable manual fixture fix1 re-review

**CHANGES REQUIRED before live use.** The port, PPID handling and immutable journals improve the four original findings, but three concrete startup/failure paths remain broken. This is a scoped repair review, not a new fixture design or product-causality finding.

Verified helper SHA-256 `bd919f9a8d5250ebe394bf9d1c8563842e288fc28ed36e5f62524f9481b5f1c6`, fake-check SHA-256 `561b941efc58aad69d5a6a818acaf802192f3d67a85b4d07a317603342ef78e1`, and reported passing output SHA-256 `4f8737a9f17b4e4b7c5ba769f32694354a69793ec0aa8ee7eb49e43dc4c040fd`. The retained four fake scenarios were inspected and not rerun.

## Original finding disposition

| Original finding | Disposition |
|---|---|
| Stable identity including changing PPID | PPID issue fixed; startup-handoff portion remains incomplete, as below. |
| Serial not bound to launch port | Addressed: explicit `-port 5556`, serial-absence and TCP-port preflight, persisted port/serial. Root reservation authority remains separate. |
| Unbounded readiness/verify probes | Deadline enforcement addressed; new fatal treatment of normal startup nonzero probes prevents readiness polling. Timeout partial-output persistence also needs correction. |
| Missing startup PID journal/overwritten verification | Pending/PID journal and exclusive numbered verification fixed. Nonempty timeout-output serialization can still prevent terminal failure evidence. |

## Required scoped corrections

### P1 — an ordinary not-yet-attached adb response aborts readiness instead of polling

`probe:28` raises on every nonzero exit. `device_state:43–44` uses it for `adb -s emulator-5556 get-state`, and `launch:74` does not catch that failure inside the readiness loop. Immediately after starting a healthy emulator, adb can legitimately report device not found/offline with nonzero status. The outer exception handler then writes failure and returns, leaving the launched fixture running without ever giving it the advertised boot deadline.

Preserve nonzero startup probe evidence as a not-ready observation and continue only within the existing overall deadline while the owned process lives. Never accept readiness unless all three probe exits are zero and all expected values match. Keep fatal identity mismatch and exhausted deadline as failures. A fake not-found/offline observation followed by ready can qualify this changed branch without live execution.

### P1 — identity is still frozen before the startup handoff

`launch:68–71` immediately snapshots the newly spawned SDK `emulator` process and requires its command already contain `qemu-system`. It then requires the entire stable identity, including executable and command text, to be identical at readiness (`76–77`). Normal SDK launcher-to-qemu handoff can therefore be rejected either at the immediate check or at the final comparison. The previous review specifically requested final stable identity capture after startup handoff; excluding PPID alone does not complete that change.

Keep the immediate returned PID journal as provisional evidence. Within the existing startup deadline, authenticate the same PID/start/group/session and wait for its expected qemu AVD/port identity, then freeze that ready identity for later separate-cell verification. Do not follow an unrelated PID or weaken the exact AVD/port constraint. Cover an emulator-wrapper identity transitioning to expected qemu identity with fake observations.

### P2 — nonempty timeout streams are bytes and cannot be JSON encoded

`probe:25–27` puts `TimeoutExpired.stdout/stderr` directly into the record even though Python exposes captured timeout output as bytes, including when `text=True` was requested. If a hanging probe emitted anything, `terminal`/`exclusive_json` later passes those bytes to `json.dump` and raises `TypeError`. A partially written exclusive JSON file can remain while the intended structured failure is lost. The fake sleeper emits no output and only inspects the exception; it does not exercise serialization.

Normalize timeout output explicitly before JSON serialization, retaining raw bytes separately or using an explicit lossless representation. Exercise a fake probe that emits both streams and then times out, and confirm the actual launch/verify terminal path writes parseable immutable evidence. Preserve the first current qualification output; do not substitute another live emulator attempt.

## Boundaries retained

DEVNULL stdin, direct exclusive emulator logs, new session, closed inherited descriptors, explicit reserved port, positive argument validation, PID journaling and numbered verification files are appropriate and should remain. No teardown or automatic cleanup action should be added; uncertain startup identity must remain evidence for root's later exact owned cleanup decision, not a guessed signal target.

This review used only the provided helper, report, package and fake-check files. No device, process, adb, test, build or network command was executed for the re-review. No actor code or raw evidence was changed; only this report was added. The separate current retirement inventory task remains inventory-only and grants no fixture launch window.

# Candidate4 Android core-through-030 scoped rereview

Status: **CHANGES REQUIRED — the five evidence gaps are cleared; AND-110 and three aggregate ledger bindings need narrow corrections.**

Scope was limited to the five gaps from `candidate4-android-core-through030-review.md`, their final ledger bindings, and the requested AND-110 qualification. No command, build, compiler, or device operation was run.

## Five corrections

1. **AND-021 — cleared.** `supplement-process-before.stdout` and `supplement-process-after.stdout` are both empty around `supplement-no-launch`, while `supplement-package-after.stdout` proves `com.kylebrowning.landmarks` remains installed. The command record retains the candidate identity, exact cwd/environment, exit status and timing. This now proves the literal not-running condition in addition to the original JSON fields.
2. **AND-022 — cleared.** `signing-status.stdout` verifies the exact produced APK with v2 signing and one signer whose certificate DN is `C=US, O=Android, CN=Android Debug`. Under the corrected row, the unsigned warning is therefore inapplicable; the retained build output proves `assembleFreeRelease` and the APK path.
3. **AND-107 — cleared.** `run-crash-rerun-1` exits 1 without timeout and reports the required `LANDMARKS_CRASH_ON_LAUNCH` failure at `launchApp` in about 4.7 seconds. The retained `report.json` is a failed report for the same flow, and the retained report inventory hashes its machine report, failure screenshot, logs and flow artifacts. The public report does not expose a separate `error.type` field, but the matrix accepts the explicit `app_crash` launch classification in the command output; no extra artificial field is required.
4. **AND-108 — cleared.** `capture-artifacts.stdout` hashes all five retained PNGs. Direct visual inspection confirms `Lakes.png` shows Lakes with Lake Tahoe, Mono Lake and Crater Lake, and `Detail.png` shows Golden Gate Bridge with the `Plan Visit` control. `diff-capture-rerun-2` reports 5/5 and binds those names to the successful capture.
5. **AND-144 — cleared.** `distinct-config-readback.stdout` records deliberately invalid iOS sentinels in `grantiva.yml` and a usable Android module/variant/application/emulator in `grantiva-android.yml`. `install-platform-android-rerun-1` then succeeds from that fixture and installs `com.kylebrowning.landmarks`. This distinguishes Android config selection; the identical-config first capture remains preserved.

## Remaining ledger corrections

- **AND-110 is still overgraded.** Its row verdict says `Result: pass`, the durable ledger says `pass`, and the core total counts it among 44 passes. The retained `blocked-global.txt` says the required `grantiva emulator teardown --all` leg was not executed because of the campaign environment constraint. Record AND-110 as **partial / environment-blocked**, with the named examples passed and the global leg blocked. It must not remain an unqualified full pass even though the expected outcome for that line is “blocked.”
- The ledger directly binds AND-107 and AND-108 to their row directories. AND-021 and AND-022 are only hidden behind the aggregate `AND-019–025` row whose Evidence link points to `AND-019/`; AND-144 is hidden behind `AND-143–144` whose link points to `AND-143/`. Add exact ledger entries or explicit additional links for `AND-021/`, `AND-022/`, and `AND-144/` so the corrected evidence resolves from the final grade without relying on prose about separate directories.
- Recompute the core-window totals after qualifying AND-110. Preserve all original verdicts and fixture-first attempts.

The five former evidence gaps do not show a candidate4 product failure. Final approval is blocked only by the grade/binding corrections above.

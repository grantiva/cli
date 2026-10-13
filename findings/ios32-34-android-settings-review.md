# Round 3 scoped evidence review: iOS attempts 32–34 and Android settings

Reviewed against `2026-10-13-round3-coverage-matrix.md` at the current candidate CLI commit `8f2cff676b3c12e951478920fa20e600cdca4e29` and runner commit `fd9d8e8`. This review treats platform halves independently and uses no quarantined round-2 evidence.

## Material findings

1. **B-I02.2 [ios] is overgraded as a complete pass.** The cited evidence establishes an explicit simulator selection (attempt 21), a configured simulator selection (attempt 22), session fallback (attempt 32), and refusal when several simulators are booted (attempt 32). It does not establish the required *precedence* of flag over a conflicting config value: attempt 21's `--simulator 563907E1-...` names the same `cov3-ios-26` device as its config. It also does not exercise the final fallback when exactly one simulator is booted. Keep the individual IOS-143 and IOS-144 passes; B-I02.2 needs these two missing observations or a qualified/blocked grade.

2. **IOS-040's behavioral run is credible, but its ledger citation is broken and two claims lack retained direct evidence.** `cov3-ios-attempt33/grantiva.yml` does not exist. The retained `harness.sh` proves the scratch config was written with only `bundle_id`, and `app-file.out` proves the eight-step run passed. However, the `.app` path was in temporary scratch and is no longer retained, and there is no preserved `Info.plist`/`plutil` output or install narration proving that the bundle ID was read from that app. Replace the nonexistent citation with `harness.sh`; qualify the Info.plist-derived-ID claim unless a contemporaneous retained capture exists.

3. **AND-145 used the wrong required flow.** Matrix row AND-145 requires `--flow .maestro/01-browse.yaml`; `android-settings-lifecycle-exact-rerun1/AND-145/commands.txt` shows `.maestro/11-slow.yaml`. The capture does prove flag acceptance plus apply/save/restore behavior, but not the exact row input. Grade it partial/blocked pending an exact-input run rather than pass.

4. **AND-067 also uses a different flow than the row specifies.** Its joined AND-065-067 command runs `.maestro/11-slow.yaml`, while AND-067 specifies `.maestro/01-browse.yaml`. The normal-exit restoration itself is strongly evidenced (prior/live/after values and state-file removal), but strict exact-input grading should remain qualified. AND-066 exactly specifies the slow flow and is supported.

5. **IOS-072 remains provisional because attempt 34 used an undocumented input form.** Its command repeats `--flow`, but README.md:104 and `Sources/GrantivaCLI/RunCommand.swift:17-18` expressly define a *single* flow override. The observed last-value behavior therefore does not prove same-basename deduplication. The supported multi-flow form is the `flows:` config array. A config-driven run with `a/same.yaml` and `b/same.yaml` is required before classifying IOS-072; see `IOS072-K25-requirement-triage.md`.

6. **B2-K25 [android] exposes a requirement conflict, not a product regression.** Its compound wording includes `ci run`, but matrix CLI-108/CLI-167/AND-089, B-D06.1, docs/android.md and the Android design all require the exact early local-baselines-only refusal. The supported Android build-install/run/local-diff behaviors satisfy K25. Task 6 should reconcile the K25 compound row with the established Android CI boundary; see `IOS072-K25-requirement-triage.md`.

## Supported grades

- IOS-143 and IOS-144: supported by attempt 32 session metadata, exact device identity, five-device ambiguity message, and unchanged booted lists.
- IOS-035, IOS-036, IOS-037: supported by exact command arrays plus retained live hierarchy values and successful flow output.
- IOS-073: supported for the observable contract by exact 30-second command, 33-second total wall time, failed ready state, no running state, and complete terminal message. The SIGTERM mechanism is additionally consistent with the exact-head timeout implementation; wall time alone would not identify the signal.
- IOS-100: supported. All 24 server stdout lines are JSON-RPC, the mixed batch continues receiving correctly identified responses after subprocess-backed calls, and the client records `nonjson_lines=0 server_alive=True`.
- IOS-111: supported by the exact MCP transcript: explicit scheme, Product path, and build/run summary with scheme, bundle ID, simulator and Product.
- IOS-113: supported. Attempt 22 `commands.txt` pins the server executable SHA/path, and the transcript shows capture JSON, compare metrics/status, named Home-only approval, later all-screen approval, and JSON-RPC-only stdout.
- IOS-068 and IOS-069: supported. The reports distinguish failed 99-crash followed by a passing eight-step browse under continuation from failed 99-crash followed by a zero-command skipped browse without continuation; both commands exit nonzero.
- AND-026: supported by exact paidDebug runtime evidence, warning naming configured and APK IDs, installation/testing of `.paid`, and report `app.id`.
- AND-066: supported as noted above.

## Evidence-integrity notes

Attempt 33's temporary app/config workspace is gone, so claims should rely only on its retained harness and outputs. Attempt 22 directly records `/Users/kyle/.grantiva-qa/bin/grantiva mcp` and the expected QA SHA. No reviewed claim depends on reconstructed pre-import groups.

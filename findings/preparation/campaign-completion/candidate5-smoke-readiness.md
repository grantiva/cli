# Candidate5 smoke readiness

Status: **static preparation only**. No build, test, device, emulator, network, candidate, or smoke command was run. Candidate5 smoke must begin only after the fresh iOS 26/27 early gate passes and root freezes the candidate5 manifest and dynamic device identities.

## Accepted workflow to reuse

Use the final candidate4 files as the semantic bases:

- `findings/evidence/completion-candidate4/run-smoke-phase.py`
- `findings/evidence/completion-candidate4/provision.py`
- `findings/evidence/completion-candidate4/final-cleanup.py`
- the final files under `findings/evidence/completion-candidate4/harness/`, especially corrected `lifecycle_smoke.py` SHA-256 `29b89b63681932baba6601051cdffc7b501fb03c6433c91878506c4eca9bb7be` and its dependent `foreground_force.py` SHA-256 `03728f386e6a6433b7efdc9558cae3a4ef35ade2f5439936a60a2acbcad0cc3c`.

The candidate4 final-smoke review approved these semantics, including the recorder correction for authenticated report-root/subtree disappearance. Candidate5 must copy the corrected lifecycle recorder, never `lifecycle_smoke.before-recorder-fix.py`. After the candidate5 session/path rebinding changes the lifecycle file bytes, recompute and bind that exact SHA in `foreground_force.py`; retain the dependency check.

## Binding-only copy set

After candidate5 is frozen, copy these files into `findings/evidence/completion-candidate5/` and `.../harness/` with only the listed substitutions:

| file | bindings permitted |
|---|---|
| `run-smoke-phase.py` | candidate root; frozen candidate manifest SHA; candidate5 `argv-bound.json` |
| `provision.py` | candidate root, session/home/scratch from candidate5 initial state, reserved iOS/AVD names and collision-free Android port/serial |
| `harness/candidate_identity.py` | ownership session literal |
| `android_runner_smoke.py`, `docs-output.py`, `forward_joint_live.py`, `mcp_smoke.py` | candidate5 session/evidence/input roots and owned AVD name only |
| corrected `lifecycle_smoke.py` | candidate5 session literal only |
| `foreground_force.py` | candidate wording plus SHA-256 of the rebound corrected lifecycle helper |
| `mcp_client.py` | byte copy; no candidate binding expected |
| `smoke-emulator-launch.py` | reserved owned AVD name and allocated port/serial |
| `argv-templates.json` / `argv-bound.json` | candidate manifest, ownership, source, binary/bundle/runner/home/project/session, fresh outputs, owned UUID/serial/AVD and frozen app |
| `final-cleanup.py` | generate last, after live provisioning and accepted phases: exact manifest/ownership/process/baseline hashes, owned UUID/name/runtime, AVD/serial/PID, scratch/home namespace, and fresh acceptance hashes |

Do not carry candidate4 UUID `8BE033F1-0455-4BE3-A083-3132222D63C6`, serial `emulator-5580`, PID `39152`, session `completion-candidate4`, AVD `smoke4-c4-android`, manifest SHA, output directories, or acceptance hashes into executable candidate5 files. Protected UUID and Pixel constants remain unchanged.

## Dependencies and order

1. Candidate5 preparation completes and freezes `candidate.json`; bind its external SHA. The existing candidate5 `PREPARATION.md` and `early-ios26-gate.template.json` govern freeze and the mandatory early gate.
2. Provision fresh owned iOS and Android resources with absent-name/serial checks and write a new `provision/ownership.json`. If early-gate devices are adopted into smoke, the new ownership record must explicitly authenticate their exact UUIDs and creation provenance; otherwise provision separate smoke resources. Never infer ownership from a name.
3. Require the early iOS gate to pass exact stock and diff captures on iOS 26, followed by the iOS 27 regression checks. A failure stops broad smoke.
4. Create fresh project/output roots and bind `argv-bound.json`. Run `candidate-identity` first, then Android runner, full corrected lifecycle in one fresh output (no candidate4 resume split), joint forward, iOS MCP, Android MCP, docs/output, foreground force, and final cleanup. Every phase writes fresh captures.
5. Generate `final-cleanup.py` only after dynamic identities and accepted phase files exist. Preserve exact process identity checks and exact-resource deletion; do not broaden process matching or cleanup.

## Pre-execution review

Record unified diffs from each accepted candidate4 base to the candidate5 copy. Reject any change outside the binding table. Parse every Python file with `ast.parse` without importing it, verify JSON templates parse, verify no `PENDING` token remains in executable argv, and hash the complete prepared package. The candidate5 manifest SHA must be checked by `run-smoke-phase.py` before it creates an invocation directory. `GRANTIVA_API_KEY` remains unset and both isolated runner-home variables must use the candidate5 home.

The scripts are intentionally not copied before the frozen manifest and dynamic allocation bindings exist: `run-smoke-phase.py` must pin the final manifest SHA, `provision.py` must use controller-reserved names/port, `foreground_force.py` must pin the rebound lifecycle hash, and `final-cleanup.py` must pin live ownership/process and acceptance hashes. Creating executable-looking files with placeholders would weaken the accepted fail-closed controls. The table above is the complete bounded copy recipe for root inspection.

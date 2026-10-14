# Candidate 5 smoke binding readiness

Status: **prepared, statically parsed, not executed**.

The candidate 4 final controller and corrected harness were copied byte-for-byte before applying only candidate identity, completion namespace, session/home, evidence/input roots, reserved owned names, and Android port/serial substitutions. `run-smoke-phase.py` pins candidate manifest SHA-256 `191e59afdca010e488f1825d5064fc05facde89f065e71bac9e1ecee91c3d30c`. `provision.py` retains the eventual absence preflights and binds iOS name `smoke5-c5-ios`, Android AVD `smoke5-c5-android`, port `5582`, and serial `emulator-5582`.

The corrected lifecycle helper is rebound only from session `completion-candidate4` to `completion-candidate5`; its SHA-256 is `5aceb568822e167004f516aa4d99fbb12c47eb80ebabc637bbecab2ba34d0625`. `foreground_force.py` pins exactly that hash. `mcp_client.py` remains byte-identical to candidate 4.

Every Python copy passed `ast.parse` without import or execution, and `argv-templates.json` parses. The template intentionally retains dynamic `PENDING` device, app, sampler, and analyzer fields. `argv-bound.json` was not created because ownership does not exist. `final-cleanup.py` was not created because ownership, process identity, phase acceptance, and cleanup hashes do not exist.

Candidate 4 bases are under `harness/candidate4-original/` and beside the root controllers. Per-file unified diffs are under `harness/diffs/` and beside each root controller. `smoke-preparation.json` records the complete prepared-file hashes and invariants. Provisioning must still prove the reserved names and serial absent at execution time; this preparation supplies no ownership.

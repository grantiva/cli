# Task 8 lifecycle runtime2 attempt 3 harness correction

## Scope and finding

This is a harness-only correction. No product source or device state was changed. The controller stopped the attempt before this edit and retained its raw evidence at `findings/evidence/round4-smoke/03-lifecycle/remaining-helper-attempt3/`.

The attempt's live runner had the correct CLI parent, process-group relationship, frozen executable, hash, owned device, report output, and long-wait flow. The gate remained waiting because the CLI serialized the staged YAML mapping as `timeout` then `visible`, while the source file used `visible` then `timeout`. Byte hashes therefore differed even though the YAML documents were structurally equivalent. This is a harness serialization mismatch, not a product regression.

The controller subsequently recorded the exact owned CLI and runner, sent SIGINT, and allowed cleanup to complete. The preserved report is truthfully `interrupted`; the helper itself exited 1 because its gate had not accepted the reordered flow.

## Change

- The runner's `--output` path must now resolve exactly to the current case's requested report directory. Mere directory existence is no longer sufficient.
- Source and staged flow files are parsed document-by-document with macOS's installed Ruby/Psych YAML parser using `YAML.safe_load` with no permitted classes, symbols, or aliases.
- Structural document equality replaces byte equality, so mapping serialization order does not affect ownership binding.
- The generated flow must still contain `extendedWaitUntil`.
- The retained active-runner record includes the source and staged paths, both SHA-256 values, and `flowSemanticallyEquivalent: true`.
- All prior PPID, PGID, exact device, exact frozen executable path/hash, and filesystem-existence gates remain in force.

The pre-edit durable and mirror helpers are preserved under `.superpowers/sdd/2026-10-13-round4-fix-wave/task8-lifecycle-runtime2-attempt3-base/`, both with SHA-256 `0db355fe5255212436181c1b636d72de3eb338bfea3c65425d10dff34d597ab4`.

## Device-free verification

The focused Python test created a temporary frozen runner, exact current report directory, and source/staged YAML fixtures. It imported both the snapshot and corrected helper and produced:

- `RED pre-fix byte binding rejects reordered equivalent YAML`
- `GREEN reordered equivalent YAML accepted with both hashes recorded`
- `PASS semantically changed flow rejected`
- `PASS non-current report output rejected`
- `PASS durable/mirror byte identity`

Both corrected helpers passed `python3 -m py_compile`, and the durable diff passed `git diff --check`. The durable and mirror helpers are byte-identical with SHA-256 `9a59996cac5085fd978af2ef23c6d11784398a32154708e5fc6a0997afb21898`.

No live lifecycle acceptance claim is made; the corrected helper requires a fresh controller rerun.

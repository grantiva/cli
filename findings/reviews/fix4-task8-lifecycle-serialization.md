# Task 8 lifecycle runtime2 attempt 3 harness review

**Scoped verdict: APPROVED.** The serialization blocker described in `task8-lifecycle-runtime2-attempt3-report.md` is corrected safely by the reviewed diff. Mapping-key order can differ between the source and CLI-staged YAML without weakening the current-case binding, while semantically changed content remains rejected. No new defect was found in the scoped change. This was a static review only; no live lifecycle acceptance claim is made.

## Review

- `yaml_documents` parses each source and staged document through Ruby/Psych `YAML.safe_load` with no permitted classes, symbols, or aliases. Comparing the resulting structures ignores mapping insertion order but preserves scalar values, sequence order, document order, keys, and nesting, so a content change does not satisfy the gate.
- The staged runner flow must remain semantically equal to the current case's source flow and must still contain `extendedWaitUntil` before SIGINT.
- The runner's resolved `--output` path must now equal the current case's requested report directory exactly, and that directory must exist. An unrelated report directory cannot satisfy the gate.
- The retained `activeRunner` evidence preserves both source and staged paths and both byte hashes while explicitly recording semantic equivalence. The differing hashes therefore remain auditable rather than being presented as byte identity.
- The earlier PPID/current-CLI, PGID, exact owned device, frozen executable path, current executable SHA-256, and file-existence gates are unchanged by this diff.

No device command or test rerun was performed for this review, and no product or harness source was edited.

# CLI slice results: Round 4 coverage pass

Status: **PROVISIONAL, INCOMPLETE, AND NOT A CAMPAIGN PASS.** The controller is closing the current candidate incomplete/failing because of L86. This file records only the 40 CLI rows with fresh, clause-by-clause proposed-pass assessments. It does not grade unexecuted rows and excludes every verdict produced by the quarantined replay harness.

Frozen candidate manifest SHA-256: `d833797d30a794d8cfe9d2dc4646329d4f791667eb8dfa5d17cf417d827f744e`. Executable SHA-256: `1b6a973b63a750691bcb76a710a97f346d331fe44ef60f6c50bef0f6d35e4731`. Session: `cov4-cli`; API key unset; both runner-home variables bound to `/private/tmp/grantiva-round4-candidate3-9lkulx9q/runner-home` in approved-collector captures.

| ID | result | evidence | note |
|---|---|---|---|
| CLI-001 | provisional pass | findings/evidence/cov4-cli/CLI-001-rerun-1/ | Explicit clause assessment in verdict.md; pending controller final review. |
| CLI-002 | provisional pass | findings/evidence/cov4-cli/CLI-002-rerun-1/ | Explicit clause assessment in verdict.md; pending controller final review. |
| CLI-003 | provisional pass | findings/evidence/cov4-cli/CLI-003-rerun-3/ | 172/172 help pages; reruns 1/2 preserved as fixture failures. |
| CLI-004 | provisional pass | findings/evidence/cov4-cli/CLI-004-rerun-1/ | Explicit clause assessment in verdict.md; pending controller final review. |
| CLI-005 | provisional pass | findings/evidence/cov4-cli/CLI-005-rerun-1/ | Explicit clause assessment in verdict.md; pending controller final review. |
| CLI-006 | provisional pass | findings/evidence/cov4-cli/CLI-006-rerun-1/ | Explicit clause assessment in verdict.md; pending controller final review. |
| CLI-007 | provisional pass | findings/evidence/cov4-cli/CLI-007-rerun-1/ | Help-only lifecycle surface; no lifecycle action. |
| CLI-008 | provisional pass | findings/evidence/cov4-cli/CLI-008-rerun-1/ | Explicit clause assessment in verdict.md; pending controller final review. |
| CLI-009 | provisional pass | findings/evidence/cov4-cli/CLI-009-rerun-1/ | Explicit clause assessment in verdict.md; pending controller final review. |
| CLI-010 | provisional pass | findings/evidence/cov4-cli/CLI-010-rerun-1/ | Explicit clause assessment in verdict.md; pending controller final review. |
| CLI-011 | provisional pass | findings/evidence/cov4-cli/CLI-011-rerun-1/ | Explicit clause assessment in verdict.md; pending controller final review. |
| CLI-012 | provisional pass | findings/evidence/cov4-cli/CLI-012-rerun-1/ | Explicit clause assessment in verdict.md; pending controller final review. |
| CLI-013 | provisional pass | findings/evidence/cov4-cli/CLI-013-rerun-1/ | Explicit clause assessment in verdict.md; pending controller final review. |
| CLI-014 | provisional pass | findings/evidence/cov4-cli/CLI-014-rerun-1/ | Explicit clause assessment in verdict.md; pending controller final review. |
| CLI-015 | provisional pass | findings/evidence/cov4-cli/CLI-015-rerun-1/ | Read-only session query. |
| CLI-016 | provisional pass | findings/evidence/cov4-cli/CLI-016-rerun-1/ | Read-only session query. |
| CLI-017 | provisional pass | findings/evidence/cov4-cli/CLI-017-rerun-1/ | Explicit clause assessment in verdict.md; pending controller final review. |
| CLI-019 | provisional pass | findings/evidence/cov4-cli/CLI-019-rerun-1/ | Explicit clause assessment in verdict.md; pending controller final review. |
| CLI-020 | provisional pass | findings/evidence/cov4-cli/CLI-020-rerun-1/ | Init-only warning check; generated configs were never executed. |
| CLI-021 | provisional pass | findings/evidence/cov4-cli/CLI-021-rerun-1/ | Read-only doctor comparison. |
| CLI-023 | provisional pass | findings/evidence/cov4-cli/CLI-023-rerun-1/ | Generated config retained but never executed. |
| CLI-024 | provisional pass | findings/evidence/cov4-cli/CLI-024-rerun-1/ | Platform/init clauses pass; doctor nonzero reflects host JDK advice. |
| CLI-025 | provisional pass | findings/evidence/cov4-cli/CLI-025-rerun-1/ | Ambiguous Platform now appears under Advisory. |
| CLI-026 | provisional pass | findings/evidence/cov4-cli/CLI-026-rerun-1/ | Explicit clause assessment in verdict.md; pending controller final review. |
| CLI-030 | provisional pass | findings/evidence/cov4-cli/CLI-030-rerun-1/ | Explicit clause assessment in verdict.md; pending controller final review. |
| CLI-032 | provisional pass | findings/evidence/cov4-cli/CLI-032-rerun-1/ | Explicit flag wins over environment. |
| CLI-033 | provisional pass | findings/evidence/cov4-cli/CLI-033-rerun-1/ | Three failures plus no-file postcheck. |
| CLI-034 | provisional pass | findings/evidence/cov4-cli/CLI-034-rerun-1/ | Explicit clause assessment in verdict.md; pending controller final review. |
| CLI-035 | provisional pass | findings/evidence/cov4-cli/CLI-035-rerun-1/ | Explicit clause assessment in verdict.md; pending controller final review. |
| CLI-036 | provisional pass | findings/evidence/cov4-cli/CLI-036-rerun-1/ | File and line/column parser error captured. |
| CLI-037 | provisional pass | findings/evidence/cov4-cli/CLI-037-rerun-1/ | Android file and line/column parser error captured. |
| CLI-040 | provisional pass | findings/evidence/cov4-cli/CLI-040-rerun-1/ | Explicit clause assessment in verdict.md; pending controller final review. |
| CLI-041 | provisional pass | findings/evidence/cov4-cli/CLI-041-rerun-1/ | Explicit clause assessment in verdict.md; pending controller final review. |
| CLI-042 | provisional pass | findings/evidence/cov4-cli/CLI-042-rerun-1/ | Explicit clause assessment in verdict.md; pending controller final review. |
| CLI-043 | provisional pass | findings/evidence/cov4-cli/CLI-043-rerun-1/ | Both cross-platform flag legs captured. |
| CLI-123 | provisional pass | findings/evidence/cov4-cli/CLI-123-rerun-1/ | Help and frozen README agree on UIAutomator2. |
| CLI-124 | provisional pass | findings/evidence/cov4-cli/CLI-124-rerun-1/ | Help and frozen MCP documentation captured. |
| CLI-125 | provisional pass | findings/evidence/cov4-cli/CLI-125-rerun-1/ | Help and frozen hierarchy documentation captured. |
| CLI-126 | provisional pass | findings/evidence/cov4-cli/CLI-126-rerun-1/ | Isolated install was idempotent; stop found no session. |
| CLI-128 | provisional pass | findings/evidence/cov4-cli/CLI-128-rerun-1/ | Invalid platform emitted no JSON-RPC stdout. |

## Preserved non-results and fixture failures

- `findings/evidence/cov4-cli/_isolation-repair/` inventories the original 77 replay directories and 76 unsupported auto-generated verdicts. None is counted above.
- `CLI-003-rerun-1/` and `CLI-003-rerun-2/` are preserved failed Bash-fixture attempts; `CLI-003-rerun-3/` is the only proposed result.
- `CLI-038-rerun-1/` lacks the project precondition and has no proposed verdict.
- `CLI-039-rerun-1/` used the wrong YAML structure and has no proposed verdict.
- `_collector-fixround2/` and `_collector-fixround3/` preserve collector qualification failures and repairs; they are harness evidence, not product results.

## Remaining scope

Exactly **385 of the 425 directly executable CLI keys remain ungraded**. The six CLI-owned iOS actor handoffs (`CLI-048`, `CLI-049`, `CLI-061`, `CLI-064`, `CLI-066`, `CLI-083`) remain pending separately and are not double-counted. `B3-L29` still requires the controller build window. `B4-L85.5` remains the controller's final campaign-closeout join and retains the known failed source component. The current candidate is closing incomplete/failing because of L86, so no unexecuted key is inferred to pass.

## Evidence limits

Mechanical consolidation confirmed 40 distinct proposed-pass verdict files and existing evidence directories. Every listed directory contains command capture JSON with exit information. CLI-001/002 were accepted under the earlier collector and record candidate/executable hashes directly in command JSON; later captures use adjacent identity JSON files verified by the independently approved fix3 collector. These entries remain proposals pending controller review, not canonical campaign verdicts.

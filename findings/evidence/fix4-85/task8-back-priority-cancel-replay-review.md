# Task 8 iOS 26 Cancel replay helper review

## Verdict

**Preparation specification verdict: CHANGES REQUIRED.** The helper implements the requested bounded diagnostic replay, but it does not enforce the exact source-built binary hash named by the replay scope.

**Code quality/safety verdict: APPROVED apart from that provenance gap.** Routes, environments, timing records, fresh-output behavior and scoped cleanup are suitable for one controller-owned diagnostic run. This helper makes no acceptance or regrading claim.

## Finding

### P1 — exact binary identity is delegated to a mutable manifest value

The helper hardcodes source HEAD `6cad3f2b4081f0862cd0e93140eda11c2816b9ba` and owned UUID `DE2663B5-C24E-42DA-998D-20F7A80054B3`, but line 50 checks only:

`sha(binary) == cli["releaseBinary"]["sha256"]`

It never requires that declared and actual value to equal the replay's approved binary SHA-256 `f9b8161b00049b71b5ffb84176dad97232d89640e24182132e88daffb7c63c78`. A newly written source manifest could therefore bind another binary and still pass while `run.json` appears exact-source-bound.

Add an `EXPECTED_BINARY_SHA256` constant, require both the manifest value and freshly computed binary hash to equal it before any device command, and retain that literal in `run.json`. This is the only required change.

## Verified diagnostic contract

- Inputs require the non-final source schema, `task8Passed: false`, exact source HEAD, clean CLI checkout, unchanged runner/demo identities, complete source/installed app-manifest equality, exact owned iOS 26 UUID/name/runtime, `fix4-85`, live simulator identity, a fresh project session and nonexistent output.
- Both local commands and the MCP subprocess inherit the isolated runner/Maestro home, `fix4-85`, and API-key-unset environment. Commands name the exact UUID; no simulator create/delete or broad process action exists.
- MCP performs only readiness and `Deep Links → Edit Landmark → Name`. Its retained raw JSONL includes the pre-Cancel hierarchy returned by the placeholder-annotated Name tap.
- Direct requests match frozen production shapes: `GET /status`, preferred `POST /session/<sid>/elements`, broad elements lookup, `POST /session/<sid>/element/<first-id>/click`, and `GET /session/<sid>/source`. The preferred and broad predicates exactly match the production selector strings; the selected first element ID is persisted.
- Every direct WDA operation has its own request/result directory, method, URL, body, wall timestamps, bounded 1–30 second timeout, status/error and response size/raw bytes when a response exists. Lookup/click failures stop the replay; the two source outcomes are retained as diagnosis, so a first timeout cannot suppress the retry.
- The exact-device screenshot occurs after a successful click and before the 500 ms delay/source request. A second screenshot occurs after both bounded source attempts and before runner stop. The report correctly discloses that screenshot latency makes this a decomposition rather than an exact `UITools.tap` timing reproduction.
- `replay-result.json` says `acceptanceRegraded: false` and `originalFailurePreserved: true`; it reports both source attempts without grading L85 or replacing the original failure.
- `finally` closes the exact MCP process, validates the project session's platform/UUID before exact project stop, waits only on the recorded positive runner PID, and records session/PID absence plus primary/cleanup errors. Cleanup failure prevents a nominally successful replay result. Physical device cleanup remains controller-owned.

The durable `mcp_client.py` bounds each MCP call at 90 seconds and its close path at bounded waits. Local subprocesses and direct HTTP calls are also bounded. No unbounded device or network operation was found.

## Scope

This was a static review of the diagnosis, helper, report and preparation diff. I did not run the helper, issue a device command, build source, execute tests or modify product code.

## Scoped binary-binding fix re-review

**Final preparation specification verdict: APPROVED.** The revised helper has SHA-256 `12daecfc227bf7e52428b25b91d0c804f00727f22559889c81c4a4ec0127b397` and resolves the sole prior P1. It defines the approved candidate binary hash as the literal `f9b8161b00049b71b5ffb84176dad97232d89640e24182132e88daffb7c63c78`, requires both the manifest-declared hash and the actual binary-byte hash to equal that value, and performs those checks before the first device command. The retained `run.json` derives `binarySHA256` from the already validated binary, so the recorded identity is bound to the same approved value.

**Final code quality/safety verdict: APPROVED.** The scoped change introduces no new breakage: it replaces the manifest-controlled trust anchor with one immutable constant while preserving the replay sequence, evidence recording, timeouts and scoped cleanup. This remains static preparation approval; it does not claim that the replay ran or passed.

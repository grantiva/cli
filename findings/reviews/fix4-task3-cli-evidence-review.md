# Task 3 CLI evidence re-review — L79 warned optional command

Reviewed the newly retained execution artifacts under `findings/evidence/fix4-3-cli/raw-semantic-red/`, `raw-focused-green/`, and `raw-full-green/`. No tests were rerun by the reviewer.

## Verdict

**Replacement execution evidence approved; provenance gate resolved with a historical qualification.** The new directories contain actual stdout/stderr streams plus command, source revision, exit, timestamps, isolated runner-home path, and before/after home counts. They substantiate the base behavioral defect, focused fix behavior, and complete suite result. This approval does not recast the earlier summary files as raw proof and does not claim the overwritten initial `red.txt` was recovered.

## Evidence inspected

### Behavioral RED

`raw-semantic-red/metadata.txt` records the base-compatible collector test at source `63c9b45190e43bfb8aa239d0f9fcc75ec455dd72`, with `GRANTIVA_API_KEY` unset, a fresh isolated `GRANTIVA_RUNNER_HOME`, exit 1, and home count 0 before and after.

The retained stdout shows the test actually executed production collection and failed semantically:

- two commands survived instead of three;
- actions were `launchApp / assertVisible`, omitting the warned tap;
- the warning message was nil;
- XCTest reported one test with three assertion failures.

This is the required runtime RED rather than the earlier compile-only RED.

### Focused GREEN

`raw-focused-green/metadata.txt` records both focused commands at source `c1373f6c07bf97ec5cb7978d45c954902958c04a`, exit 0 for each, with the same isolated home remaining empty.

- `core.stdout.log` shows `testWarnedOptionalCommandIsRetainedWithItsError` executed and passed.
- `cli.stdout.log` shows `testWarnedFlowRendersWarningAndRemainsPassedInTextAndJSON` executed and passed.
- The corresponding stderr files contain successful build output and no test error.

The semantic details of warned/no-throw and failed/`ExitCode.failure` are asserted in the reviewed test source; the raw stream confirms that exact test passed.

### Full GREEN

`raw-full-green/metadata.txt` records `swift test` at the same fix head, with API key unset, isolated home `/tmp/grantiva-fix4-3-cli-raw-full-home.xAsad6`, exit 0, and home count 0 before and after. The 538,086-byte stdout stream terminates normally and reports:

- GrantivaMCPTests: 281 / 0 failures;
- GrantivaCoreTests: 968 / 0 failures;
- GrantivaCLITests: 662 / 0 failures;
- GrantivaAPITests: 101 / 0 failures;
- total across those targets: 2,012 / 0 failures.

The stderr stream contains only the successful debug build completion.

## Historical qualification

The original `focused-green.txt`, `full-green-and-home-proof.txt`, `review-fix-green.txt`, and rewritten `red.txt` remain authored summaries, not raw process captures. The first observed contents of `red.txt` were replaced rather than preserved byte-for-byte, so the initial compile-RED artifact is unrecoverable from this evidence package. The newly added append-only directories are genuine reruns and provide replacement proof; they do not repair or erase that earlier retention failure. Future raw captures must remain immutable, with any narrative summary stored separately.

## Remaining gates

This review clears only the CLI RED/GREEN provenance gate. Source/spec behavior and code quality were already approved in `task-3-cli-fix1-review.md`. Joint live acceptance, cleanup verification, CI, and merge remain owned and reviewed separately.

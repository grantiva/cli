# Task 9 source-verification window preparation

## Status and ruling

**PREPARATION ONLY.** The candidate fields remain `UNKNOWN`, Task 9 remains behind the Task 8 zero gate, and no command was run.

The smallest operational ruling is: after the controller records the green Task 8 zero gate and freezes the exact Task 9 candidate, but before general device dispatch or load-sensitive Android work, the controller may open one serial, read-only **source-verification window**. During that window it may run only the source tests, L53's explicitly required scratch runner build, and the one compile-only product row listed below, from the frozen source paths in the candidate manifest. It may create isolated temporary build/test homes and evidence files. It may not edit source/tests/docs, rebuild or repack the frozen Grantiva CLI/runner candidate for substitution, install a different runner into the frozen home, operate any device except the controller-reserved shutdown `cov4-android` precondition for `AND-111`, merge, tag, release, or use a campaign worktree as product source.

This resolves the conflict between the literal rows requiring fresh output and the slice briefs' blanket `do not build` language. Slice agents remain prohibited from ad hoc builds/tests; the controller schedules and records this one exception, then hands the resulting fresh evidence to the fixed owning keys. A command failure is that row's fresh non-pass evidence, not permission to fix or rerun in place.

## Frozen checkout ownership

- Swift/CLI/MCP tests run only in candidate `cli.repoPath` at candidate `cliSourceSHA`. They use the frozen manifest's toolchain inputs, `GRANTIVA_API_KEY` unset, and a distinct initially absent `GRANTIVA_RUNNER_HOME` and `MAESTRO_RUNNER_HOME` for every focused command and for the full suite.
- Go runner tests/vet run only in candidate `runner.repoPath` at candidate `runnerSourceSHA`, with caches disabled for the required uncached evidence. They do not use the CLI campaign checkout.
- Demo-source obligations use candidate `demo.repoPath` at candidate `demoSHA` for read-only inspection. No demo build is authorized by this window.
- `AND-111` runs the frozen candidate executable against a controller-created scratch copy of the frozen Android demo/project input. It is a product `grantiva build build` behavior check, not permission to build the CLI or runner source.

Before every command, record repository realpath, exact HEAD, empty porcelain status, candidate-manifest SHA-256, command argv/cwd/environment/start time, and the relevant source/input tree hash. Afterward record end time, exit, raw stdout/stderr, resulting status, and fresh-home contents. Any HEAD/status/hash drift closes the window and blocks the affected rows.

## Rows requiring fresh source execution

One fresh command may support multiple listed rows only when its raw assertions cover each row's literal clauses; each row still gets its own verdict/evidence mapping.

### Frozen CLI Swift source

The following groups explicitly require source-test or fresh focused/full evidence:

- `B4-L53.E`, `.F`, `.P1`–`.P5`: runner/CLI empty-device, preserved `--udid`, unknown `--serial`, malformed UDID, target-option and canonical-cycle controls. The runner-side Go cases described by `.P2`/`.P3` come from the frozen runner checkout; the Swift target/session cases come from the frozen CLI checkout.
- `B4-L67.1`–`.4`: doctor ambiguous-platform text/JSON/advisory/exit and unchanged run rejection. `.4` expressly requires meaningful doctor tests; the same focused output may substantiate the test siblings in `.1`–`.3` alongside fresh public commands.
- `B4-L74.1`–`.4`: public ISO-8601 statement plus the preserved semantic JSON encoder test. Source inspection supplies `.1`/`.2`; a focused JSON-output test supplies `.3`; fresh session JSON evidence remains separate for `.4`.
- `B4-L75.1`–`.5`: final merged `RunnerSessionOutputTests` nested-cycle, root/screens/absolute-path, `/tmp` and `/private/tmp` controls. Fresh scratch CLI commands remain row evidence in addition to the focused test.
- `B4-L81.1`–`.7`: production-entry `DoctorTests` order, text/JSON, owned/unowned/no-default/no-list branches. These are fake/source fixtures and must not query owner simulators.
- `B4-L82.1`, `.2`, `.5`: exact-candidate production regression, sibling contracts, focused and full fresh-home Swift output.
- `B4-L84.1`, `.2`, `.4`: startup and stop/orphan production regressions, ownership-safe siblings, focused and full fresh-home Swift output.
- `B4-L85.2`, `.3`, `.5`: selector and transport fixtures plus separate focused and full fresh-empty-home Swift suites with the API key unset. `.5` also remains a controller closeout provenance/join row under the approved non-circular ruling.
- `B4-PC.5` source half: completed/failed/incomplete/missing launch-report source tests. Its owned-simulator half remains in the later iOS slice.
- `B4-EJ.3` source component: exact alias/split/canonical-path tests. Its two `B3-L20` platform halves remain later join inputs.

Run focused filters from separate homes. The exact filter inventory must be frozen before execution by resolving the named test classes/cases above in the candidate tree; at minimum it includes `TargetOptionsTests`, `SimulatorCommandTests`, `RunnerSessionOutputTests`, `DoctorSelectionTests`/`DoctorTests`, `JSONOutputTests`, the L82 foreground/attachment suites, the L84 forward-cleanup suites, `WDAClientTests`, and the completed-launch-report suites. Use this command shape for each frozen filter, replacing only the recorded filter and unique paths:

```sh
env -u GRANTIVA_API_KEY \
  GRANTIVA_RUNNER_HOME=<new-empty-window-root>/<filter>/runner-home \
  MAESTRO_RUNNER_HOME=<new-empty-window-root>/<filter>/maestro-home \
  swift test --filter '<exact candidate test class/case>'
```

Then run one independent full suite from another empty pair:

```sh
env -u GRANTIVA_API_KEY \
  GRANTIVA_RUNNER_HOME=<new-empty-window-root>/full/runner-home \
  MAESTRO_RUNNER_HOME=<new-empty-window-root>/full/maestro-home \
  swift test
```

Record per-target counts, total count, failures, raw streams, exit, and proof that both homes were absent/empty before and remain empty afterward. The full run supports the rows that literally require full output; it does not replace missing focused assertions.

### Frozen runner Go source

- `B4-L53.P2` and the runner portion of `.P3`: real CLI empty/whitespace `--device` and preserved empty/whitespace `--udid`, with unknown `--serial` control; `.P3` also needs the public installed-runner invocation, but no new runner may replace the frozen one.
- `B4-L83.1`, `.2`, `.4`: both UIAutomator2 and DeviceLab cleanup callbacks, owned-port/no-remove-all siblings, focused uncached tests, full uncached tests and vet. `.4`'s merge/repack/smoke clauses are current-candidate provenance joins, not authorization to repack during Task 9.
- `B4-PC.9`–`.13`: production deadline/cancellation, stable-target second read, ordinary soft deadline, keyboard step context and long-press sibling tests.

Before testing, run `go list ./...` once as a read-only inventory operation from the exact frozen runner HEAD and persist its ordered stdout plus command metadata and hash. Reject an empty inventory, duplicates, package paths outside the frozen module, or any HEAD/status change between inventory and execution. Expand those frozen output lines into literal argv entries; do not pass `./...` to `go test` or `go vet`.

After resolving the exact focused candidate package paths and the complete package inventory, run commands shaped as follows, with each `<package-N>` supplied as a separate literal argv element:

```sh
env GOCACHE=<new-empty-window-root>/go-focused-cache \
  go test -count=1 '<exact package(s) containing L53/L83/PC9-PC13 tests>'
env GOCACHE=<new-empty-window-root>/go-full-cache \
  go test -count=1 <package-1> <package-2> ... <package-N>
env GOCACHE=<new-empty-window-root>/go-vet-cache \
  go vet <package-1> <package-2> ... <package-N>
```

The `go list ./...` inventory operation is recorded but is not test evidence. The controller reviews and freezes its resolved lines before launching tests. No wildcard or recursive pattern may reach the executable test/vet argv. Persist the exact resolved package/test-name manifest, `go env`, every package's output and exit, aggregate command exit, cache paths and before/after status. `-count=1` is mandatory; old Go outputs and Task 8 reports are contextual provenance only.

`B4-L53.P3` alone also authorizes the literal task-scoped runner build required by its criterion. Build from the same frozen runner checkout into a new scratch path, never into the frozen release home:

```sh
env GOCACHE=<new-empty-window-root>/l53-build-cache \
  go build -o <new-empty-window-root>/l53-runner-home/bin/grantiva-runner .
<new-empty-window-root>/l53-runner-home/bin/grantiva-runner \
  --platform ios --device "" test findings/fixtures/optional-miss.yaml
```

Record the built binary hash/source HEAD, exact exit 64 and stderr, and proof that the failure precedes signing/device discovery. This scratch binary is evidence for `B4-L53.P3` only and must never replace the manifest's frozen installed runner or satisfy candidate provenance.

### Compile-only product row

`AND-111` literally requires `build build` with no `--device`, a config naming an existing **shut-down** `cov4-android`, successful compilation, no boot, and unchanged `adb devices`. Absence of that AVD is not equivalent to the row's shutdown-device precondition. Before opening the window, the controller must create and record the literal `cov4-android` AVD under the approved ownership/reservation flow, leave it shut down, and verify its exact name/identity. The AVD remains controller-owned and no command in the source window may boot, start, stop or delete it. General Android slice dispatch and all load-sensitive work remain later.

Schedule the row at the end of this window with that literal shutdown precondition:

```sh
env -u GRANTIVA_API_KEY \
  GRANTIVA_RUNNER_HOME=<frozen-runner-home> \
  MAESTRO_RUNNER_HOME=<frozen-runner-home> \
  <frozen-cli-binary> build build
```

The cwd is the isolated scratch Android project/config bound to the frozen demo input, and its config must literally name `emulator: cov4-android`. Capture AVD identity/state and `adb devices -l` immediately before and after; require the AVD remains shut down and both device inventories are exactly equal. This command is expressly allowed to compile the scratch Android app because compilation is the behavior under test. It must not rebuild or replace the frozen Grantiva CLI/runner candidate, install an app, boot or launch the AVD, or perform another device operation.

## Source inspection and provenance rows that do not authorize another build/test

- `B4-L70.1`–`.3` are documentation/implementation/migration inspections and request no runtime change. Read the frozen CLI checkout and retained migration evidence; do not invent a test command.
- `B4-L83.4`, `B4-L84.4`, and `B4-L85.5` include merge, CI, repack/freeze and Task 8 smoke provenance. The controller joins the newly frozen candidate manifest and its hash-bound Task 8 gate with this window's fresh tests. Task 9 must not rebuild/repack the candidate to satisfy them.
- `B4-L85.4` includes frozen demo-source inspection plus later iOS live behavior. Inspect only candidate `demo.repoPath`; the iOS result remains device-owned.
- The inherited source-criterion section is governed by the matrix text at lines 941–942 and the later round-3 source-check ruling: locate the required test/source at the frozen HEAD, with no `swift build`, `swift test`, or `go test` merely because an inherited row says “test.” `B3-L31` inspects fresh-home CI configuration and the required current CI run; it does not trigger a local suite. `D2-32` and runner-install rows exercise the frozen executable/home contract, not a source build.

Historical RED/GREEN output, implementation reviews, CI and Task 8 smoke may establish lineage and candidate provenance, but cannot populate a Task 9 result. Every executable source-test row above needs fresh raw output from this window; every inspection row needs a fresh frozen-path inspection record.

## Handoff to slices

Freeze a `source-window-manifest.json` containing candidate hash, repo HEADs, every command/result/raw-stream hash, fresh-home/cache checks, exact row-to-command mapping, and final clean statuses. Independently review it before device dispatch. CLI owns the listed CLI verdicts, iOS owns `B4-PC.5` and the joined/platform rows as already assigned, Android owns `AND-111`; the controller supplies evidence without changing key ownership or denominators.

The ordinary slice prohibition resumes when the window closes. No slice may rerun a source test/build, substitute a campaign checkout, or use an old pass to fill a blank result without a new explicit controller ruling.

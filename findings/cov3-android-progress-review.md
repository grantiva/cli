# Interim review — Android g9/g10 and mapped coverage verdicts

Scope: read-only review of the specified new Android verdicts and evidence changes since `d851bb5a` in `cov3-android`: AND-075; AND-202/203/204/205/208/209/210/211/214; B2-K01; and N-11. The still-running VRT work is excluded. This is not whole-slice completion approval. No device/tool rerun or source edit was performed.

## Findings

### Important — AND-075 does not contain the required flow-failure path

The matrix requires `run --logs` to terminate by success, flow failure, and Ctrl-C, with no matching `adb ... logcat` process after each path (`coverage-matrix.md:642`). `AND-075-rerun` contains two successful `.maestro/08-caching.yaml` runs and one SIGINT run of `18-long-wait.yaml`. Its only exit-1 capture, `01`, also runs the passing caching flow and fails before flow execution because adb cannot start (`AND-075-rerun/01.err`: `could not install *smartsocket* listener: Operation not permitted`). No command references `.maestro/99-crash.yaml`, and no raw output contains a flow failure. The ledger's claim that “crash failure exited 1” is unsupported. Success and SIGINT cleanup are supported; the row must remain partial until a genuine flow-failure terminal path is evidenced.

### Important — AND-210 changes the required initial state

The matrix requires `doubleTapOn: {id: "gesture-pad"}` to yield `Double taps: 1`, `Taps: 0` (`coverage-matrix.md:754`). The round-3 flow first performs a normal `tapOn` and asserts `Taps: 1`, then double-taps and asserts `Double taps: 1` and `Taps: 1` (`CF-03-gesture-lab-taps/run.out`; the input is also preserved canonically in `report/flow-000.json`). This is useful evidence that the double tap does not add ordinary taps, but it does not produce the matrix's exact `Taps: 0` state. Grade it as input-variation/partial evidence unless the matrix expectation is formally changed.

### Important — B2-K01 is substantially incomplete

B2-K01 requires live, summary, and runner-log descriptions for index, point, percent start/end, absolute start/end, point-based `doubleTapOn`, and point-based `longPressOn`; no blank tap description; identical descriptions on iOS 26, iOS 27, and Android; and the named runner unit-test results (`coverage-matrix.md:1239`). The cited Android evidence proves:

- indexed text tap in `CF-01-selectors`;
- percent point tap in `CF-04-point-taps`;
- percent start/end swipe in `CF-05-swipe-forms`;
- no blank tap line in those captures.

It does not exercise absolute start/end, point-based double tap, or point-based long press. The gesture flow uses `id="gesture-pad"`, not `point`. The cited directory is only `CF-01-selectors`, although the note also claims point and swipe evidence from other directories. It supplies no iOS description comparison and no runner unit-test evidence. The pass should be downgraded to partial/blocked, and any eventual evidence list must cite all contributing captures.

### Moderate — AND-202 uses the exact selector variant instead of the specified text-map input

The matrix input is `tapOn: {text: "Lake Tahoe"}` (`coverage-matrix.md:746`). The captured flow uses `{text: "Lake Tahoe", exact: true}`. It successfully opens the expected detail, and other steps prove string selectors, but the exact flag changes the requested selector semantics. This capture should be described as variant evidence rather than exact execution of AND-202.

### Moderate — AND-209 and N-11 prove acceptance, but not the stated landing result

`CF-04-point-taps` proves both `100%,100%` and `0%,0%` steps pass without an out-of-bounds error. There is no assertion or hierarchy/screenshot interpretation after either edge tap showing where it landed. The matrix explicitly says “passes and lands on screen” for AND-209 and N-11 (`coverage-matrix.md:753,1177`). The present evidence supports parser/execution acceptance and absence of a bounds error; the landing clause remains unobserved.

### Minor — evidence packages do not preserve the source YAML verbatim

The evidence directories preserve commands, terminal streams, runner logs, and `flow-000.json`, whose canonical `yaml` fields are enough to verify most individual steps. The command records point to flow files under a scratch project, but the original YAML inputs are not copied into the evidence directories. This matters for selector-form distinctions such as AND-202 and for future provenance if the scratch tree disappears. Preserve the exact input flow or a checksum with source provenance in later batches.

## Verdicts supported by the reviewed raw evidence

- AND-203: `assertVisible: id="clock"` and `tapOn: id="clock"` both pass on Caching Demo.
- AND-204: whole-value regex succeeds and bare `Lake` correctly does not match `Lake Tahoe`.
- AND-205: regex positive, exact-literal negative, and exact Lake Tahoe navigation all pass; no unsupported/ignored exact warning appears.
- AND-208: the 50%,50% tap is followed by successful `Last tap: center` and `Taps: 1` assertions.
- AND-211: id-based long press is followed by `Long presses: 1`.
- AND-214: the selector flow contains successful visible assertions using string, text-map regex, and id forms.
- AND-075's success and SIGINT subcases are supported, including exit 0/130 and the post-run no-logcat process checks.
- AND-209/N-11's narrower no-bounds-error execution claim is supported.

## Artifact/table integrity notes

- The reviewed rows each appear once in the active table; no duplicate IDs were introduced for this subset.
- The current aggregate count is arithmetically consistent with the 65 table rows (60 pass, 1 fail, 4 blocked), but it inherits the overstated passes above.
- `controller-g9-safe.sh` and `controller-g10-safe.sh` are preserved, and the new capture directories use separate paths rather than overwriting the earlier AND-075 attempt. AND-075 correctly cites `AND-075-rerun`; the first attempt remains preserved.

## Interim disposition

AND-203/204/205/208/211/214 are supported as graded. AND-075, AND-210, and B2-K01 are not supported as full passes against the exact matrix. AND-202 is a changed-input variant. AND-209 and N-11 still lack observable evidence for the landing clause. VRT was not reviewed.

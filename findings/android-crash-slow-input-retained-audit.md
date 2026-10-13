# Android crash, slow-input, and scroll retained-evidence audit

Runtime evidence is current round 3. Runner source is `/Users/kyle/Developer/maestro-runner/.worktrees/release-round3b` at `fd9d8e8`.

## B2-L01: partial

`S2-01-inputtext-three-runs-rerun1` supplies the exact `03-edit.yaml` three-run leg: all three exit 0 and pass. The retained reports preserve the input step and client logs, and exact-head source has the required request-deadline tests in `pkg/uiautomator2/request_deadline_test.go` plus append-timeout handling tests in `pkg/driver/uiautomator2/input_append_test.go` and `input_timeout_test.go`.

It does not close the full compound row. The summary's GPU field is empty and the retained provenance does not establish the required software/lavapipe resolution; this directory also lacks the required stock-set/10-seed-many join and the explicit timeout-after-text-present versus timeout-without-text runtime/source assertions mapped clause by clause. Keep partial rather than infer these from three passing edits.

## B2-L02: strong source and crash-runtime support, but exact row runtime is incomplete

The recent `B3-L49-L50-crash-waits-rerun1` demonstrates 15 consecutive crash-on-launch variants failing with the `LANDMARKS_CRASH_ON_LAUNCH` RuntimeException in roughly 4.1–4.7 seconds wall time, never passing a selector step. This supports the corrected launchApp-or-first-step outcome and the wall threshold.

Exact source semantics are present:

- `pkg/driver/uiautomator2/crash_during_find_test.go`: blocked first find fails with app_crash within two seconds, looser match after death cannot pass, slow live find passes, prompt match after death fails, and page-source fallback after death fails;
- `crash_replay_test.go`: a previously missed crash cannot let later steps pass;
- `launch_first_frame_test.go`: crash before first frame fails launch promptly and crash-cancelled lookup capture is bounded.

The retained recent batch is not the exact `99-crash.yaml` three-run input and does not expose an `am_crash`-to-failure delta for each run or prove the named first-assert timing when launchApp succeeds. Keep partial. Smallest gap is an exact current three-run 99-crash timing summary joined to these source assertions; the 15-run launch-crash batch need not be repeated.

## B2-L03: source implementation covered; device comparison runtime missing

Exact-head tests satisfy the named semantic clauses: `bare_scroll_verify_test.go` asserts list-relative drag geometry and tops up a half-distance move; `bare_scroll_test.go` exercises repeat landing; the uiautomator2 gesture logging tests preserve pointer action bodies. Current evidence reviewed here does not contain the required 3x software-rendered plus 3x host-GPU `10-seed-many` comparison with last-visible rows and per-step row advances. Keep partial. This row needs the comparative inventories, not another generic successful stock run.

## B2-L05 and B3-L05: partial

The S2-01 directory supplies three successful exact `03-edit` runs and their client logs. The 15 recent crash runs all fail well under 12 seconds and preserve failure screenshots. Exact runner tests cover first lookup after launch, prompt launch crash, and bounded screenshot/hierarchy capture after a crash-cancelled lookup (`launch_first_frame_test.go`).

Missing runtime clauses remain: decoded first `POST /element` and `tapOn Deep Links` timings for all three edit runs, three executions of the explicit optional `No Such` 404 flow, a stock-wide first-lookup maximum, and exact 99-crash `am_crash`/capture timing. B3-L05 additionally requires the logged session-start settings and waitForIdleTimeout override proof. Neither row should be graded from exit codes alone.

## B2-L06 and B3-L06: partial

The recent crash batch includes count/page-source/not-visible families and all fail at launch with app_crash; it does not use the matrix's exact `{index}`, `below`, `width`, and tap-fallback fixtures. Exact-head source strongly covers the shared safety property (notably `TestPageSourceMatchOnDeadAppFailsWithAppCrash`, prompt/looser match checks, and count/wait held-source tests), so a launch-time failure in exact selector fixtures may legitimately join these tests for the selector half under B3-L06's explicit conditional.

No retained current directory reviewed here proves all four exact fixture inputs three times each or the required live stock-set control. B2-L06 also names only three selector variants with exact timing. Keep both partial; the minimal runtime is the exact variant manifest/results, not a repeat of the unrelated 15 crash-wait forms.

## B2-K107-a reconsideration

The row does permit two implementation policies: remove a device lock whenever a run ends, or retain it only while the device exists and prune it with device-home deletion. It does not require a separate product implementation for every termination route. However, its explicit input still says run, then teardown/delete, then list locks, and its acceptance text separately requires delete behavior, unlink-race behavior, unaffected install locks, and the three named tests.

The prior partial disposition remains appropriate but the gap is narrower than “every lifecycle path on both platforms.” Current iOS stop and Android post-run evidence prove release-on-end; exact tests prove release, unlink-race concurrency, and deleted-home pruning; Android inventory proves install locks unaffected. What is not yet explicit in the reviewed current artifacts is a retained teardown/delete lock inventory for each platform named by the row input (or a documented current artifact showing that inventory). One such current per-platform lifecycle inventory is enough; separate normal, Ctrl-C, and teardown repetitions are not all required if the selected release-on-end policy and common release path are established.

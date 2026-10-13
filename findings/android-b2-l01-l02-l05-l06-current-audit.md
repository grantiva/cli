# Android B2-L01/L02/L05/L06 current-round audit

Runner source is
`/Users/kyle/Developer/maestro-runner/.worktrees/release-round3b` at
`fd9d8e8`. Only round-3 runtime is used.

## B2-L01 — supported

`S2-01-inputtext-three-runs-rerun1` is the exact `03-edit.yaml` three-run leg:
all three runs pass, and `inputText " Renamed"` takes 2.0, 1.9, and 2.1
seconds, well within the step timeout. Its archived owned-AVD `config.ini`
records `hw.gpu.enabled=no` and `hw.gpu.mode=auto`. The current full-stock run
`D2-02-stock-ready-pass-rerun1` passes all twelve configured flows, including
`03-edit` and `10-seed-many`.

Exact-head semantic assertions close the branches impractical to force in a
device run:

- `pkg/uiautomator2/request_deadline_test.go` verifies an `/actions` response
  after 12 seconds succeeds under a 30-second step context, a never-answering
  request fails at the step deadline rather than ten seconds, and cancellation
  aborts an in-flight request.
- `pkg/driver/uiautomator2/input_timeout_test.go` verifies timeout-after-text-
  present passes with the late-response note, unchanged text fails once with
  the UIAutomator2 timeout named, and the deadline grows with text length.

This meets the runtime and named source-test clauses. The earlier audit's empty
GPU summary was a wrapper extraction issue; the archived config and provenance
note explicitly preserve the required software-rendered AVD setting.

## B2-L02 — partial; exact runtime complement remains

Current evidence strongly supports the fixed behavior. In
`B3-L49-L50-crash-waits-rerun1`, fifteen crash-on-launch variants fail at
`launchApp` with `error.type=app_crash`, the exact
`LANDMARKS_CRASH_ON_LAUNCH` cause, failure captures, and roughly 4.1–4.7 second
wall times; none passes a selector step. `N2-13-crash-wait-complements-rerun1`
adds scroll and animation first-wait forms, both failing at launch in under
five seconds with their waits skipped.

`pkg/driver/uiautomator2/crash_during_find_test.go` exactly covers a first
`FindElement` held ten seconds while the process dies, the under-two-second
`app_crash` result, and rejection of a looser match found after death.
`wait_crash_test.go`, `crash_replay_test.go`, and
`launch_first_frame_test.go` cover concurrent polling, re-check-before-pass,
and bounded post-cancellation failure capture.

The literal row still requests three runs of the stock `.maestro/99-crash.yaml`
with per-run step/flow/wall and `am_crash`-to-failure timing. The retained
crash variants are semantically equivalent but not that exact input. Smallest
gap: run only stock `99-crash.yaml` three times and preserve those decoded
timings; no additional source work or broad crash family rerun is needed.

## B2-L05 — partial

The three exact edit runs above prove the visible first interaction and typing
path succeeds, and the recent crash runs prove repeated `app_crash` wall times
under twelve seconds with failure captures. Exact-head launch/find tests cover
prompt first lookup and bounded screenshot/hierarchy work after cancellation.

The retained evidence does not decode, for each edit run, the first
`POST /element` duration and the first `tapOn "Deep Links"` duration against
the row's <2s/~3s bounds. It also lacks the explicit absent `No Such` 404 probe
three times and an `am_crash`-to-capture delta for the exact stock crash input.
Smallest complement: extract the edit client-log timings if already present,
then run only the absent-element probe and exact `99-crash` timing legs still
missing. Exit-zero edit summaries alone do not close those thresholds.

## B2-L06 — partial

Exact-head `pkg/driver/uiautomator2/pagesource_crash_test.go` covers relative,
nonzero-index, and size selectors for both `assertVisible` and `tapOn`: a held
page source is cancelled within two seconds, a matching launcher page source
after death still yields `app_crash`, and a live slow match remains valid.
`crash_during_find_test.go` supplies the common no-post-death-pass invariant.

Current crash runtime includes page-source/count families but not the row's
exact three scratch variants: `{text: Landmarks, index: 0}`, the specified
`below:` selector, and the matching `width:` selector, each three times with
crash-relative timing. Smallest gap: those nine exact runs with their frozen
fixtures, first-step outcomes, `error.type`, and crash-to-failure deltas. The
existing broad crash batch and source assertions should be joined rather than
repeated.

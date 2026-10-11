# `run` leaves its takeScreenshot shots and failure screenshots in `.grantiva/captures`, and `diff approve`/`diff compare` then treat them as screens

Severity: wrong-result
Component: cli
Platforms: ios (seen on iOS; Android uses `.grantiva/captures/android` with the same logic, not tested)
Rows: IOS-092 (ios); B-I16.2 output shows the same set (findings/evidence/cov-ios/B-I16.2/legacy.out); split from cluster C82 run-artifacts-treated-as-screens (trace shots as screens is K82-a)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
README:472: "Local baselines are stored in `.grantiva/baselines/`"; `diff approve` "Promote current captures to
baselines" (README:316). Matrix IOS-092: after `diff capture`, `diff approve` writes the configured screens' baselines.
The visual-diff set is the configured `screens:` (README:132-149), not whatever else sits in the directory.

## Actual
Fresh project copy (fix1/): a failing `run` and a passing `run`, then `diff capture`, `diff approve`, `diff compare`:
```
$ ls .grantiva/captures      # after the two runs (3-ls-captures.out)
01-browse-cmd-003-Home.png
01-browse-cmd-007-Landmark Detail.png
failure-1791709614.png
$ grantiva diff approve      # 6-approve.out, exit 0
Approved 8 screens as baseline
  • 01-browse-cmd-003-Home
  • 01-browse-cmd-007-Landmark Detail
  …
  • failure-1791709614
```
`diff capture` itself captured only the 5 configured screens (4-diff-capture.out) but left the run's files in place;
`diff compare` then compares 8 "screens" (8-compare.out). In the longer-lived slice project the same led to 13
approved and compared screens, including five `failure-…` shots (B-I16.2/legacy.out).

## Repro
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-k82b
unset GRANTIVA_API_KEY
rm -rf /tmp/k82b && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/k82b && cd /tmp/k82b/ios   # 4e49dc4
UDID=$(grantiva simulator ensure --name "fix-k82b iPhone 17" --runtime 26.0)
grantiva build install --simulator "$UDID" --no-launch
grantiva run --no-build --simulator "$UDID" --flow .maestro/coverage/02-exact-negative.yaml   # fails: failure-<ts>.png
grantiva run --no-build --simulator "$UDID" --flow .maestro/01-browse.yaml                    # 2 takeScreenshot shots
grantiva diff capture --no-build --simulator "$UDID"
grantiva diff approve; ls .grantiva/baselines
grantiva diff compare | head -4
grantiva simulator teardown --session-id fix-k82b
```
Today: `Approved 8 screens`, baselines include `failure-<ts>.png` and the two `01-browse-cmd-…` files.

## Evidence
- findings/evidence/cov-ios/IOS-092/commands.txt, fix1/1-run-fail.err (line 73: `Failure screenshot:
  .grantiva/captures/failure-1791709614.png`), fix1/3-ls-captures.out, fix1/4-diff-capture.out,
  fix1/5-ls-captures.out, fix1/6-approve.out, fix1/7-ls-baselines.out, fix1/8-compare.out
- findings/evidence/cov-ios/B-I16.2/legacy.out (13 screens)

## Suspected cause
- One directory for two purposes: `Sources/GrantivaCLI/RunCommand.swift:243-245` sends a `run` without
  `--report-dir` to `DiffCommand.captureDirectory(for:)` (`.grantiva/captures`, DiffCommand.swift:666-668), and
  RunCommand.swift:152 writes `failure-<ts>.png` there.
- `diff capture` overwrites only its own screens and removes nothing else.
- `diff approve` (DiffCommand.swift:456-457) and `diff compare` (:396) take every `.png` in the directory as a
  screen; there is no manifest of what the last `diff capture` produced.

## Acceptance criteria
- Re-running the repro: `diff approve` approves exactly the 5 configured screens; `diff compare` compares exactly
  those; no `failure-*` or `01-browse-cmd-*` baseline is written.
- Either `run` writes its captures and failure shots somewhere `diff` does not read (for example
  `.grantiva/runs/<ts>/`), or `diff capture` records a manifest (or clears stale files) and approve/compare use only
  the manifest. Whatever is chosen, README (`--snapshot`, failure screenshot, `diff approve`) says where each kind of
  file goes.
- Existing baselines named like old run artifacts are not silently deleted; at most a note lists them.
- GrantivaCLITests/DiffCommandTests: a capture directory with configured screens plus `failure-1.png` and
  `flow-cmd-003-Home.png` approves and compares only the configured screens.

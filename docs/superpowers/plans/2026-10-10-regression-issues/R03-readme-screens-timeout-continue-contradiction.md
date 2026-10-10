# README contradicts itself on whether `--timeout` and `--continue-on-failure` apply to `screens:`

Severity: doc
Blocking: no
Platforms: cli, ios, android
Found by: CLI slice, brief row `C26` (findings/cli-results.md, Step 1 and "Regressed detail"). Original brief: C26 (`plans/2026-10-09-qa-issues/C26-document-run-continue-snapshot-timeout.md` (last round's files are on branch `qa-campaign`, commit 8084069; exported copy at `~/.grantiva-qa/briefs/docs/superpowers/`)); related: C04.
Binary: grantiva 2.1.0 at a278b77, grantiva-runner 1.1.28-grantiva.8; no device (README text only)

## Expected
C26's third criterion: "Note that until C04 is fixed, these flags apply only to `flows:`/`--flow`; say so, or drop the
note once C04 lands." C04 has landed according to README:101, so the old note should be gone and the README should
say one thing.

## Actual
README:99 still carries the pre-C04 note, two lines above the post-C04 text that contradicts it:
```
README.md:99:  `--continue-on-failure` and `--timeout` apply to flow files (`flows:` in the config, or `--flow`). A suite that runs only the configured `screens:` does not read these two flags: it uses a fixed 300 s timeout.
README.md:101: ... `--timeout` and `--continue-on-failure` also apply to `screens:`; with `--continue-on-failure` a failed screens session is reported and the configured flows still run. Screens run as one flow, so a failed screen stops the remaining screens; the flag lets the configured flows run afterwards.
```
C26's other criteria hold: README:95-97 describe `--snapshot failure|trailing|full`, `--continue-on-failure`
(fail-fast default) and `--timeout` (default 600, minimum 30, ignored under `--keep-alive`); `run --help` says
"Minimum 30."; `run --timeout 0 --no-build` exits 64 with `Error: --timeout must be at least 30 seconds.`

This pass did not run a `screens:` suite with a short `--timeout` or with `--continue-on-failure`, so it did not
confirm on a device which of the two lines matches the binary (the CLI slice marked C04 not-verifiable-here).

## Repro
```
cd /Users/kyle/Developer/grantiva-cli        # or a checkout at a278b77
sed -n '99p;101p' README.md
grep -n -- '--continue-on-failure\|--timeout' README.md | sed -n '1,20p'
```
Line 99 says the two flags do not apply to `screens:`; line 101 says they do.

## Evidence
- findings/evidence/cli/C26.txt (README grep, `run --help` excerpt, `--timeout 0` exit 64, `sed -n '99p;101p'`)
- findings/cli-results.md, C26 row and "Regressed detail"; C04 row (not-verifiable-here)

## Suspected cause
Docs only. The C04 fix added the sentence at README:101 but did not remove the paragraph at README:99 that C26 had
asked for "until C04 is fixed".

## Acceptance criteria
- `grep -n "fixed 300 s timeout" README.md` finds nothing, and README:99's paragraph is removed or rewritten to agree
  with README:101.
- Before choosing the wording, confirm the behaviour on one device: a `screens:`-only run with `--timeout 30` and a
  screen that waits longer is killed at about 30 s (not 300 s), and with `--continue-on-failure` a failed screens session
  is reported and the configured flows still run. The README states whichever is true.
- README:95-97 and `run --help` keep their current `--snapshot`, `--continue-on-failure` and `--timeout` text.

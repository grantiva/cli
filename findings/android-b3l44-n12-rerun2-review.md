# Android B3-L44 / N-12 rerun2 review

Evidence: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B3-L44-N12-capture-equivalence-rerun2`.
Candidate CLI binary hash is the required
`3f3293aaf1522fefe8d46457370b32a20fa8c657461bf32af086e75a754a73f8`;
runner source is `fd9d8e8`.

The wrapper's exit 1 is a decoder error, not a command failure. It expected a
boolean `screens[].passed`; the real compare schema has top-level
`passed: true` and `screens[].status: "passed"`. The additive
`posthoc-decoded.json` reads the retained documents without changing them.

## N-12 [android]: PASS

- Interactive MCP capture exits 0 and returns five screens from the live
  `emulator-5554` session. Every recorded action is `passed`.
- Those exact five PNGs become the baseline. Three subsequent CLI captures on
  the same live serial each retain five PNGs. Each of the three compare JSON
  documents has top-level `passed: true` and 5/5 screen statuses `passed`.
- Pixel differences are zero or `0.00004359567901234568`, comfortably inside
  the configured `0.02` threshold. This includes placeholder/navigation text
  because all configured steps pass before each capture.
- The MCP response identifies the live session's serial, and the iOS half is
  independently retained at `cov3-ios-attempt109b`/`109c` with its deliberately
  different configured simulator, so the both-platform live-session override
  behavior is covered.

## B3-L44 [android]: PASS

- Home is an actual app capture 3/3. MCP Home is 125,344 bytes; CLI Home is
  125,344, 125,377, and 125,377 bytes. Maximum size delta is 0.0264%, below the
  required 10%, and Home compares pass in all three runs.
- Launch steps complete in 1.639–1.654 s. The literal clause concerns the
  *added first-frame wait*, not total app launch time. Exact runner test
  `/Users/kyle/Developer/maestro-runner/.worktrees/release-round3b/pkg/driver/uiautomator2/launch_first_frame_test.go:112`
  proves the screenshot waits until the first frame; lines 138–150 prove an
  already-drawn app adds no material wait. The total runtime values do not
  contradict that source-level timing clause.
- `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/README.md:140`
  documents waiting up to 10 seconds for text inside the app content view.
- Current-round iOS 26/27 stock captures are retained at `cov3-ios/IOS-117`
  and `IOS-118`, satisfying the unchanged control.
- Targeted stop succeeds and names the same session PID/serial; MCP server exit
  is 0.

No rerun is warranted. The only failed assertion was the obsolete decoder key.

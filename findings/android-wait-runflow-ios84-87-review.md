# Android runFlow and iOS attempts 84–87 review

## Android B3-L19 and B-C10.2

The six valid non-screens legs in `wait-runflow-contracts-rerun1/` support both rows. Successful plain, explicit-report, and JSON runs exit 0 and retain `runFlow: 14-runflow-sub.yaml` twice in live/summary/report or JSON action output. Failing plain and JSON runs exit 1 and name `14-runflow-sub-fail.yaml` as written in both step/error surfaces. The assertions confirm no absolute or `grantiva-flows-` staging path leaks. The configless copy has no Grantiva config, exits 0 using the flow header `appId`, and its runner client log records launching `com.kylebrowning.landmarks`. Exact-head path-rewriter/runFlow and app-ID resolution source semantics join these runtime clauses.

The two screens legs are harness-fixture failures and are excluded. They are not needed for B3-L19's explicit `run --flow` input or B-C10.2's configless-header input; they must not be used for separate wait/screens rows until rerun2.

## iOS attempt 84: S2-02 supported

Start, stop, and later force teardown all exit 0. After the required 120 seconds, the only processes naming the UDID are the resident Landmarks app and `launchd_sim`, not a runner, WDA xcodebuild, or diagnose process. Force JSON reports empty process arrays and `reclaimed:false`, and no killed-diagnose text. The app process does not “hold” the simulator in the teardown contract. The current S2-02 grade is supported.

## iOS attempt 85b: IOS-042 and IOS-044 supported

The standard Payload IPA contains the retained simulator app and declares `iPhoneSimulator`; explicit-U1 `--no-build --app-file` execution exits 0 with a passed browse report. Separately, installed-app no-build execution passes, explicit uninstall succeeds, and the same no-build input then exits 1 before runner execution with the required installed-state remedy. Restoration artifacts are retained. Both grades are supported.

## iOS attempt 86: B2-K21-a and B2-K21-b supported

The no-report flow pass/fail documents both omit `reportDir`; attempt 10 supplies the matching explicit-report pass/fail pair with absolute paths. Success omits `error`, while failure contains it. Flow pass/fail preserve the same one-flow shape. Screen pass/fail each preserve exactly two `kind: screen` entries, with the failed `Broken` entry retained beside the passed `Home` entry. Joined with exact-head encoder/contract assertions, both grades are supported.

## iOS attempt 87: IOS-043 supported

The retained fresh product declares only `iPhoneOS`. Candidate execution on explicit owned U1 exits 1 before runner execution with `Invalid app binary: Binary is built for [iPhoneOS], not iPhoneSimulator` and the simulator rebuild remedy. The grade is supported.

## Android B-A13.1: supported

`B-A13.1-exact-text-current-audit/` hash-pins the current AND-128 config and decoded runtime. Its `Lakes Exact` screen uses mapping-form exact selectors for tap, assert-not-visible, and assert-visible; all three actions pass and the screen result is all-passed. Exact-head FlowGenerator/config-platform excerpts cover emission and decoding, and the retained README expressly documents `{text: ..., exact: true}` for all three operations. This satisfies the Android half.

## Android D2-18: supported

`D2-18-run-json-shape-current-audit/` hash-pins current AND-050 pass, fail, and bad-device outputs. The decoded audit verifies pass/fail entry-key equality, required step keys, failure message, screenshot name/path, and the exact pre-flow `{allPassed:false,screens:[],error}` shape. Its absolute screenshot/report paths are correct because the retained report directories lie outside the command working directory, matching the exact README rule. The Android half is supported.

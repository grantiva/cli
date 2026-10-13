# Android B2-K24 scoped rereview

**Verdict: substantially addressed, with one remaining acceptance-clause gap.**

This rereview is limited to the sole open B2-K24 finding from the d162 checkpoint review. It does not reopen other Android rows.

## Addressed

`findings/evidence/cov3-android/B2-K24-exact-rerun1/` is fresh, non-overwriting evidence with a preserved controller script and candidate provenance (`8f2cff676b3c12e951478920fa20e600cdca4e29`). It closes the earlier runtime and source/default gaps:

- The default command and the separate `--platform android` command both run the candidate QA binary with the preserved Maestro-format `grantiva-android.yml`, exit 0, and write `Home Swiped.png` and `Caching Maestro.png`.
- Both JSON results contain the two named screens. Their step results show `Tap on id "clock"` and `Assert visible id "clock"` passing; verbose stderr independently shows the same ID actions.
- The preserved source assertions semantically cover Android platform loading, `appId`, default module `app`, default variant `debug`, named screens, `tapById`, `assertVisibleById`, generated Android `id:` steps, and command-line application-ID override.
- The exact-head CI excerpt shows both captured semantic tests started and passed.
- Exact-candidate `docs/android.md` states that Maestro-format `grantiva-android.yml` is supported and documents its `appId`, defaults, screenshots, and Android ID selectors.

The earlier overwrite allegation remains withdrawn: the original controller harness intentionally installed the fixture at the runtime config path. The new rerun makes that provenance explicit within each evidence leg.

## Remaining gap

B2-K24 incorporates B-C08.2's native-config branch. Because the candidate chose the “gains `{id: ...}`” alternative, the row must establish native `tap`, `assert_visible`, and `assert_not_visible` ID forms on both platforms and README documentation.

The new README excerpt documents those three native forms on iOS and Android, but the preserved source excerpt and exact-head CI lines cover only the Maestro Android fixture's `tapById` and `assertVisibleById`. They do not preserve semantic source/test evidence for native `assert_not_visible {id: ...}` or the native branch on both platforms. B-C08.2 is not separately recorded in the current Android ledger, so the B2-K24 row cannot inherit an already graded proof for that clause.

The runtime repro, explicit-platform leg, defaults, override, Maestro ID generation, docs/android requirement, and named-test execution are now supported. Full B2-K24 pass still requires a narrow source capture plus exact-head test result for the native B-C08.2 semantics (or a separately reviewed B-C08.2 row cited by B2-K24). Until then, the restored pass remains a partial overclaim.

## Fix round 2 — remaining B-C08.2 clause

**Updated verdict: addressed; B2-K24 is approved within this scoped rereview.**

The additional files under `B2-K24-exact-rerun1/source/` close the sole remaining gap:

- `GrantivaConfigPlatformTests-native-id.txt` preserves `testNativeStepsAcceptAnIdSelector`, which decodes native `tap`, `assert_visible`, and `assert_not_visible` `{id: ...}` forms and verifies all three by-ID flags survive a YAML round trip.
- `FlowGenerator-native-selector-production.txt` preserves the shared, platform-independent generator path. It feeds `tapById`, `assertVisibleById`, and `assertNotVisibleById` into selector emission; the only nearby platform branch adds Android's drawn-app wait and does not change selector generation.
- `FlowGeneratorTests-native-id.txt` pins emitted `tapOn id` and `assertVisible id` syntax.
- `exact-head-ci-native-id-tests.txt` shows both `testNativeStepsAcceptAnIdSelector` and `testAnIdStepIsEmittedAsAnIdSelector` started and passed in the already established exact-candidate CI run.
- `README-native-and-maestro-config.txt` documents native `{id: ...}` for all three operations and explicitly defines its iOS and Android meanings.

Together, the platform-independent production path, native round-trip assertions for all three forms, exact-head passing tests, and both-platform documentation satisfy the incorporated B-C08.2 branch. No remaining issue from the d162 B2-K24 review is open.

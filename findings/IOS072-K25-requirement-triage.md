# IOS-072 and B2-K25 requirement triage

Candidate source is `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main` at `8f2cff676b3c12e951478920fa20e600cdca4e29`. This note supersedes the premature product-defect classifications in the earlier scoped review; existing fail rows remain unchanged pending controller adjudication.

## IOS-072: current capture does not reproduce the documented input

The matrix says only “two flows named `same.yaml` in different dirs” and expects each to run once. It does **not** specify two repeated `--flow` options. Candidate README.md:104 defines `--flow <path>` as overriding configured flows to run “a single YAML file.” `Sources/GrantivaCLI/RunCommand.swift:17-18` likewise declares one scalar `String?`; lines 380-396 replace configured flows with `[flow]`. Therefore attempt 34's repeated command tests the documented singular override twice, and last-value behavior is not by itself proof of basename deduplication.

The supported multi-flow input is the config array: `GrantivaConfig.flows` is `[String]` (`Sources/GrantivaCore/Config/GrantivaConfig.swift:13,281`), and project resolution preserves `config?.flows` (`Sources/GrantivaCLI/TargetOptions.swift:149`; `RunCommand.swift:380-396` changes it only when singular `--flow` is supplied). README's report contract says flow paths in reports are the paths passed/configured, providing the relevant source-path semantics.

The discriminator is now complete in `cov3-ios-attempt36`. Its `grantiva.yml` configures `a/same.yaml` and `b/same.yaml`, the command supplies no `--flow`, exit is 0, and output/report contain two distinct passing flows (`same-1` and `same-2`) with the expected eight-step browse and six-step category bodies. Report `sourceFile` values preserve both paths. IOS-072 therefore **passes** under the supported matrix input. Attempt 34 documents only unsupported repeated use of a singular override, and no defect brief is warranted.

## B2-K25 [android]: the row conflicts with the established Android CI boundary

The original K25 brief does literally require the chosen pair behavior for `build install`, `run`, `diff capture`, and `ci run` alike. The exported B2-K25 matrix retained that language. However, this requirement conflicts with multiple explicit contracts that Android `ci run` refuses before all work:

- `docs/superpowers/specs/2026-10-07-android-support-design.md:290-293` says Android `ci run` fails before doing anything because remote baseline keys lack platform.
- `docs/android.md:98-102` repeats the exact local-only refusal.
- Candidate `Sources/GrantivaCLI/CICommand.swift:183-216` deliberately throws that refusal before pipeline work.
- Matrix CLI-167 and CLI-108 require this exact early refusal, while D2-08 already permits recording the `ci run` error when it cannot run without the necessary external path.

The fresh B2-K25 runtime is therefore consistent with the established Android CI boundary and inconsistent only with K25's compound expansion. It does not justify adding Android remote CI support as a K25 fix. The narrow supported correction is to evaluate K25's install/skip semantics on Android commands that are supported (`build install`, `run`, local `diff capture`) and treat Android `ci run` as the existing documented refusal; retain the iOS `ci run` half where supported/auth-gated. Task 6 should reconcile B2-K25 with CLI-108/167 and the Android design rather than label the current refusal a product regression.

This does not erase any real K25 behavior failure in the supported commands. The current Android evidence shows those commands honor the pair and `--no-build`-alone status correctly; only the contradictory `ci run` leg causes the compound row fail.

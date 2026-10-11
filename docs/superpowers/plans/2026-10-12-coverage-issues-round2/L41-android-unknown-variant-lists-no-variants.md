# An unknown `--variant` or `--module` names the Gradle failure and a generic `./gradlew tasks --all` hint, but not the variants or modules that do exist

Severity: ux
Component: cli
Platforms: android (2 of 2 inputs; logical, Gradle-only, no device).
Rows: B-A09.2 [android] (evidence in AND-024, AND-025)
Regresses/extends: A09 criterion 2 (docs/superpowers/plans/2026-10-09-qa-issues/A09-show-gradle-what-went-wrong.md, in git history; fixed in #170). Criteria 1 and 3 pass (B-A09.1, B-A09.3).
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11
Triage note: A09 criterion 2 is an "ideally" criterion ("Ideally, for an unknown variant/module, also list the available ones"). The current hint already tells the user how to find them. The owner may close this by ruling (record it in the fix-wave Rulings); otherwise the criteria below apply. Low priority either way.

## Expected
A09 criterion 2: "Ideally, for an unknown variant/module, also list the available ones (`./gradlew :app:tasks` or the
variant list)."

## Actual
findings/evidence/cov2-android/AND-024/01.out (`build build --variant noSuchVariant`) and AND-025/02.out
(`build build --module nosuch`):
```
✗ Build failed
  Duration: 0.6s
  ✗ FAILURE: Build failed with an exception.
  ✗ Cannot locate tasks that match ':app:assembleNoSuchVariant' as task 'assembleNoSuchVariant' not found in project ':app'.
  ✗ Check --variant and --module (or variant and module in grantiva-android.yml); `./gradlew tasks --all` lists the assemble<Variant> tasks of each module.
exit=1
  ✗ Cannot locate tasks that match ':nosuch:assembleFreeDebug' as project 'nosuch' not found in root project 'Landmarks'.
```
Neither names `freeDebug`, `paidRelease`, … or the `app` module.

## Repro
No device needed.
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$PATH"
unset GRANTIVA_API_KEY
rm -rf /tmp/l41 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l41 && cd /tmp/l41/android
grantiva build build --variant noSuchVariant; echo exit=$?
grantiva build build --variant noSuchVariant --json | python3 -I -c 'import json,sys;print(json.load(sys.stdin)["errors"])'
grantiva build build --module nosuch; echo exit=$?
./gradlew -q :app:tasks --group build | grep -E '^assemble[A-Z]'     # what the message could list
```

## Evidence
- findings/evidence/cov2-android/AND-024/01.out, 01.err, 02.out (`--json`), commands.txt
- findings/evidence/cov2-android/AND-025/02.out, 02.err, commands.txt
- findings/cov2-android-results.md row B-A09.2

## Suspected cause
`Sources/GrantivaCore/Android/GradleBuildRunner.swift:114-116` (in `errorLines`, `:95-118`): when Gradle's text contains
"Cannot locate tasks that match" or "not found in root project", it appends a fixed hint and stops. Nothing runs
`./gradlew :<module>:tasks` or `./gradlew projects` (or reads the variant names another way) to list the candidates.

## Acceptance criteria
- `build build --variant noSuchVariant` adds one line listing the module's assemble variants, e.g.
  `Variants of :app: freeDebug, freeRelease, paidDebug, paidRelease.`; `--module nosuch` lists the project's modules
  (e.g. `Modules: app.`). Text and the `--json` `errors` array carry the same line.
- The lookup costs at most one extra Gradle invocation, runs only on this failure, and is bounded by a timeout; if it
  fails, the current hint stays as the fallback.
- GrantivaCoreTests/GradleBuildRunnerTests.swift (next to `testAnUnknownModuleKeepsGradlesReasonAndTheHint`, `:105`):
  with a scripted shell returning a captured `:app:tasks` listing, the unknown-variant failure's errors include the
  variant list; with the listing command failing, they include the old hint.

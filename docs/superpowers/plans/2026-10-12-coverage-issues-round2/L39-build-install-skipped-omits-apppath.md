# `build install --json` drops the `appPath` key whenever nothing was built or installed (`--no-build`), although README lists it for every document

Severity: contract
Component: cli
Platforms: both. Android observed (D2-07 [android], 1 of 1, load ~250 but logical). iOS has the same omission (findings/evidence/cov2-ios/B2-K25/nobuild-only.out, `skipped` without `appPath`); the iOS D2-07 row only checked `status`, so it passed.
Rows: D2-07 [android]
Regresses/extends: new (D2 contract row). Related ruling: the round-2 fix wave's K17 ruling "explicit null, never omit" for absent JSON values (findings/ledgers/2026-10-11-round2-fix-wave-ledger.md:58).
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
README (c65fc17, :258-263): "The JSON result includes `status`, `scheme`, `bundleId`, `appPath`, `dataContainerPath`,
and `simulator` … On Android it includes `status`, `applicationId`, `appPath`, and `device` with the emulator's `name`
and adb `serial`. `status` is `installed` …, `launched`, or `skipped` (`--no-build --no-launch`: nothing was installed or
launched)." Every documented key is present in every document; where there is no value it is `null` (or README says
which statuses omit it).

## Actual
`launched` (D2-07/01) and `installed` (AND-021/01) carry `applicationId, appPath, device{name, serial}`.
`--no-build --no-launch` (findings/evidence/cov2-android/D2-07/02.out):
```
{
  "applicationId" : "com.kylebrowning.landmarks",
  "device" : {
    "name" : "cov2-android",
    "serial" : "emulator-5554"
  },
  "status" : "skipped"
}
exit=0
```
iOS, `--no-build --no-launch --simulator <udid> --json` (findings/evidence/cov2-ios/B2-K25/nobuild-only.out): `bundleId`,
`dataContainerPath`, `scheme`, `simulator`, `status: skipped`, no `appPath`. By the same code, `--no-build` with launch
(`status: launched`, nothing installed) omits it too (source read).

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner" GRANTIVA_SESSION_ID=fix-l39
unset GRANTIVA_API_KEY
rm -rf /tmp/l39 && git clone -q /Users/kyle/Developer/landmarks-demo /tmp/l39 && cd /tmp/l39/android
sed -i '' 's/^emulator: .*/emulator: fix-l39/' grantiva-android.yml
SERIAL=$(grantiva emulator ensure --name fix-l39)
grantiva build install --device "$SERIAL" --json | python3 -I -c 'import json,sys;d=json.load(sys.stdin);print(d["status"],sorted(d))'
grantiva build install --device "$SERIAL" --no-launch --json | python3 -I -c 'import json,sys;d=json.load(sys.stdin);print(d["status"],sorted(d))'
grantiva build install --device "$SERIAL" --no-build --no-launch --json | python3 -I -c 'import json,sys;d=json.load(sys.stdin);print(d["status"],sorted(d))'
grantiva build install --device "$SERIAL" --no-build --json | python3 -I -c 'import json,sys;d=json.load(sys.stdin);print(d["status"],sorted(d))'
grantiva emulator teardown --serial "$SERIAL"; grantiva emulator delete --name fix-l39
```
iOS: from `/tmp/l39/ios`, `grantiva build install --simulator <grantiva-created
UDID> --no-build --no-launch --json`.

## Evidence
- findings/evidence/cov2-android/D2-07/01.out, 02.out, commands.txt; findings/evidence/cov2-android/AND-021/01.out
- findings/evidence/cov2-ios/B2-K25/nobuild-only.out, commands.txt

## Suspected cause
- `Sources/GrantivaCLI/BuildCommand.swift:197-203` (Android) and `:204-213` (iOS) pass `appPath: productPath`, which is
  `nil` when nothing was built or resolved (`productPath` is set only at `:158`; `installed = productPath != nil` at
  `:182`).
- `InstallResult.appPath` (`:308`) and `AndroidInstallResult.appPath` (`:324`) are `String?` with synthesized
  `Codable`, which encodes `nil` by omitting the key.
- `InstallCommandTests.swift:122` pins the Android key set only for a document that has a path.

## Acceptance criteria
- Every `build install --json` document, on both platforms and for all three statuses, contains `appPath`: the path
  installed, or `null` when nothing was installed (K17 ruling: explicit null). Alternatively README :258-263 says that
  `appPath` is present only when the command installed a binary; pick one.
- `--no-build --app-file <apk>` (which installs) reports that file as `appPath`.
- Tests in GrantivaCLITests/InstallCommandTests.swift: encoding an `AndroidInstallResult` and an `InstallResult` with
  `status: .skipped` and no path yields a document whose keys include `appPath` with `null`; add the `skipped` shape to
  `JSONKeyCasingContractTests.swift` fixtures.

# Emulator boots are windowless whenever stdout is not a terminal, and neither help nor docs say so

Severity: docs
Component: docs (behaviour in cli)
Platforms: android (Android-only)
Rows: AND-005 (android)
Binary: grantiva 2.1.0 (main 51c597a), grantiva-runner 1.1.28-grantiva.9

## Expected
Matrix AND-005 (help emulator_ensure.txt: `--headless  Boot without a window.`; docs/android.md:38: "`--headless` boots
without a window."): the documentation describes when a boot gets a window. A reader of either expects a window
unless `--headless` is passed.

## Actual
`--headless` works (AND-005/01.out, under `script` so stdout is a TTY):
```
23672 .../qemu-system-aarch64-headless -avd cov-android-2 -port 5556 -no-snapshot-save -no-boot-anim -no-window
```
and without it on a TTY a window opens (AND-005/03.out: `qemu-system-aarch64 ... -no-boot-anim`, no `-no-window`).
But without `--headless`, any boot whose stdout is not a terminal is also windowless: `| cat`, CI, agents, and the
documented capture form `serial=$(grantiva emulator ensure --name Pixel_8_API_35)` (docs/android.md, and
`EmulatorCommand.swift:36-38`'s own comment). The same applies to `run`/`diff capture`/`build install` when they boot
an AVD. Nothing in help or docs mentions it. (The `| cat` run, AND-005/04, recorded no `ps` line; the TTY dependence is
read from source.)

## Repro
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_SESSION_ID=fix-k27; unset GRANTIVA_API_KEY
cd /tmp
SERIAL=$(grantiva emulator ensure --name fix-k27)          # stdout captured: not a TTY
ps -axo command | grep '[q]emu.*fix-k27' | grep -o -- '-no-window' || echo "window"
grantiva emulator teardown --serial "$SERIAL"
script -q /dev/null grantiva emulator ensure --name fix-k27 </dev/null    # stdout is a TTY
ps -axo command | grep '[q]emu.*fix-k27' | grep -o -- '-no-window' || echo "window"
grantiva emulator teardown --serial "$(adb devices | awk '/emulator-/{print $1}' | tail -1)"; grantiva emulator delete --name fix-k27
```
Today: `-no-window` for the first boot, `window` for the second, with no `--headless` in either.

## Evidence
- findings/evidence/cov-android/AND-005/01.out (headless), 03.out (TTY, window), 04.out (`| cat`), commands.txt

## Suspected cause
- `Sources/GrantivaCore/Android/EmulatorManager.swift:263`:
  `Self.bootArguments(avd: avd, port: port, headless: headless || isatty(STDOUT_FILENO) == 0)`; `bootArguments`
  (:178-182) adds `-no-window` when that is true.
- Help text: `Sources/GrantivaCLI/EmulatorCommand.swift:26-27` (`--headless` "Boot without a window.") and the shared
  `--headless` flag in `Sources/GrantivaCLI/TargetOptions.swift:36-37`; docs/android.md:38.

## Acceptance criteria
- `--headless` help (emulator ensure and the shared run/build flag) and docs/android.md:38 state the rule, e.g.
  "Boot without a window. Boots are also windowless when stdout is not a terminal (scripts, CI); pass `--window` to
  force one." (or whatever the rule ends up being).
- If a `--window`/`--no-headless` override is added, it is honoured when stdout is a pipe.
- Optional behaviour fix, if the rule is judged wrong: base the default on stderr/stdin or on `CI`, not on stdout,
  since `serial=$(grantiva emulator ensure ...)` is the documented interactive form.
- GrantivaCoreTests (EmulatorManagerTests): the headless decision is a pure function of (flag, isTTY) and is tested for
  the four combinations; a help-snapshot test (or doc check) contains the new sentence.

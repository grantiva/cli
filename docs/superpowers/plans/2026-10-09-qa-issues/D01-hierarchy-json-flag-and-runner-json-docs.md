# Make `hierarchy --json` select JSON (or drop it), and correct README's JSON-mode statement for runner commands

Severity: contract
Platforms: cli, ios, android
Found by: CLI-DOCS-F12, CLI-DOCS-F02 (matrix rows CLI-120, CLI-110; also IOS-050, AND-055)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
"Commands that advertise `--json` emit structured output." Source: README §Dashboard commands (README.md:309-312);
help: hierarchy (`--json  Output as JSON`); docs/dump-hierarchy.md §Flags (only `--format xml|json`).

## Actual
`grantiva hierarchy --json` and `grantiva runner dump-hierarchy --json` advertise `--json` but only `--format` selects the
output; `--json` alone gives XML (hierarchy) or the tree view (dump-hierarchy). Triage: "HierarchyCommand.swift never
reads options.json (only `format` at :80, :101, :120), so `--json` alone yields XML."
Meanwhile README says the opposite of the truth for runner commands:
```
for example, `hierarchy` emits XML by default, while runner lifecycle commands
do not have a JSON result.
```
yet `runner start|stop|install|version` all list `--json`, and `runner stop --json` prints `{"status":"not_running"}`.

## Repro
With a keep-alive session (`grantiva run --keep-alive ...`) running:
```
grantiva hierarchy --json | head -c 80          # XML, starts with "<"
grantiva runner dump-hierarchy --json | head -3 # tree text
cd $(mktemp -d) && grantiva runner stop --json  # {"status":"not_running"}
sed -n 309,312p README.md
```

## Evidence
- help/hierarchy.txt:25, :35; help/runner_dump-hierarchy.txt:3, :6, :14; help/runner_stop.txt (qa-cli worktree root)
- findings/evidence/cli/json/forced-failures.txt (runner stop --json); README.md:309-312; docs/dump-hierarchy.md:32-37

## Suspected cause
Sources/GrantivaCLI/HierarchyCommand.swift:33 pulls in `GlobalOptions` (which declares `--json`) but routes on `format`
only (:41-42, :80, :101, :117). Sources/GrantivaCLI/DriverCommand.swift:694-700 (`DumpHierarchyCommand`) does the same.

## Acceptance criteria
- `hierarchy --json` and `runner dump-hierarchy --json` print JSON (as if `--format json`); `--json` with
  `--format xml` is a usage error. Alternatively, hide `--json` on both and say so in help.
- README.md:309-312 states that runner lifecycle commands support `--json`; docs/dump-hierarchy.md lists `--json`.
- GrantivaCLITests/HierarchyCommandTests and DumpHierarchyCommandTests: parsing `--json` alone resolves to JSON output.

## Android detail (AND-F08)
Same on Android: during a keep-alive run on emulator-5554, `hierarchy --json` exits 0 and prints UIAutomator2 XML.
```
export JAVA_HOME="$(brew --prefix openjdk@21)/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="$HOME/Library/Android/sdk"
export PATH="$HOME/.grantiva-qa/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$ANDROID_HOME/cmdline-tools/latest/bin:$PATH"
export GRANTIVA_SESSION_ID=qa-android
cd /Users/kyle/Developer/landmarks-demo/android
grantiva run --no-build --flow .maestro/05-category.yaml --device emulator-5554 --keep-alive --ready-file /tmp/d01.ready & pid=$!
while [ ! -f /tmp/d01.ready ]; do sleep 0.2; done
grantiva hierarchy --json | head -1
<?xml version='1.0' encoding='UTF-8' standalone='yes' ?>
kill -INT $pid
```
Evidence (qa-android worktree): findings/evidence/AND-055/out.txt. Extra acceptance criterion: on Android,
`hierarchy --json` returns the same JSON shape as `--format json` (parsed by UIAutomator2HierarchyParser).

## iOS detail (IOS-F14)
Same on a device: during a keep-alive run, `hierarchy --udid <udid> --json` exits 0 and prints XML:
```
<?xml version="1.0" encoding="UTF-8"?>
<XCUIElementTypeApplication type="XCUIElementTypeApplication" name="Landmarks" label="Landmarks" ...
```
Repro:
```
export PATH="$HOME/.grantiva-qa/bin:$PATH" GRANTIVA_SESSION_ID=qa-ios
rm -rf /tmp/qa-ios-app && cp -R /Users/kyle/Developer/landmarks-demo/ios /tmp/qa-ios-app && cd /tmp/qa-ios-app
udid=$(grantiva simulator ensure --name qa-ios-2 --device-type "iPhone 17" --runtime 26.0)
grantiva build install --simulator qa-ios-2
grantiva run --no-build --flow .maestro/01-browse.yaml --simulator qa-ios-2 --keep-alive --ready-file /tmp/d01.ready &
while [ ! -f /tmp/d01.ready ]; do sleep 0.2; done
grantiva hierarchy --udid "$udid" --json | head -1; kill -INT %1
```
Evidence (qa-ios worktree): findings/evidence/triage/F14.out, IOS-050/out.txt.
Extra acceptance criterion: on iOS, `--json` output parses with `json.load` (the same tree as `--format json`).

# Fix the README `run --device "$udid" flows/` example

Severity: docs
Platforms: cli, ios
Found by: CLI-DOCS-F01 (matrix rows CLI-109)
Binary: grantiva 2.0.1 (commit c8dc86d)

## Expected
The example passes the UDID from `simulator ensure` to `run` with flags `run` accepts. Source: help: run (`USAGE: grantiva
run <options>`, `--simulator`, `--flow`; `--device` is "adb serial of an attached emulator or physical device (Android)").

## Actual
README.md:352-353 (§stdout is the result):
```
udid=$(grantiva simulator ensure --name "iPhone 17 Pro")
grantiva run --device "$udid" flows/
```
`run` takes no positional argument, and an iOS project rejects `--device` by name ("--device is an Android option, but
this is an iOS project ...").

## Repro
```
sed -n 348,356p README.md
grantiva run --help | head -5
cp -R fixtures/detect/xcode-only /tmp/d03 && cd /tmp/d03 && grantiva run --device X flows/; echo rc=$?
```

## Evidence
- README.md:353; help/run.txt:4, help/run.txt:34 (qa-cli worktree root)

## Suspected cause
Stale example from before `--device` became Android-only.

## Acceptance criteria
- README shows a command that runs as written, e.g.
  `grantiva run --simulator "$udid" --flow flows/login.yaml`.
- The fixed snippet is copied into a scratch iOS project and parses (no usage error).

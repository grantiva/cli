# Task 8 L85 source-live preparation report

Prepared `back_priority_source_live.py` as a bounded, serial iOS 26/27 acceptance helper for the unmerged `fix4/back-button-label-priority` source build. It was not executed. No build, test, simulator/device command, product edit, runner start, MCP call, review dispatch, or cleanup command was performed while preparing it.

## Scope and safety

The helper accepts exactly four controller inputs: `--source-manifest`, `--ownership`, `--project`, and `--output`. It never creates or deletes a simulator and never selects a default device. The ownership document must name a literal UUID, runtime, literal creation-command array, `owned: true`, and one of the controller-reserved names `fix4-back-26` or `fix4-back-27`. Provisioning, booting, exact demo installation, and eventual physical simulator deletion remain controller work outside this helper.

Before runner start, the helper requires both source checkouts to declare and actually have empty porcelain status. It computes complete relative-path/SHA-256 manifests for the adjacent bundle, source app, and installed app container and requires exact equality with duplicate, absolute, and escaping paths rejected. It parses the frozen release build proof and binds its exact clean source HEAD/repository, successful command and raw streams, binary path/hash, and complete bundle manifest to the artifacts under test. It also binds the unchanged runner source `ba9008f4b2cd2c7320a9c46e04faed612b0958a2` to the expected `.15` install stamp and exact path beneath the fresh runner home. Candidate 2 remains only the immutable source for unchanged runner/demo identities; actual paths and hashes are checked for this run.

The helper records `simctl list devices --json` before start and requires exactly one matching UUID. `fix4-back-26` must report the declared iOS 26 runtime; `fix4-back-27` must report the declared iOS 27 runtime. The ownership document must bind the exact name, device type and runtime in its literal creation command and record a pre-creation claim timestamp no later than creation. It then resolves the installed app container on that UUID and checks its complete manifest before runner start.

The helper starts only the explicit UUID with the manifest-bound release binary and exact command `runner start --platform ios --simulator <UUID> --bundle-id com.kylebrowning.Landmarks --detach --json` in the supplied fresh project. Its environment unsets `GRANTIVA_API_KEY` and fixes both runner-home variables plus `GRANTIVA_SESSION_ID=fix4-85`. Each external command records exact argv, cwd, selected environment, start/end, exit, and raw streams.

It imports the durable `findings/tools/round4-smoke-candidate2/mcp_client.py` `Client`; it does not carry a second MCP transport implementation. The started session must expose a positive integer PID before MCP acceptance begins. Cleanup independently attempts MCP close, exact matching-project stop, session-absence inspection, and exact-PID absence even if an earlier cleanup action fails. `cleanup.json` retains the primary error and every cleanup error. Command timeouts retain terminal `result.json` metadata plus partial raw-stream sizes before re-raising into scoped cleanup. It performs no broad process search/kill and leaves the owned simulator for controller cleanup.

## Source manifest interface

The controller must freeze a JSON document shaped as follows. Every placeholder is replaced with a literal value; paths are absolute. `version` and `nativeVersion` are exact stripped stdout strings from the corresponding `--version` command.

```json
{
  "schema": "grantiva.fix4-85.source.v1",
  "finalMergedCandidate": false,
  "task8Passed": false,
  "cli": {
    "repo": "/absolute/fix4-back-button-label-priority-worktree",
    "head": "<unmerged-source-head>",
    "cleanStatus": "",
    "releaseBinary": {"path": "/absolute/grantiva", "sha256": "<sha256>", "version": "<exact version>"},
    "adjacentBundle": {
      "path": "/absolute/grantiva_GrantivaCore.bundle",
      "files": [{"path": "Contents/Info.plist", "sha256": "<sha256>"}]
    },
    "frozenBuildProof": {"path": "/absolute/release-build-proof.json", "sha256": "<sha256>"}
  },
  "runner": {
    "sourceHead": "ba9008f4b2cd2c7320a9c46e04faed612b0958a2",
    "home": "/absolute/fresh-runner-home",
    "installed": {"path": "/absolute/fresh-runner-home/versions/1.1.28-grantiva.15+android-drivers-2/grantiva-runner", "installStamp": "1.1.28-grantiva.15+android-drivers-2", "sha256": "<sha256>", "nativeVersion": "<exact native version>"}
  },
  "demo": {
    "repo": "/Users/kyle/Developer/landmarks-demo/.worktrees/release-round4-candidate2",
    "sourceHead": "84af7581b75134b0e417b254e4317d565f7b73c6",
    "cleanStatus": "",
    "app": {"path": "/absolute/Landmarks.app", "files": [{"path": "Landmarks", "sha256": "<sha256>"}]}
  },
  "runtimeOwner": {
    "sessionId": "fix4-85",
    "deviceId": "<literal UUID matching ownership>",
    "ownershipManifest": "/absolute/ownership.json"
  }
}
```

The adjacent-bundle and app arrays must enumerate every regular file below their roots, sorted by relative POSIX path; the one-entry arrays above are illustrative only. The controller should copy candidate-2 runner/demo identities only after checking the actual supplied paths.

The referenced release build proof has this schema and must be frozen only after the exact clean-head release build completes:

```json
{
  "schema": "grantiva.fix4-85.release-build.v1",
  "success": true,
  "exit": 0,
  "repo": "/absolute/fix4-back-button-label-priority-worktree",
  "sourceHead": "<same exact unmerged head as source manifest>",
  "binary": {"path": "/absolute/grantiva", "sha256": "<same binary sha256>"},
  "bundle": {
    "path": "/absolute/grantiva_GrantivaCore.bundle",
    "files": [{"path": "<every relative bundle file, sorted>", "sha256": "<sha256>"}]
  },
  "command": {
    "argv": ["swift", "build", "-c", "release", "... exact args ..."],
    "cwd": "/absolute/fix4-back-button-label-priority-worktree",
    "startEpoch": 0.0,
    "endEpoch": 0.0,
    "exit": 0,
    "stdout": {"path": "/absolute/release-build.stdout.raw", "sha256": "<sha256>"},
    "stderr": {"path": "/absolute/release-build.stderr.raw", "sha256": "<sha256>"}
  }
}
```

The helper validates this content rather than trusting the outer proof-file hash alone. This truthfully binds the tested release binary and adjacent bundle to the exact source HEAD while retaining the explicit non-final status.

The ownership document interface is:

```json
{
  "schema": "grantiva.fix4-85.ownership.v1",
  "device": {
    "platform": "ios",
    "id": "<literal UUID>",
    "name": "fix4-back-26",
    "runtime": "com.apple.CoreSimulator.SimRuntime.iOS-26-...",
    "deviceType": "com.apple.CoreSimulator.SimDeviceType.iPhone-...",
    "creationCommand": ["xcrun", "simctl", "create", "fix4-back-26", "<device-type>", "<runtime>"],
    "claimedBeforeCreation": true,
    "claimedAtEpoch": 0.0,
    "createdAtEpoch": 0.0,
    "owned": true
  }
}
```

Use `fix4-back-27` for the other serial invocation. Each runtime gets its own fresh project, output, ownership document, and UUID; do not reuse an output directory or active session.

## Acceptance performed by the helper

The serial live sequence checks:

1. Existing L65 exact missing/wrong-type script errors and the unknown-selector error.
2. A cold hierarchy where the `heart` identifier exists while Favorites is unselected, followed by identifier-annotated selection; it repeats after switching back to Landmarks and confirms selected value `1`.
3. `Name` placeholder fallback and quoted `Mount "Denali"` selection.
4. Denali/Mountains navigation state survives switching to Favorites and back to Landmarks.
5. The Denali `Mountains` back reaches a category hierarchy simultaneously containing the Landmarks application root, actual Landmarks/`BackButton`, and selected same-labelled Landmarks tab.
6. Semantic `Landmarks` tap retains the exact label-stage prefix `Tapped on "Landmarks". Updated hierarchy:` and reaches a hierarchy containing Golden Gate Bridge. A separate fresh MCP hierarchy and exact-UUID `simctl io ... screenshot` independently confirm the root result.
7. A point-coordinate tap derived from the live Favorites frame remains functional.

This is focused L85 source-live evidence. The acceptance JSON explicitly retains `finalMergedCandidate: false` and `task8Passed: false`; it cannot promote the source build or replace candidate 3's complete transport/full-smoke acceptance.

## Prepared invocation

Run once per owned runtime, serially:

```sh
env -u GRANTIVA_API_KEY \
  python3 .superpowers/sdd/2026-10-13-round4-fix-wave/back_priority_source_live.py \
  --source-manifest /absolute/source-26.json \
  --ownership /absolute/ownership-26.json \
  --project /absolute/fresh-project-26 \
  --output /absolute/new-evidence-26
```

The prepared source is recorded in `task8-back-priority-source-live-preparation.diff`. Static syntax validation with `python3 -m py_compile` passed; its generated bytecode was removed. No execution result exists at preparation time.

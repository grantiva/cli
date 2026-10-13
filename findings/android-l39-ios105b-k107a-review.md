# Android B3-L39, iOS attempt105b, and B2-K107-a review

Source provenance: Grantiva CLI `8f2cff67`. This review uses retained round-3 evidence only.

## B3-L39 [android]: PASS

`/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/B3-L39-install-json-rerun2/decoded.json` records four successful exact modes:

- normal launch: `status: launched`, built APK `appPath`;
- `--no-launch`: `status: installed`, built APK `appPath`;
- `--no-build --no-launch`: `status: skipped`, `appPath: null`, with absent optional scheme/data-container values decoded as null;
- `--no-build --app-file ... --no-launch`: `status: installed`, and `appPath` exactly equals the frozen evidence APK path.

The decoder's checks are all true, including exit zero for every command and presence of the `appPath` key in every document. This is the Android half only.

## B2-K56 [ios]: PASS

Attempt105b starts a genuine current keep-alive run. Its original owner sidecar contains `appId: com.kylebrowning.Landmarks`; `current/context.json` renders that exact value in the Runner Session block with pid, WDA port, and UDID. The harness then removes only `appId` from the same live owner record to emulate an older Grantiva; `legacy/context.json` renders `bundle_id: (unknown)`, never an empty value. The flow exits 0 with terminal `passed`, and cleanup leaves no sidecars.

Evidence root: `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios/findings/evidence/cov3-ios-attempt105b/`. This evidence is also a valid current/legacy context clause for D2-39 [ios], but does not alone cover D2-39's other directory/config variants.

## B2-K107-a: supported clauses, not yet a full both-platform grade

The exact semantic assertions required by the row exist at candidate HEAD:

- `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/SimulatorLeaseTests.swift:289` — `testReleaseRemovesTheLockFile`;
- the same file at line 305 — `testAcquireRetriesWhenTheLockFileWasUnlinkedWhileWaiting`;
- `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/Tests/GrantivaCoreTests/WDADeviceHomeTests.swift:112` — `testPruningADeletedDevicesHomeLeavesNoLockFile`.

Current runtime evidence also proves useful branches:

- iOS attempt103b shows each same-directory keep-alive stop changing the row device lock probe from `True` to `False`, while an unrelated live session's lock remains `True` until its owner stops it.
- Android `B2-K107-a-exact/01.out` proves `emulator-5554.lock` absent after the owned run and shows the versioned `install-*.lock` files still present.

I would not mark the compound row fully passed from these artifacts alone. The retained current evidence reviewed here does not explicitly inventory the device lock before/after each separately named normal, Ctrl-C, teardown, and deleted-device runtime path on both platforms. The source tests cover the unlink race and deleted-home semantics, but they do not substitute for those explicit runtime inputs. Smallest remaining evidence is a consolidated before/after lock inventory keyed to already-owned lifecycle operations; no new product behavior is implicated by this review.

## B3-L23 [android]: PASS from retained session captures

The current detached-session batch `/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-android/findings/evidence/cov3-android/MCP064-066-B2K55-D241-vrt-equivalence-type-rerun1/` contains both required surfaces:

- `cli/capture.json` is the session-backed CLI capture document. Its Home step is `Launch app` and every recorded step duration is positive.
- `mcp-live/capture.json` is the MCP `grantiva_vrt_capture` response from the live session. Its Home `Launch app` duration is `1.5441219806671143`; every other step duration is also positive.

Both documents contain the duration key and neither contains a zero duration. The separate no-session MCP response in the same batch is not used to substitute for the row's explicit live-session input.

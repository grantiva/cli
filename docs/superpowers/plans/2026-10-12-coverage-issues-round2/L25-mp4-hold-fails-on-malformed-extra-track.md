# The Android `record` last-frame hold gives up on the whole file when any extra track lacks an `mdia` box, so the video track is not held

Severity: wrong-result
Component: cli
Platforms: android (the hold runs only for Android `record`, `RecordCommand.swift:220`). Source-only finding: no device or recording reproduces it with stock `screenrecord` output.
Rows: N2-20 [cli]
Regresses/extends: new brief for the fix-wave Task 8 deferred minor, left by CLI #191 (K34-a/K34-b held-frame note and hold diagnostics).
Binary: grantiva 2.1.0 (main c65fc17), grantiva-runner 1.1.28-grantiva.11

## Expected
The N2-20 matrix row and the fix-wave Task 8 ledger minor: a malformed track that is not video is skipped. The last-frame
hold still applies to the video track, and a unit test pins that.

## Actual
From the source at c65fc17. No test covers an extra track (findings/evidence/cov2-cli/N2-20/: `MP4LastFrameHoldTests` and
`MP4LastFrameHoldFixtureTests` have no extra-track case). A non-video track with a readable `hdlr` is skipped
(`.success(false)`). A track with no `mdia` box returns `Unreadable("a track has no mdia box")` before the handler type is
known. The loop returns that failure at once, so the video track is not held and the K34-b diagnostics report the file as
unreadable:
```
        guard var mdia = trak.child("mdia") else { return .failure(Unreadable("a track has no mdia box")) }
        guard mdia.child("hdlr").map({ $0.handlerType() == "vide" }) == true else { return .success(false) }
```
The same applies to a track whose `mdia` has no `hdlr`: `map` yields nil, `== true` is false, so it is skipped. Only the
missing-`mdia` case fails. A track before or after the video track with a missing `mdia` aborts the hold either way. The
behaviour was not observed on a device: `screenrecord` writes one video track.

## Repro
No device needed. `screenrecord` never writes such a file, so the repro is a unit test against the CLI source at c65fc17:
```
git -C /Users/kyle/Developer/grantiva-cli worktree add /tmp/l25 c65fc17 && cd /tmp/l25
# Add to Tests/GrantivaCoreTests/MP4LastFrameHoldTests.swift a case that builds the existing single-zero-length-frame
# fixture (testSingleZeroLengthFrameIsHeldToTheRequestedDuration) and appends a second `trak` box that holds only a
# `tkhd` (no `mdia`), writes it to a temp file and calls MP4LastFrameHold.holdFile(atPath:toSeconds: 4).
swift test --filter MP4LastFrameHoldTests
# bug: the new case returns .unreadable("a track has no mdia box"); the same fixture without the extra trak returns .held
```

## Evidence
- findings/evidence/cov2-cli/N2-20/ (source read and test listing at c65fc17)
- Sources/GrantivaCore/Android/MP4LastFrameHold.swift at c65fc17 (lines below)
- docs/superpowers/plans/2026-10-11-coverage-issues/K34-b-record-held-frame-note-intermittent.md; docs/superpowers/plans/2026-10-11-round2-fix-wave.md (Task 8)

## Suspected cause
- `Sources/GrantivaCore/Android/MP4LastFrameHold.swift:131-137`: the `trak` loop returns `.failure(error)` from
  `holdTrack` for any track.
- `MP4LastFrameHold.swift:217-218` (`holdTrack`): `guard var mdia = trak.child("mdia") else { return
  .failure(Unreadable("a track has no mdia box")) }` fails before the track is known to be video. The video-only guard
  is on the next line.
- By contrast, `videoTiming(of:)` (`:170-182`) already tolerates bad non-video tracks. It keeps the best video timing and
  only reports a reason when no video track is readable. The hold should match.

Fix: in `holdTrack`, return `.success(false)` when `mdia` or `hdlr` is missing (not provably video). Keep the failures for
a track that is video but unreadable (`mdhd`, `tkhd`, `stts`).

## Acceptance criteria
- A two-track MP4 (one video track with a held-frame candidate, one track with no `mdia` box, in either order) is held to
  the requested length: `holdFile` returns `.held` with the video track's timing. The extra track is left byte-identical.
- A file whose only video track is unreadable still reports why (K34-b behaviour unchanged).
- A file with no video track still reports "the movie has no video track".
- Tests: GrantivaCoreTests/MP4LastFrameHoldTests, synthetic boxes (as the existing single-frame fixtures build them)
  with (1) video + mdia-less track, (2) mdia-less track + video, (3) video + track whose mdia has no hdlr. Each `holdFile`/`hold`
  returns a held outcome whose video `stts` ends at the target and leaves the other `trak` unchanged.

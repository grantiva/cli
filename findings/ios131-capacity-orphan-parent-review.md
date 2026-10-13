# iOS attempt131 capacity and orphan review

B-I09.1: PASS. The targeted force teardown of U1 returns capacityRecordsCleared0 and retains its named cov3-ios record with an explicit session teardown explanation. The same session remains active on owned U2; simulator sessions lists U2 after force, and its hierarchy still responds0. The restored exact dead runner file44169 is listed in sessionFilesRemoved and is absent; no matching sidecar survives. Both U1 simctl diagnose processes are identified and killed, and the retained post-force process snapshot has none.

B-I09.2: PASS through runtime and exact semantic tests. The raw JSON above records the kept record and reason. The exact pinned SimulatorReaperTests excerpt asserts pending and dead sessionless records clear; named sessions and live sessionless owners are retained with reasons. This joins the current campaign's existing stale/pending capacity checks rather than treating every retained named session as a leak.

B3-L12: the two kill cases and sidecarless cleanup pass: killed-runner parent exits1 and leaves no runner files; kill followed by parentSIGINT exits130 and leaves no runner files; the captured dead runner file alone is restored and force removes/lists it. The live U2 hierarchy succeeds afterward. One precise evidence question remains: direct retention of U2's live session file (the fixture records functionality but does not explicitly inventory its file before/after). Worker is checking the retained store/source join; do not close that last clause only from parent wrapper0.

Evidence: cov3-ios/findings/evidence/cov3-ios-attempt131/. Cleanup stops the owned U2 session and no owner devices are touched.

## Final B3-L12 disposition: PASS

The source join resolves the live-file question without another device run. At pinned CLI8f2cff67, Sources/GrantivaCLI/HierarchyCommand.swift:69-74 calls locateSession; lines197-199 use KeepAliveSessionStore.locate exclusively. Sources/GrantivaCore/Runner/KeepAliveSessionStore.swift:320-327 enumerates .grantiva files, decodes the runner file, and requires its PID alive before returning a session. Therefore successful post-force U2 hierarchy resolution necessarily found its live runner file; this path neither recreates it nor falls back to the detached project's JSON. Both U1 runners and their files were already gone. The post-force success plus this exact source path proves file retention rather than merely a reachable port. All three attempt131 rows are approved.

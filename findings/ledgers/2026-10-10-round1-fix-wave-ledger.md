# SDD ledger — plan: docs/superpowers/plans/2026-10-10-round1-fix-wave.md

Spec: docs/superpowers/specs/2026-10-10-full-coverage-campaign-design.md (approved in chat: "A", "start working"; owner waived section-by-section review).

## Pre-flight scan

| Pair / task | Produces vs consumes | Finding |
|---|---|---|
| T0 S2 -> T1/T2/T3 | followups doc rows assigned per task | T3 depends on it; T1/T2 only consume rows assigned to them |
| T1 vs T2 | both touch pkg/driver/uiautomator2/commands.go | separate branches off grantiva/main; second to merge rebases — expected, not a conflict |
| T3 vs T1/T2 | selector/wait changes in both drivers | same: rebase on merge order T1, T2, T3 |
| T5 <-> T8 | install integrity may need a version marker in the tarball; T8 must emit it | T5 decides the mechanism (prefer `grantiva-runner --version` output so no tarball change is needed); T8 reads T5's PR before packing |
| T7 depends on T3, T5 merged | README:147 exact on Android; README:92 device-home path | ordering only |
| T8 depends on T1-T7 merged | runner main + CLI main | ordering only |
| T4 vs T6 | MCP vs CLI Android code | disjoint files |
| T6 internal | build must not boot vs build install may boot | self-consistent |
| GC: "no mention of related project" vs runner repo identifiers | existing identifiers left as-is | consistent |

Ruling: runner remote is `grantiva` (github.com/grantiva/runner); plan edited to say so — cost if wrong: none.
Ruling: T5 install-integrity mechanism — prefer executing the extracted `grantiva-runner --version` over a new marker file so T8's tarball layout is unchanged; T5 may choose the marker if the binary's version output is unreliable, and then T8 must emit it — cost if wrong: a repack iteration.

## Execution
Ruling: device slots — at most two Android emulators and two iOS simulators at once; dispatch order T1,T2 (Android) + T4,T5 (iOS) now; T6 when an Android slot frees; T3 after the harvest and a slot; T7 after T3+T5 merge; T8 after all — cost if wrong: idle time only.
Ruling: implementers open PRs but the controller merges after the review loop (owner approved "PRs, I merge after review") — cost if wrong: none.
Task 0: Steps 1,3 complete (toolchains ok; runner wts fix-uia2-input/fix-swipe-geometry/fix-selectors-followups off grantiva/main 2f2ee31; CLI wts off origin/main a278b77); Step 2 harvest dispatched (sonnet).
BASE runner=2f2ee31 BASE cli=a278b77
Task 0: complete (harvest commit 0d97378: 17 follow-ups, F01 -> Task 2 (forwarded to the running agent), F02-F17 -> Task 3).
Ruling: F10 (verify launch from cloned Products dir on a physical device) is out of scope — spec excludes real hardware — recorded in the round report as a gap; F13 (two-simulator concurrent-launch check) is satisfied by the 2.1.0 regression's I01 result (5/5 pairs, ports 8581/8457) and needs no code — cost if wrong: a physical-device bug stays unverified until someone has hardware.
Ruling: Task 3 splits into two PRs on the same branch family: 3a `fix/wda-selectors-followups` (exact on Android, F02, F14-F17) and 3b `fix/runner-lifecycle-followups` (F03-F09, F11, F12) — 16 items is too much for one review — cost if wrong: an extra PR.
Tasks 1,2 (runner, Android slots) and 4,5 (CLI, iOS slots) dispatched 16:50 (opus).
Ruling: a third light iOS simulator is allowed for Task 3a device checks (WDA caches hit; sims are far lighter than emulators) — cost if wrong: slower device checks.
Task 5: implementer DONE 17:05, PR cli#184 (8aad25b, f9e0740); no tarball marker needed (binary --version usable). Reviewer dispatched.
New finding (for round-1 coverage briefs / a later fix task): `grantiva runner stop` does not stop a `run --keep-alive` session (reads .grantiva/session.json, written only by `runner start`); SIGINT is the only way. Not in any brief; add to the coverage-pass expectations.
Task 5 review: spec ✅ (one gap), not approved: Important --force --json exit 0 on removal failure; minors: wrong cause text when the runner cannot run, root-sensitive test, PR note on keep-alive race. Fix round 1/5 dispatched (all four, per owner's "fix minors too").
Task 5: fix round 1/5 (commit 55eb7d5; 4 items) — scoped re-review dispatched; CI pending on #184.
Task 5: fix round 1/5 result: 4 addressed, 0 open (re-review clean). Awaiting CI on cli#184, then squash-merge.
Task 4: implementer DONE 17:30, PR cli#185 (2052bfb, 2fafbb3). Design choice to scrutinise: vrt_capture with a live session captures through the session's driver (exact label match, refuses runFlow/swipe steps) instead of running the runner. Reviewer dispatched on a278b77..2fafbb3.
New finding (coverage brief candidate): a tap on a missing label right after WDA becomes ready once returned "Network error (400)" instead of "Element not found" (now isError, still wrong text).
Task 4 review: spec ✅ (R04 test gap, R05 screenshot doc); design accepted-with-doc; not approved: Important session-capture taps ignore id/exact/duration; minors (missingConfig before shell-out, docs sentences, absolute directory, substring match). Fix round 1/5 dispatched (all six + optional baseline comparison).
Task 5: complete (PR cli#184 squash-merged as db8b338 on main; worktree removed)
Task 3a: implementer DONE_WITH_CONCERNS 17:50, PR runner#13 (6e95078). INCIDENT: pkg/emulator TestForceKillEmulator_ValidSerialNoProcess on main runs the real forceKillEmulator (pgrep qemu-system.*-avd -> SIGTERM all emulators); the agent's go test ./... killed fix-1/fix-2 emulators. Both agents warned with a test exclusion. User's Pixel_8_API_35 was not running.
Ruling: that test fix (and auditing forceKillEmulator so the fallback never touches emulators the runner did not start) goes to Task 3b as its first item (F18) — cost if wrong: none.
Ruling: Task 3a's pending Android exact: check is folded into Task 9 smoke and the round-1 coverage pass — cost if wrong: Android exact lands with unit-test coverage only until Task 9.
Note for Task 8: PR #13 bumps the WDA cache name to -wda16.12.8-r1 (vendored WDA gains an identifier attribute); the repack must regenerate caches under that name and the CLI tests that reference wda16.12.8 must follow.
Note for merge: commit 97496f3's message has two lines naming a related project; the squash-merge message must drop them.
Task 3a reviewer dispatched.
Task 3b dispatched 17:58 (opus) with F18 (emulator force-kill test/host safety) first, then F03-F09, F11, F12; devices only when a slot is free.
Task 3a review: spec ✅; approved pending: Important (CLI -r1 cache contract in PR body/gating; selectors.md false claim -> per-driver exact warning; F15 stopApp:false relaunch regression + runFlow header env), minors (F14 silent fallback log, WDA hash test, stale comment, loose test). Fix round 1/5 dispatched (all).
Ruling: F15 — exempt header-only env from forcing relaunch when `stopApp: false` is explicit; deliver sub-flow header env merged under the parent's — cost if wrong: a direct-runner user who wanted header env to force a relaunch loses that (CLI runs unaffected).
Task 4: fix round 1/5 (commit 3c7bf13; 6 items; session capture switched to driver screenshots; diff compare passes Home/Favorites/Deep Links within threshold) — scoped re-review dispatched.
New finding (coverage): during Task 4's comparison, `diff capture` under the runner failed the Detail screen ("Golden Gate Bridge" not found) on fix-4-ios while the regression pass had 19/19 screens; investigate in the round-1 coverage pass (flakiness or state from prior capture?).
Task 4: minor (deferred to coverage/next wave): SessionLifecycleTests take ~32 s waiting out the real 5 s element lookups; inject the timeout.
Task 4: fix round 1 result: 4 addressed, 1 partial (item 1), 1 not addressed (item 6: iOS rules copied from Android, stricter than runner 2f2ee31).
Ruling: the MCP session-capture selector rules must track the runner AFTER PR #13 (iOS text whole-value case-insensitive over label/value; id = identifier case-insensitive exact), platform-aware, documented against runner 1.1.28-grantiva.9 — not the 2f2ee31 behaviour the re-reviewer compared against — cost if wrong: if #13 changes shape before merge, Task 4's rules need a follow-up PR.
Task 4: fix round 2/5 dispatched.
Task 1: implementer DONE_WITH_CONCERNS 19:40, PR runner#14 (c3b98c1): inputText via key events again (set-value only as fallback), keyboard-key matches dropped when an app element matches; 03-edit 3/3, Android set 12/12. Reviewer dispatched.
Note (runner, for a later item): `make build` also copies the binary to ~/.maestro-runner/bin (outside both runner homes).
Open question for the reviewer: replaced-text detection warns instead of failing.
Task 6 dispatched 19:46 (opus) on the freed Android slot; Task 1 reviewer dispatched.
INCIDENT 2 (19:50): Task 3a agent ran `pkill -f "cat" -P` (malformed; inner pgrep empty) twice, signalling every user process with "cat" in its command line: other agents' shells (gh pr checks watchers for runner#14/#15, cli#185; a go test run), MCP servers (scape, claude-mem), Siri. Agent stopped itself at 1/7 fix items (item 2 done, item 6 partly; head 1b2e1fe).
Ruling: Task 3a's remaining items go to a FRESH implementer on the most capable model (fable), with an explicit ban on pkill/killall/kill of anything it did not start by PID — two incidents from one agent is a judgment problem, not a context problem — cost if wrong: a fresh agent rebuilds context (~15 min).
Task 1 review: spec partial (replaced text still ✓), not approved: Important double-type via set-value fallback; Important no non-ASCII tests on key path; minors.
Ruling: detected replacement of non-hint text -> `warned` step status (not ✓, not failure) via a warned flag on CommandResult — satisfies R01's "not marked ✓" without failing select-all-on-focus fields — cost if wrong: a flow that should fail hard on replacement only warns.
Task 1: fix round 1/5 dispatched (5 items).
Task 4: fix round 2/5 (commit 4bfb4a3; per-platform selector rules tracking runner#13; RED log saved) — scoped re-review dispatched.
Note (coverage): MCP session capture cannot match hint/placeholder text (not in the MCP hierarchy) though the runner can — document or fix later.
Task 2: implementer DONE 20:05, PR runner#15 (7d06953): element swipe ends at the screen's last pixel; anchors within a quarter-screen of the edge start from their far side; plain ints = pixels; F01 on appium/devicelab/browser drivers. CI green. Deviation from brief (edge margin) for the reviewer to judge. Reviewer dispatched.
Task 2 review: spec ✅; not approved: Important vertical swipes to edge pixel (restore 10%/90%), Important cdp in-element drag removed (restore); minors (point.go off-by-one, PR notes, devicelab_ios test).
Ruling: far-side start rule kept (start stays inside element bounds; documented) and edge-pixel end accepted for left/right only — cost if wrong: horizontal element swipes end 1 px further than reference semantics.
Task 2: fix round 1/5 dispatched (5 items).
Task 4: fix round 2/5 result: 2 addressed; residual divergences (hint/placeholder/errorText not parsed; try? swallows hierarchy error) -> fix round 3/5 dispatched.
Task 6: implementer DONE 20:25, PR cli#186 (5 commits, base db8b338). Device check clean. Reviewer dispatched.
Note for the owner: the new ledger pruning, run via the agent's debug binary, pruned 7 stale (already-deleted) AVD names from the real ~/.grantiva/android/created-avds.json; original saved in scratch fix-6/created-avds-before.json.
New findings (coverage / later): MCP grantiva_build still boots the AVD on Android (schema documents it); `diff capture --json` still uses the `simulator` key on Android; full `diff capture` prints "Capturing N screen(s)..." twice; UIAutomator2 connection dropped once on a fresh emulator (first diff capture attempt).
Task 6 review: spec ✅ (teardown deviation accepted: prune names only when the AVD is gone), quality approved; minors -> fix round 1/5 dispatched (lock race, CLI wiring tests, unattached-serial message, diff capture --json emulator key, double "Capturing" line).
Task 4: fix round 3/5 (commit 47447b1: placeholder/hint/error parsed and matched; page-source read failure surfaces) — scoped re-review dispatched.
Task 4: fix round 3/5 result: 2 addressed, 0 open (re-review clean at 47447b1). Awaiting CI on cli#185, then squash-merge.
Task 6: fix round 1/5 (commits 6f56e20..8c54f48; 5 minors) — scoped re-review dispatched. Owner note corrected: 8 stale AVD names pruned from the real ledger (listed in PR #186 body).
Task 4: complete (PR cli#185 squash-merged; worktree removed)
Task 4: (correction) merge landed on retry as 1f11cb1 on main.
Task 6: fix round 1/5 result: 5 addressed, 0 open (re-review clean at 8c54f48). Awaiting CI on cli#186, then squash-merge.
Ruling: Task 7 (docs) starts now on main 1f11cb1 rather than after runner#13 merges — only README:147 depends on #13, worded as current behaviour on the assumption #13 lands this wave (it is in review) — cost if wrong: one README line ahead of the bundled runner until Task 8.
Task 7 dispatched 20:55 (opus).
Task 3a: fix rounds 1-2 complete at 453c7f8 (items 1-7 done; cache prune of older-revision WDA builds added) — scoped re-review dispatched.
Task 3a: re-review of rounds 1-2: 7 addressed; Important: cache prune starves older installed CLIs and races live runs.
Ruling: drop the older-revision WDA cache prune entirely; old `-wda16.12.8` dirs stay orphaned (cache is shared across installed versions by design) — cost if wrong: disk use grows by one WDA build per runtime per revision.
Task 3a: fix round 3/5 dispatched (drop prune; hash walk via git ls-files).
Task 6: complete (PR cli#186 squash-merged as 1d2260b; worktree removed)
Task 2: fix round 1/5 (commit 296508e; 5 items; CI green) — scoped re-review dispatched.
Task 7: implementer DONE 21:20, PR cli#187 (c06a37d): 22 mismatches fixed; docs/mcp.md runner version string dropped (bundled is .8). Reviewer dispatched.
Task 2: fix round 1/5 result: 5 addressed, 0 open (re-review clean at 296508e).
Task 2: complete (PR runner#15 squash-merged as 230fe6b on grantiva/main; worktree removed). Follow-up R02-a: devicelab_ios_legacy percent-only swipe coords.
Note (coverage): `100%` now maps to size-1 for every ParsePointCoords caller incl. point taps; call sites not audited.
Task 7 review: 22/22 verified; Important README:360 `console vrt runs` is a group; minors (README:93 implies --logs; README:145 "contains" vs whole-value rule; README:332 help string is the one that is wrong -> follow-up for a CLI batch). Fix round 1/5 dispatched.
Ruling: README:145 reworded to the whole-value, case-insensitive text rule the runner adopts in PR #13 (same basis as the README:147 ruling) — cost if wrong: README ahead of the bundled runner until Task 8.
New finding (CLI follow-up): `runner start` help says "with WDA" only; should mention UIAutomator2 on Android.
Task 7: fix round 1/5 (commit 309c765; 4 items) — scoped re-review dispatched.
Task 7: fix round 1/5 result: 4 addressed, 0 open (re-review clean at 309c765). Awaiting CI on cli#187, then squash-merge.
Task 1: fix round 1/5 (rebased on 230fe6b; commits 3c0b44f..4d12f41; warned status, non-ASCII whole typing, editable-only fallback, showing-hint page-source fallback) — scoped re-review dispatched (whole branch diff since rebase).
New finding (coverage): 10-seed-many on a fresh AVD reaches Landmark 22 not 30 after four scrolls (also with unmodified 2f2ee31); passed on the round-1 AVD — scroll geometry or AVD density; re-check after #15.
Ruling: additive fields are allowed in report.json (constraint forbids removing/renaming); a warned step may carry an additive `warnings`/`status: warned` marker so the console path stops showing ✓ — cost if wrong: consumers that switch on status strings see a new value.
Task 1: fix round 1 result: items 2-5 addressed; item 1 partial (warning not in report.json/report console/HTML). Fix round 2/5 dispatched (additive report.Command.warning, console/HTML rendering, lazy hint fetch, editability-first, masked guard, PR body ref).
Task 3a: fix round 3/5 (prune reverted; hash test on git ls-files; rebased onto 230fe6b; head 409f463) — scoped re-review dispatched.
Task 7: complete (PR cli#187 squash-merged; see origin/main)
Task 3a: fix round 3 result: 3 addressed; one Minor (hash test Fatal when git missing) -> round 4/5 dispatched (same fable agent; one-line skip guard).
Task 3a: fix round 4/5 (4e6eb73: skip hash test without git) — scoped re-review dispatched; CI watch on runner#13 running.
Task 3a: fix round 4/5 result: 1 addressed, 0 open (re-review clean at 4e6eb73). Awaiting CI on runner#13, then squash-merge (squash message must drop the two related-project lines from 97496f3/f55e5a0).
Task 1: fix round 2/5 (1e4c67c, b8e2da3: warning in every report format; lazy hint check; editability first; masked guard; #122 removed) — scoped re-review dispatched.
Task 1: fix round 2 result: 4 addressed, item 2 partial (possible false-positive warning on Compose placeholder). Round 3/5 dispatched.
Ruling: the replaced-text warning requires positive evidence (hint attribute present and != before); unknown/null/404 -> no warning — cost if wrong: a real replacement on a server without the hint attribute goes unwarned (fail-safe direction).
Task 1: fix round 3/5 (fb21bab: warning only on positive evidence; empty-field probe clean) — scoped re-review dispatched.
Task 3a: complete (PR runner#13 squash-merged as c1a9a10 with a clean message; worktree removed). Pending from it: Android `exact:` device check (Task 9 smoke); CLI repack must ship -wda16.12.8-r1 caches (Task 8).
Task 1: fix round 3/5 result: 1 addressed, 0 open (re-review clean at fb21bab). Agent asked to rebase onto c1a9a10 and add the non-ASCII positive-warning test; then CI and merge.
Task 1: rebased onto c1a9a10, head e3c1dd6, non-ASCII positive test added; awaiting CI on runner#14, then squash-merge.
Task 3b: implementer DONE 23:05, PR runner#16 (d1a0671, 10 commits on c1a9a10): F18 force-kill scoped + pkg/emulator host-safe TestMain; F03-F09, F11, F12 done (F12 device check pending). Reviewer dispatched. Notes: make build copies to ~/.maestro-runner/bin (fix later); legacy dlrun-* xctestrun copies never cleaned (finding); crash error now core.ErrAppCrashed (report category may change).
Task 1: complete (PR runner#14 squash-merged as d80ee41 on grantiva/main; worktree removed).
Task 3b review: spec ✅ all F-items; approved pending Important F07 false early-fail (FATAL log alone); minors (F18 error-path test, -ports test, stale comments; F12 ctx on flock; F07 sentinel consistency; PR body notes). Fix round 1/5 dispatched.
Ruling: a logged FATAL alone is not a crash — require the launched pid gone (or launchApp's crash marker); a restarted app that shows the element passes — cost if wrong: a genuine crash whose process lingers is detected a little later (bounded by the wait timeout).
Ruling: report.json error.type relabel element_not_found -> app_crash for waits ended by a real crash is accepted (CLI does not read error.type; verified by grep) — cost if wrong: an external consumer keyed on the old value.
Task 3b: fix round 1/5 (rebased 649c5a2; fixes 56b7bbb, 1dbf9eb, 74a71a3) — scoped re-review dispatched. Concern: 99-crash detection may be slow again when the crashed process lingers.
Task 3b: fix round 1 result: 6 addressed; new Minor (shutdownEmulator ticker panic on timeout<=0); design: adopt AMS am_crash event as second crash signal.
Ruling: adopt `am_crash` (events buffer, pid-matched) as the crash confirmation when the FATAL-logging pid lingers — only the system crash handler emits it, so handled exceptions do not trigger it — cost if wrong: one logcat events read per crash poll while a FATAL is logged.
Task 3b: fix round 2/5 dispatched (am_crash signal, ticker clamp, legacy buildlock ctx).
Task 3b: fix round 2/5 (d0dd240 am_crash signal: 80 device runs, 4 post-launch crashes caught in ~300 ms; eebf3a5 ticker floor; 9c97d02 legacy lock ctx) — scoped re-review dispatched.
Task 3b: fix round 2/5 result: 3 addressed, 0 open (re-review clean at 9c97d02). Awaiting CI on runner#16, then squash-merge; then Task 8 (repack 1.1.28-grantiva.9 with -r1 caches).
Task 3b: complete (PR runner#16 squash-merged as ae48e34 on grantiva/main; worktree removed). All runner PRs for round 1 merged: #13 c1a9a10, #14 d80ee41, #15 230fe6b, #16 ae48e34.
Task 8 dispatched 00:40 (opus): runner worktree .worktrees/release-round1 at ae48e34; CLI worktree chore-bundle-runner (rebase on origin/main da9ba2c).
Task 8: implementer DONE 01:25, PR cli#188 (924c069): tarballs with four -r1 caches, runnerVersion 1.1.28-grantiva.9, 1397 tests pass, fresh-home install e2e clean. Reviewer dispatched.
Task 8 review: approved, all six checks ✅ (tarballs clean, four -r1 caches with the patched agent, binary prints .9, SDK name in xctestrun not consulted by cache lookup). Awaiting CI on cli#188, then squash-merge; then Task 9.
Task 8: complete (PR cli#188 squash-merged; see origin/main)
Task 9: complete (binary 2.1.0/51c597a + runner .9 at ~/.grantiva-qa/bin; upgrade PASS; smoke commit b517e7c: A1-A5, I1-I3 all pass; 99-crash caught in 1.6 s at launch or 318 ms after; cosmetic observations N15-N18 handed to the coverage matrix). Round-1 fix wave COMPLETE. Next plan: 2026-10-11-round1-coverage-pass.md (own ledger).

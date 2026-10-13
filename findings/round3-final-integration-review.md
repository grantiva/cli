# Round 3 final integration review

**Approved for Task 6 consolidation. No critical or important integration findings.** The report correctly concludes **ROUND 3: 22 findings — round 4 fix wave required**. This approval does not close any product finding or declare the candidate clean.

Reviewed controller head `401ee236`, the final review package, campaign design, coverage-pass Task 6, final report, matrix, all three result ledgers, effective audit JSON, corrected-criterion map, B2/B3 table, coverage ledger, new brief mappings, and relevant independent reviews. Selected raw captures and exact candidate source were inspected to resolve the integration questions below. No devices, builds, test suites, account operations, or teardown commands were run during this review.

## Coverage and accounting

An independent parse of the eight-column matrix confirms 1,170 unique logical rows and 1,329 required platform results: CLI 384, iOS 478, Android 467. Re-derivation from the merged result ledgers finds no missing IDs. Matrix and ledger SHA256 values agree with `task6-effective-coverage-audit.json`.

| Slice | Original pass / fail / blocked / N/A | Final pass / fail / blocked / N/A |
|---|---|---|
| CLI | 368 / 7 / 5 / 4 | 375 / 2 / 3 / 4 |
| iOS | 447 / 21 / 10 / 0 | 454 / 13 / 11 / 0 |
| Android | 442 / 17 / 6 / 2 | 452 / 7 / 6 / 2 |
| Total | 1257 / 45 / 21 / 6 | 1281 / 22 / 20 / 6 |

The 25 unique corrected-criterion map entries each match exactly one appended ledger line: 23 passes, one credential block, and the still-failing iOS B2-K25. Every corrected matrix ID has its `corrected round 4` marker. B3-L29 and N3-15 are the two additional completion observations; their absence from the expectation-correction map is intentional and explained in the report. The audit's two `actual_rows_without_mapping` entries are these same observations, not missing correction dispositions.

The per-brief table contains exactly all 260 required B2/B3 platform entries. The 39 iOS 27 repeats, six CLI handoffs, and three side findings remain outside the matrix denominator. Thus 22 final failing matrix results plus three side observations produce 25 failing observations, consolidated into 18 new briefs. Adding retained L51/L53/L61/L62 yields the reported 22 open briefs.

## Failure and block disposition

Every remaining failure has a matching brief that names its matrix row:

| Brief | Failing result(s) |
|---|---|
| L64 | B3-L57 Android |
| L65 | B3-L15.2 iOS and Android |
| L66 | IOS-102, B2-K78, D2-36 iOS |
| L67 | CLI-025 |
| L68 | AND-127 |
| L69 | N3-03 iOS and Android |
| L70 | B-I16.2 iOS |
| L71 | B2-K25, D2-08 iOS |
| L72 | N2-15 iOS |
| L73 | D2-20 iOS |
| L74 | B-C22.2 iOS and Android |
| L75 | B3-L20 iOS and Android |
| L76 | IOS3-OBS-01, separate side finding |
| L77 | B3-L49 Android |
| L78 | IOS-064 |
| L79 | AND3-OBS-01, separate side finding |
| L80 | AND3-OBS-02, separate side finding |
| L81 | N3-15 |

The report enumerates all 20 final blocked platform results. Their reasons match the ledgers: protected booted-device prerequisites, unavailable authenticated CI or root controls, prohibited global teardown, unavailable image/endpoint conditions, and the environment-dependent L53 observation. Local passing halves do not silently pass blocked compound rows. The current-behavior passes for retained briefs do not close their open fix obligations.

## Evidence preservation and adjudication

All three ledgers at the completed merge `6f4cba63` remain exact byte prefixes of their current files. Task 6 adds adjudications without overwriting original verdicts. Its evidence diff contains additions for the final doctor observation, with no modification or deletion of existing raw captures.

The 172 retained Task 6 help pages independently match the canonical corpus byte-for-byte; every saved exit is zero and every page contains the required headings. The replay's binary hash matches the frozen executable. B3-L29's raw hidden-option invocations retain their Gradle sandbox failure, while the named exact-candidate tests/source establish the no-boot and ABI semantics. The completion pass does not claim a successful new build.

The corrections preserve substantive failures: B2-K25 iOS remains L71, authenticated B2-K19 iOS remains blocked, and L80 is not absorbed into the lifecycle pass. Direct inspection of L80's raw stream confirms three valid initial responses followed by two invalid lines of 135,963 and 4,937 bytes, with response ID 4 inserted at byte 65,536 inside response ID 5. L79's raw result exits 1 while the runner report says passed and the optional command says failed. L76 retains the inert process's SIGINT exit `-2`. These side findings remain independently actionable.

The final N3-15 text omits the required ownership note despite the retained unowned default-named simulator. Its before/after booted inventories are byte-identical, and exact-candidate `DoctorRunner` returns a booted-device success before evaluating the ownership-note helper. The additive failure and L81 brief are justified.

B2-L03 and B3-L51 cite the final independent reviews and valid exact-session measurements, including the disclosed indexed-row method and excluded invalid baselines. Their instrumentation correction does not waive the gesture contract or close retained L51.

## Candidate integrity and cleanup

The QA executable hashes to `3f3293aaf1522fefe8d46457370b32a20fa8c657461bf32af086e75a754a73f8`. The clean source worktrees remain at CLI `8f2cff676b3c12e951478920fa20e600cdca4e29` and runner `fd9d8e8d1cb109eda6116f4221da10257b9838e3`. Controller history since slice dispatch `bb866976` has no changes under `Sources`, `Tests`, `Package.swift`, or `scripts`; its older product source was not mistaken for the candidate.

The retained iOS cleanup harness restricts teardown to the two named campaign UUIDs with QA runner home and API key unset. Both exits are zero; neither UUID appears in the after device/session/process inventories. Both owner iPhones remain booted in before/after inventories. The later read-only doctor inventory is unchanged.

Android `FINAL-primary-delete-rerun4` raw artifacts corroborate its seven passing checks: adb is empty, only `Pixel_8_API_35` remains installed, created/started records are empty, and the global-session inventory is empty. The exact campaign teardown reports killed/recorded true; its named delete reports deleted true. No global destructive teardown is needed to support these cleanup claims.

The report is accurate about the remaining failures, evidence qualifications, cleanup, and unmet zero-findings exit criterion. Proceed with the independently reviewed Round 4 plan covering all 22 open briefs.

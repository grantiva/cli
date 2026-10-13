# B3-L51 Android final review

B3-L51 is **PASS** from `B3-L51-four-forms-rerun12` joined to the exact candidate source/tests.

All four prescribed scratch forms exit 0 after accepting their initial hierarchy during the 15-second pre-gesture wait: each baseline poll is 1, contains the named seed-many initial screen, and its saved runner-log snapshot predates Step 1 completion and Step 2 execution. Thus the hierarchy transition cannot be a post-gesture baseline.

Observed movement and settling:

| form | measurement | travel | settle |
|---|---|---:|---:|
| direction UP | common row | -1561 px | 1259 ms |
| 50%,70% to 50%,30% | common row | -1561 px | 1401 ms |
| direction UP from All Landmarks | common rows | -1276 px | 648 ms |
| scroll DOWN, engine adb | indexed-row intercept | -2311 px | 1577 ms |

The first three comparisons retain common row identities. The adb form moves from visible indices 1–3 to 7–15 and has no overlap, so its travel is computed from the same known 189-pixel row pitch and indexed contract titles; this is a disclosed measurement method, not a fabricated common-row delta. Every form settles to three consecutive identical direct reads and its final CLI hierarchy matches 23/23 meaningful app nodes at 420 dpi within 1.25 dp.

The element form alone retains a W3C `/actions` body: a held drag from `(159,1537)` to `(159,240)` with 250 ms at the endpoint, matching its runner narration. The absence of `/actions` in the other three client logs is corroborative rather than treated as proof of shell routing. Exact candidate tests/source provide that proof: screen-direction and absolute coordinate swipes format `input swipe`; `bare_scroll_test.go` pins `engine: adb` to `input swipe` and excludes server drag; `deterministic_gestures_test.go` requires the element form to use the held server gesture and forbids shell `input swipe`. All forms move the list in the intended direction, so no L51 failure condition is present.

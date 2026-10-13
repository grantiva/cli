# Android K09 group and B3-L62 review

## B-A02.2, B-R02.1, B2-K09, N2-17

**Approve all four rows.** `B-A02.2-B-R02.1-N2-17-farside-ten-rerun1/decoded.json` records ten distinct exact K09 runs, ten exit-zero results, Before/After PNGs for every run, a logged selector swipe in every run, and Remove revealed in every run. The retained runner logs independently show the material geometry, for example runs 1, 5 and 10 each report `swipe left: held drag (246,500) -> (0,500) over 300 ms`, followed by successful `assertVisible: text="Remove from favorites"` and a passed 13-step flow. `failures.txt` is `0`. The stock 02-favorite control also exits zero.

That geometry is the corrected binding contract, rather than the superseded centre-start wording: for the pinned Lake Tahoe text bounds `[42,469][269,532]` on 1080×2400, x=246 is 90% across the element on the side away from the left edge, remains inside the element, and the endpoint is the left edge. At runner `fd9d8e8`, `docs/selectors.md:114-123`, `pkg/core/gesture.go:143-219`, and `pkg/core/gesture_test.go:346-390` document and pin `(246,500)->(0,500)` through both `SwipeCoordsToScreenEdge` and `SwipeCoordsForElement`. The UIAutomator2 deterministic gesture test pins the same held pointer path. This supplies the runtime count, screenshots, trace geometry, stock-flow control, documentation, and semantic source clauses.

## B3-L62

**Approve pass.** `B3-L62-remove-five-rerun4/posthoc-decoded.json` corrects three disclosed wrapper proxy mistakes against the raw artifacts and reports all required checks true for five cycles. Each prefix run exits zero and reaches the revealed Remove state. Read-only hierarchy probes before stopping show Remove, and the stopped/restarted state retains it. Each continuation begins with a runner screenshot, performs the exact `tapOn: text="Remove from favorites"`, passes its assertions, and ends with the empty Favorites state in screenshot and hierarchy. Runs 1, 3 and 5 raw stdout independently show the successful Remove assertion, exact tap, and passed flow; all seven command legs in each sampled cycle exit zero. The AVD speed evidence is retained.

The literal row accepts any 0–5 passes provided the observed behavior is the known Remove persistence/failure mode and no different failure appears. Here all five removals ultimately pass, with the intermediate revealed state and restart persistence explicitly recorded. The original wrapper exit 1 arose only from its proxy checks and does not contradict the raw or corrected decoder.

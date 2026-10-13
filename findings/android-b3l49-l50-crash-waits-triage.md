# Android B3-L49 / B3-L50 crash-waits triage

The current `B3-L49-L50-crash-waits-rerun1` evidence supports the crash-classification clauses and exposes one product defect in the intentional-stop control.

## B3-L49

- All nine required crash not-visible variants (plain, extended, and page-source; three each) exit 1 at `launchApp` with `app_crash`, `java.lang.RuntimeException`, and `LANDMARKS_CRASH_ON_LAUNCH`. The matrix explicitly permits the failure to be recorded at launch, so these legs pass.
- `live-gone` exits 0 and supplies the genuinely disappearing live-element control.
- `live-stays` exits 1 after the required still-visible timeout, supplying that negative control.
- `intentional-stop` is a **product failure**. The exact flow uses a valid header `appId` and bare stopApp. The report says stop passed, but the app UI remains onscreen and the following absence check fails. Source shows the executor inherits the header app ID, while the Android driver trusts a zero `am force-stop` shell exit without checking the stop postcondition. L77 records the defect and bounded acceptance criteria.

Therefore B3-L49 remains fail due to the intentional-stop clause; the other runtime clauses are supported.

## B3-L50

All six crash variants (count and extended-visible, three each) fail at launch as `app_crash` with the RuntimeException cause, satisfying the crash clauses. The initial `live-count` fixture expected count 1 but observed 2; that was an input mismatch, not a product failure. `B3-L50-live-count-complement-rerun1/input/live-count.yaml` uses the observed correct count 2, exits 0, and `report/flows/flow-000.json` records the count-2 assertion passed. Joined with the six crash variants and exact source assertions, **B3-L50 is fully supported**.

## Source semantics

Exact runner `fd9d8e8` contains the named crash/not-visible semantic assertions in `pkg/driver/uiautomator2/notvisible_crash_test.go`, including `TestNotVisibleAfterStopAppPasses`, and the count/visible crash paths in the adjacent wait tests. Those tests support classification behavior but do not replace the failed live stop postcondition.

# Android round-3 coverage final summary

The Android slice is complete: **467 of 467 base rows** are recorded in `findings/cov3-android-results.md`.

- 442 pass
- 17 fail
- 6 blocked
- 2 n/a
- 2 additional evidence-backed side findings: AND3-OBS-01/L79 and AND3-OBS-02/L80

The two final runtime gaps closed with direct, exact-session hierarchy instrumentation. B2-L03 records consistent four-step bare-scroll movement on software and GPU renderers and joins the prescribed three-by-three full-snapshot runs. B3-L51 records all four swipe forms from valid pre-gesture baselines, including disclosed indexed-row measurement for the nonoverlapping adb-engine transition. Both use app-only semantic normalization between direct UIAutomator2 and final CLI hierarchy data.

## Final cleanup

`findings/evidence/cov3-android/FINAL-primary-delete-rerun4` completed with exit 0. Its decoder reports all seven checks true:

- adb inventory is empty;
- no campaign device remains attached;
- no campaign AVD remains installed;
- no campaign started or created ledger record remains;
- no campaign global session file remains;
- the owned primary `cov3-android` was deleted;
- unrelated `Pixel_8_API_35` remains installed.

The exact targeted teardown records `emulator-5554` / `cov3-android` as recorded and killed, and the targeted delete returns `deleted:true`. Cleanup did not use a global destructive teardown.

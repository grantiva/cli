# CLI-108 candidate5 corrected clause assessment

Verdict: **PASS**.

Expected: Refuses with "Android baselines are local only until the Grantiva backend supports platforms; use local baselines" (docs/android.md:71-73)

Fresh run2 exits 1 before build/device with the exact Android-local-baselines rejection.

Evidence: `../CLI-108-run-2/`. First pending assessment is preserved.

# CLI-101 candidate5 clause assessment

Verdict: **PASS**.

Expected: `Android recordings are capped at 180 seconds per file (screenrecord --time-limit); --duration 200.0 is too long.` before recording (docs/android.md:118)

Fresh current-candidate raw confirms the required validation/result before compiler or live-device work. Evidence: `CLI-101-run-2/duration-cap.command.json`.

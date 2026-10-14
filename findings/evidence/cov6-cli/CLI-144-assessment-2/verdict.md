# CLI-144 candidate5 corrected clause assessment

Verdict: **PASS**.

Expected: Exit 64: `--output must end in .mov on iOS (simctl records QuickTime); got a.mp4. Try a.mov.` and the `.mp4` / Android counterpart, before recording (help: record.txt `--output`; brief C14)

Fresh run2 exercises all three invalid output extensions; each exits 64 with the platform-specific expected extension diagnostic.

Evidence: `../CLI-144-run-2/`. First pending assessment is preserved.

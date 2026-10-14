# CLI-008 cov5 clause assessment

Verdict: **pass**.

Current evidence was freshly executed against candidate4 manifest SHA-256 `714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783`; each command has adjacent identity and exit capture. The following observations are from this directory’s current stdout/stderr and command records:
- Runner install, version, start, stop, and dump-hierarchy help, plus hierarchy and top-level record help, exit 0. An additional runner group-help probe is retained but is not needed to grade the row.
- Runner dump-hierarchy shows `-p, --port`, `-f, --format`, values tree/json/xml with default tree, and `--udid`.
- Record usage places `--duration <duration>` outside brackets, establishing it as required.

No runner session, recording, hierarchy request, or device resolution occurs because every invocation requests help.

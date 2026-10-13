# Foreground Android ready exit leaks the CLI-owned ADB forward

Severity: resource cleanup / lifecycle contract. Owner: Task4 CLI follow-up. Candidate: CLI `fb7af9d1702cd4f294aae48eb5f1ed52dbfe2d88`, runner `ff68658f73e4b6d9d94897d99ad1a0a270a105b7` (`1.1.28-grantiva.14`). Status: confirmed during Task8 bounded smoke; fix in progress.

A foreground Android runner session must release its exact CLI-owned driver attachment when it ends, including SIGINT and normal exit, without removing unrelated forwards. The original combined smoke found tcp55149 remaining after ready-state interruption. Isolated reproduction began with no forward, recorded a ready session on port55809, sent SIGINT to the exact CLI PID, and observed exit130 and absent project session while tcp55809→tcp6790 remained immediately and one second later. Controller then removed only tcp55809.

Raw proof: `findings/evidence/round4-smoke/03-lifecycle/ready-forward-repro/` (argv, process identity, ready session, before/ready/after/+1s forwards, exit, and exact cleanup). The clean-baseline absent-app control under `absent-forward-repro/` has no leaked forward; the original later absent-app assertion merely exposed the inherited leak.

The successful DriverAttachment is reduced to a port in the foreground path, losing its detach callback. The runner uses a local-filesystem forward and cannot clean the independently allocated CLI TCP port.

Acceptance:
- A production-path semantic regression fails at the candidate before the fix and proves attachment detach occurs exactly once for foreground interruption and normal exit.
- Preserve startup failure/cancellation cleanup, iOS behavior, existing flags/JSON, exit130 and the exact platform SIGINT notice.
- On an owned Android AVD, capture empty baseline, ready attachment identity/port, SIGINT exit130, immediate and delayed absence of that exact forward, absent project/global session and runner PID.
- Exercise normal foreground stop and an absent-app control; neither leaves its owned attachment. An unrelated forward remains untouched by exact attachment cleanup.
- Focused/full fresh-home tests, independent review, CI, merge and rebuilt candidate must pass. Task8 and Task9 cannot be declared clean on the leaking candidate.

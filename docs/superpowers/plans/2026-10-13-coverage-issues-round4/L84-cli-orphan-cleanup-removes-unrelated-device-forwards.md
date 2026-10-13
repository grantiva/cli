# CLI orphan cleanup removes unrelated forwards on the same device

Status: confirmed during isolated L82 live verification; Task4 CLI ownership follow-up. Source CLI015521cb (PR213), runnerff68658f/.14. Separate from runnerL83's remote-number deletion.

Governing live trace: findings/evidence/fix4-84/normal-stop-trace. Controller created unrelated allocated local tcp60632→remote tcp16791 on owned emulator5582, verified it before start and alongside ready owned attachment tcp60776→tcp6790. `runner stop` PID72089 then called `forward --list` and `forward --remove tcp:60632` after exact owned port60776 was released; foreground exited0, unrelated forward was absent. Each ADB invocation has argv/PID/PPID/time through a scoped SDK shim that execs the real ADB. No product source was instrumented.

The parallel governing startup/SIGINT control under fix4-84/startup-trace preserved its unrelated forward and exited130 with exactownedportcleanup. The initial untraced live-acceptance attempt lost control59633 before the ready snapshot but has no attributable remover; retain it as a failed/unresolved attempt, not proof that runnerstart invokes generic cleanup.

AndroidPlatform.cleanupOrphans currently calls ADB.removeForwards(serial:), which enumerates/removes every TCPforward belonging to that serial, regardless of purpose. Device scope alone does not establish driver ownership. Identify startup/stop callers and limit driver orphan cleanup without altering explicitly destructive full emulator teardown semantics.

Acceptance:
- Source-compatible production regression demonstrates unrelated same-device forward removal and passes after scoped ownership-safe cleanup. Cover startup and runner stop/orphan paths, preserve other-device forwards and exact owned driver cleanup.
- Do not use remove-all or delete arbitrary same-device TCPforwards. Cleanup must have driver ownership evidence; explicit full emulator teardown may retain its existing device-removal contract. Preserve public flags/JSON/exits, app readiness, startup interruption, and L82 attachment completion.
- On owned Android, an unrelated allocated TCPforward to tcp16791 survives ready startup, SIGINT, normal foregroundstop, absent-app failure and healthy stock. Exact owned CLI/runnerforwards and sessions/PIDs disappear after each ending; retain immediate/delayed inventories and baseline/control creation.
- Focused/full freshhome Swift tests, independent source/live review, CI, merged/rebuiltcandidate and completeTask8smoke are mandatory. Original failedcontrol remains immutable; Task9 stays gated.

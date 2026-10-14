# B-D07.1 candidate5 clause assessment

Verdict: **PASS**.

Expected: docs/android.md §Devices drops "Only running emulators are considered by default" and states the order: configured AVD (running, else booted); otherwise one running emulator, one booting emulator, or the only AVD (booted); otherwise an error listing AVDs. (brief D07)

Fresh candidate5 public/docs or exact-current-source evidence satisfies the named clause without compiler/live work. Evidence: `B-D07.1-run-1/inspect.command.json`.

# Simulator Lifecycle: Orphan Incident and Remediation

_2026-08-22. Status: code fix landed on branch `simulator-lifecycle-cleanup`; release and agent-fleet actions below still open._

## What happened

On Aug 21–22 the machine accumulated **54 orphaned simulators** named `TienLen Flow <session>`, including 12 identical `TienLen Flow APP-652` devices created roughly one per agent retry over a single day. All 52 shutdown orphans have been deleted; two booted sims belonging to live runs were kept.

## Root cause

Two independent gaps, one in the card-of-war flow scripts and one in this CLI:

1. **Stale flow scripts bypassed Grantiva entirely.** The pre-1.6.0 `Scripts/flows/run-flow.sh` (still present in old card-of-war worktrees `app-813`, `app801`, `app-812`, `app459`) "reuses" a simulator via a UDID cache file at `$TMPDIR/tienlen-flow-sessions/<session>/simulator-udid`. Paperclip agent runs get a fresh `TMPDIR` each run, so the cache is never found, and the script falls through to a raw `xcrun simctl create "TienLen Flow $SESSION_KEY"` on every run. Its `--teardown` reads the same missing cache, so it can never clean up either.
2. **The CLI never deleted what it created.** `grantiva simulator teardown` only shut simulators down. Nothing recorded which devices Grantiva created, so nothing could safely garbage-collect them. Additionally, `ensure`'s look-up/create pair had a cross-process race: two concurrent runs asking for the same new name could both see "not found" and both create, producing same-name duplicates that then make every later `ensure` fail with "Multiple simulators are named …".

## What is already fixed (branch `simulator-lifecycle-cleanup`, commit `90d2acb`)

- **Provenance ledger.** Every simulator `ensure` creates is recorded in `~/.grantiva/simulator-capacity/created.json` (flock-protected). User-created devices are never in the ledger and are never deleted by any of the paths below.
- **Race-free `ensure`.** The look-up/create critical section now runs under a cross-process provisioning lock. Verified: two concurrent `ensure` calls for a brand-new name yield exactly one device (`Created` + `Reused`).
- **Teardown deletes.** `grantiva simulator teardown --session-id <id>` now deletes Grantiva-created simulators outright and only shuts down pre-existing devices the session merely booted. JSON output gained a `deleted` flag per session.
- **New GC command.** `grantiva simulator cleanup` deletes every Grantiva-created simulator that is shut down and not part of an active managed session, and prunes ledger entries for devices that no longer exist. Safe to run any time, including from cron or an agent heartbeat.
- Tests: `SimulatorProvenanceTests` (ledger + lock serialization) and extended `SimulatorCommandTests`; full suite passes.

## What still needs doing

### Grantiva (this repo)

1. **Review and merge** `simulator-lifecycle-cleanup` into `main` (self-review model applies; this is CLI-only, no SDK API or migration surface).
2. **Ship 1.6.5** so the installed Homebrew binary (`/opt/homebrew/bin/grantiva`, currently 1.6.4) picks up the fix. Follow the usual release process, then verify with `grantiva --version` and a `simulator cleanup` dry run on the host.
3. Optional hardening: schedule `grantiva simulator cleanup` periodically (launchd or a Paperclip routine) so any future leak self-heals.

### card-of-war / Paperclip fleet

1. **Purge or rebase the stale worktrees** that still carry the raw-`simctl create` script: `.worktrees/app-813`, `.worktrees/app801`, `.worktrees/app-812`, `.worktrees/app459` (and `collect-store-screens.sh` / `capture-invite-rematch.sh` in those trees, which have the same pattern). Any agent pinned to those trees will keep leaking simulators until then.
2. **Policy for agents:** provision only through `grantiva simulator ensure --name <name>` and end every session with `grantiva simulator teardown --session-id <id>`. Never call `xcrun simctl create` directly from flow scripts.
3. The current `main` version of `Scripts/flows/run-flow.sh` already complies; no change needed there.

## Verifying health later

```sh
# Everything Grantiva currently manages (booted / pending)
grantiva simulator sessions

# What Grantiva created and hasn't deleted yet
cat ~/.grantiva/simulator-capacity/created.json

# Reclaim orphans
grantiva simulator cleanup

# Spot leaks from non-compliant scripts (should stay near zero)
xcrun simctl list devices | grep -c "TienLen Flow"
```

## Runner ownership and interrupted runs (2026-08-28)

A separate lifecycle gap, reported from a two-simulator concurrent E2E setup:
cancelling a `grantiva run --keep-alive` left `grantiva-runner`, WebDriverAgent's
`xcodebuild test-without-building`, and a `simctl diagnose` alive and still
owning the simulator, while `grantiva simulator sessions` reported nothing.

### Root cause

Two independent things, neither of them the capacity ledger:

1. **The interrupt never arrived.** grantiva installed no signal handler. A shell
   running a script starts asynchronous commands (`grantiva run … &`) with SIGINT
   and SIGQUIT set to `SIG_IGN`, and children inherit that disposition — so
   `kill -INT` against a backgrounded keep-alive run did nothing at all. grantiva
   kept running and kept holding the simulator lease, which is what produced
   "Simulator … is already owned by another Grantiva run" on the next run.
2. **Nothing reaped the descendants.** Even when grantiva did die, the runner and
   everything it had started (WebDriverAgent, `simctl diagnose`) shared grantiva's
   process group and were never signalled as a unit.

The two ledgers legitimately disagree, and that is by design: `sessions.json`
records **boot capacity** — simulators grantiva booted — while the lease file
under `~/.grantiva/runner/locks/<udid>.lock` records **runner ownership**. A run
against an already-booted simulator has a lease and no session record. What was
missing was a way to see and act on the lease.

An earlier theory — that the lease descriptor leaked into the runner because it
was opened without `O_CLOEXEC` — was tested and **disproved**: both
`Foundation.Process` and grantiva's spawn path use `POSIX_SPAWN_CLOEXEC_DEFAULT`,
so the descriptor never reaches a child and the lock is released when grantiva
exits. `O_CLOEXEC` was added anyway as defence in depth.

### What is fixed

- **The lease names its owner.** grantiva's pid, the runner's pid, and whether the
  run is `--keep-alive` are written into the lock file when the claim is made and
  cleared when it is released, including on signal. The "already owned" error
  quotes them and names the command that frees the device.
- **The runner gets its own process group,** and SIGINT/SIGTERM are forwarded to
  the whole group, so one interrupt takes down grantiva-runner, WebDriverAgent,
  and any diagnostics with it. The handler is installed only on paths that spawn
  a runner, and replaces an inherited `SIG_IGN` so a backgrounded run can be
  interrupted at all.
- **`grantiva simulator teardown --udid <UDID> --force`** reclaims a device by
  live process inspection when the ledger has nothing to act on: it kills the
  runner / WebDriverAgent / `simctl diagnose` processes carrying that UDID,
  breaks the lease, and clears any stale capacity record. It replaces a
  hand-written `pkill` trap.

### Verifying health later

```sh
# Who owns a simulator right now
cat ~/.grantiva/runner/locks/<udid>.lock

# Reclaim it regardless of what the ledger says
grantiva simulator teardown --udid <UDID> --force
```

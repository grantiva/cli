# Task 8 CLI-owned Android forward cleanup report

## Outcome

Implemented L84 on PR #213 from the approved L82 review base `015521cb75ff46b19aa66790300d6c85d2bd6e3b`.

Final source commit: `a587581723ec2599e0247c186d27667951959d9e`.

Routine Android runner cleanup no longer enumerates or removes every TCP forward on the device. It still force-stops the two UIAutomator2 packages. Stop paths remove a TCP forward only when the session recorded that exact local port. Unknown and zero ports are preserved, iOS requests no Android cleanup, and full emulator teardown retains its existing device-wide forward removal.

## Production cause and ownership boundary

`AndroidPlatform.cleanupOrphans(deviceID:)` previously called `ADB.removeForwards(serial:)`, which listed every TCP forward for the serial and removed every listed local port. A device serial is not proof that Grantiva owns a forward.

The immutable `015521cb` normal-stop trace confirmed the production failure. An unrelated `tcp:60632 -> tcp:16791` control survived startup and was present at ready beside the owned `tcp:60776` port. After `runner stop`, the trace records the CLI listing forwards and removing `tcp:60632` after its own `tcp:60776` had already detached; the final inventory was blank. Evidence is under `findings/evidence/fix4-84/normal-stop-trace/`.

The immutable startup/SIGINT trace separately shows the unrelated control surviving both startup and SIGINT while the owned CLI port is removed. Therefore the earlier ready-time loss is preserved as an observed but unattributed, non-governing attempt. Current source and traced behavior do not support claiming a startup cleanup call.

The fix separates routine process cleanup from forward ownership:

- `cleanupOrphans` force-stops stale UIAutomator2 packages without listing forwards;
- `removeOwnedForward` accepts one recorded positive local port and removes exactly that port;
- `RunnerStopCommand` passes the ready `RunnerSessionInfo.wdaPort`, or no port for a starting session;
- `RunnerSessionStopper` passes a positive published `KeepAliveSession.port`, and passes the ready runner-start session port during device teardown session stopping;
- normal and signal `RunnerSession` cleanup has no TCP ownership evidence and performs no TCP deletion;
- `EmulatorManager.stop` remains explicitly destructive and retains serial-wide removal when tearing down the emulator itself.

L83, the runner's local `tcp:6790` cleanup, is separate and unchanged here.

## Semantic RED/GREEN

The source-compatible RED changed the existing real `AndroidPlatform`/`ADB` scripted-shell test to require preservation of an unrelated same-device `tcp:61211 -> tcp:16791` forward. On base production behavior it compiled and failed because the command log contained both `forward --list` and `forward --remove tcp:61211`.

With the production fix, the same test passes and records only the two UIAutomator2 force-stop commands. A second production-seam test proves exact recorded-port cleanup emits only `forward --remove tcp:61211`, without listing or broad removal.

- RED source SHA-256: `c124fc47a7d8d051a1de5615cdac7ea473e37d2a0e9a635349b02e7def348058`; transcript SHA-256: `6aee1adf0a592a487d85718cda117c949288c1581aa9d34a127b1a8c9c726784`.
- GREEN/scoped source SHA-256: `804fd657aa890854970a8dc9c8b1d5b65fc72763a34232810ca5d87e881bf603`.

## Validation

- Focused Android platform, normal/signal session cleanup, stopper, runner stop, and L82 lifecycle suites: 128 tests, 0 failures (Core 54, CLI 74). Transcript SHA-256: `b2f43e7918754fe57349803b929e65be50de71bf332086a2354aa42cb66aa8dc`.
- Full Swift suite: 2,022 tests, 0 failures (MCP 281, Core 973, CLI 667, API 101). Transcript SHA-256: `d7f57cffea81962ec766d33edf6974651e49a841db50fedfbfc531447fcd9140`.
- `git diff --check`: clean.
- Governing runs used separate fresh homes, literal `GRANTIVA_SESSION_ID=fix4-84`, and unset API environment variables. The final full home remained absent/empty.
- The scoped `015521cb..a5875817` source diff SHA-256 is `804fd657aa890854970a8dc9c8b1d5b65fc72763a34232810ca5d87e881bf603`; the complete `fb7af9d1..a5875817` source diff SHA-256 is `03623231553cf9e9aa03f5970ed559e665be4c0c02b028b360086527255b2fe5`.

Raw source, transcripts, metadata, and checksums are under `findings/evidence/fix4-84/`. Earlier focused/full attempts remain preserved separately and are non-governing.

No device commands were run by the source author. Controller owns integrated live acceptance on the rebuilt candidate.

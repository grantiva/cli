# B3-L09 candidate5 clause assessment

Verdict: **PASS**.

Expected: `init` writes `emulator: Pixel_8_API_35` and prints one `Warning:` line naming the AVD, saying runs from this directory will boot and drive it, and suggesting a name of your own (`Grantiva_Pixel_8_API_35`, `grantiva emulator ensure --name Grantiva_Pixel_8_API_35`); exit 0. • The iOS and Android warnings share one sentence shape (`<A> <noun> named <name> already exists and was not created by Grantiva; runs from this directory will boot and drive it.`). • No warning when the AVD is absent or recorded: checked in InitAndroidTests (source check; the absent case cannot be produced without deleting the owner's AVD) (brief L09; docs/android.md init paragraph)

The retained current-candidate outputs were inspected against the clause, including expected nonzero validation/error exits where applicable.

- `B3-L09-run-1/config.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `config.stdout`, `config.stderr` retained.
- `B3-L09-run-1/init.command.json`: exit 0, timedOut=false, cleanupFailed=false; raw `init.stdout`, `init.stderr` retained.

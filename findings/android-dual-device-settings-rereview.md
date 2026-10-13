# Android dual-device and settings correction review

Reviewed retained round-3 raw only against the exact round-3 matrix clauses. No runtime commands were rerun.

## Supported grades

- **AND-052:** supported. `start-primary` and `start-secondary` establish two live exact-serial sessions; secondary starts last. The secondary readiness capture contains the Landmarks app, and untargeted `AND-052` hierarchy exits 0 against the same app tree. This demonstrates newest-session selection, even though the XML also contains System UI nodes.
- **AND-056:** supported. With both sessions live, the command explicitly passes `--udid emulator-5554`; its output is the primary Landmarks app tree and exits 0.
- **AND-062:** supported. `AND-062-primary.commands.txt` and `AND-062-secondary.commands.txt` target emulator-5554 browse and emulator-5556 category concurrently. The recorded shell PIDs overlap, both exit 0, and their separate outputs/reports contain the expected eight-step and six-step passing bodies.
- **AND-064:** supported. Before and after inventories are byte-equivalent and contain only the guarded other-serial mapping `emulator-5556 tcp:28123 tcp:6790`; the primary emulator-5554 browse run passes. Cleanup therefore leaves the other serial's orphan mapping untouched.
- **AND-067:** now supported by `android-settings-browse-exact-rerun2/AND-067-browse`. The exact `.maestro/01-browse.yaml` run exits 0; captured prior/live/after values show application and restoration, and the state file is absent afterward.
- **AND-145:** now supported by `android-settings-browse-exact-rerun2/AND-145`. The exact `.maestro/01-browse.yaml` run includes `--allow-device-settings`, exits 0, observes the state file and applied settings during execution, then restores prior values and removes state.

## Remaining grade gap

- **AND-057 is overclaimed by the current evidence.** The matrix expects comparison of `adb forward --list` before/after with a local forward to 6790 existing only for the hierarchy command. In this batch the hierarchy runs while a detached live session already owns its recorded local 6790 forward; `AND-057-before.txt` and `AND-057-after.txt` are identical, demonstrating reuse/no leak, not creation for and removal after this command. This is useful lifecycle evidence but does not establish the literal command-scoped-forward clause. Qualify the row unless the controller rules that reuse of a live session forward is the intended behavior.

## Cross-platform corrections

The earlier cross-platform map is corrected as follows:

- X-011 exact sources are iOS attempt 29 `hierarchy-xml.out`/`hierarchy-format-json.out` and Android `AND-053-exact/01.out`/`AND-054-exact/01.out`. Both show the Golden Gate Bridge detail (`Plan Visit`), rather than the required Landmarks list, so the full row remains an input gap.
- X-014 Android has a new `--no-boot` case that prints the AVD name, a reused booted plain case that prints the serial, and a reused JSON case. It lacks a current new-and-booted JSON/plain pair; therefore the row remains a gap rather than an automatic pass.

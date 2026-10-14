# Android next canonical core routing

Source of order and clauses: controller `findings/evidence/completion-coverage/required-keys.json`, `slices.android` (522 keys). This is static preparation only and authorizes no command.

The next canonical 40-key span after AND-018 is exactly AND-109, AND-146, AND-110, AND-019–025, AND-111–113, AND-143–144, and AND-026–050. It ends before AND-114. Numeric-only batching would miss the inserted keys.

Lifecycle quiet-window keys:

- AND-109: requires exact secondary ownership and an authenticated manual `avdmanager` delete after Grantiva creation, followed by a product call proving ledger pruning.
- AND-146: requires a stopped Grantiva-created secondary and exact post-delete absence.
- AND-110: compound documentation example; its `--all` leg remains blocked. Other lifecycle examples require the allocated primary/secondary identities.
- AND-029, AND-032, and AND-036 change or depend on emulator boot/selection state and need serialized device state. AND-032 additionally checks the headless process argv.
- AND-049 is a timed cancellation measurement and AND-040/046 are crash/continuation measurements; reserve a quiet timing window and retain host load.

Compiler/build window keys:

- AND-019–025, AND-111–113, AND-143–144 require the controller's serialized fresh scratch-demo build window and exact frozen-APK restoration afterward.
- AND-026–030 and AND-032 require build or install behavior unless their literal precondition supplies the frozen APK. AND-028 is the explicit frozen-app-file/no-build path.
- AND-034–050 generally exercise real run/report behavior and must use the frozen APK with `--no-build` where the literal clause permits. A command that explicitly tests building must stay in the serialized build window.

Device-free or pre-device candidates within this span are AND-024's invalid Gradle variant only after its build window is granted, AND-031 (empty work, ready failure), and AND-033 (uncreatable ready-file parent). Their raw captures still need the standard candidate identity and before/after device inventory required by the row.

The external secondary currently live as `cov5-android-2`/`emulator-5556` PID 71427 is an AND-018 control and must not be adopted, signaled, or repurposed outside the next explicit reservation. The primary remains `cov5-android`/`emulator-5554` PID 56881 generation 1.

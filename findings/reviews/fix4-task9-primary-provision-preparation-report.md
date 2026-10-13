# Task 9 primary provisioning preparation

## Scope and gate

Prepared `task9_primary_provision.py` as an executable SDD-only controller helper. It was not executed. No device, worktree, build, test, product source, candidate, runner home, or durable evidence was changed.

The helper requires explicit `--candidate`, `--gate-evidence`, and fresh `--output` paths. Before creating the output or running any command, it requires candidate schema `grantiva.task9.candidate.v1` and gate schema `grantiva.task8.zero-gate.v1`, literal `passed: true`, an exact SHA-256 binding to the supplied Task 9 candidate manifest, and existing review and cleanup artifacts whose hashes match the gate. The cleanup artifact must itself be JSON with `passed: true`. This leaves the current gate unasserted: the controller must populate the actual reviewed paths and hashes after Task 8 closes.

The candidate shape preserves the Task 8 candidate's `cli`, `runner`, and `demo` identity structure under the new Task 9 schema. Before any inventory or mutation, the helper validates the frozen CLI binary, complete resource-bundle file manifest, source iOS app file manifest, and frozen Android APK hash. It takes the runner home only from that supplied manifest and exports it explicitly with session `cov4-controller`, an unset API key, Android SDK paths, and Java 21.

## Ownership and provisioning

Before the first mutation, the helper captures simulator, AVD, adb-device, and forward inventories; requires both `cov4-ios-*` names, `cov4-android`, and `emulator-5584` to be unused; proves local ports 5584 and 5585 are free; snapshots the two protected simulator records while excluding only dynamic size fields; and records the protected `Pixel_8_API_35` config hash.

It creates only:

- `cov4-ios-26`, iPhone 17 on `com.apple.CoreSimulator.SimRuntime.iOS-26-0`;
- `cov4-ios-27`, iPhone 17 on `com.apple.CoreSimulator.SimRuntime.iOS-27-0`;
- `cov4-android`, Pixel 8 with `system-images;android-35;google_apis;arm64-v8a`, launched only as `emulator-5584` on port 5584.

Each create command is placed into `ownership.json` before invocation, then receives its exact start/end timestamps and exit immediately afterward. Each successful iOS creation records its literal UDID before boot, readiness, and install. Both installed app containers must reproduce the frozen iOS file manifest. Android ownership is recorded immediately after AVD creation, and the exact emulator PID/argv are recorded before waiting for readiness. Installation uses the frozen APK; its source and expected hashes plus installed package paths are recorded.

Every bounded command now records terminal timeout evidence. A `TimeoutExpired` capture writes any partial stdout/stderr plus a result containing `timedOut: true`, the configured timeout, end epoch, and timeout outcome before re-raising. Android boot-property reads use individual timeouts of at most three seconds inside a 120-second monotonic deadline. The helper persists whether that deadline ended ready or timed out.

Before acceptance, the helper captures fresh simulator, AVD, adb-device, and forward inventories and rehashes the protected Pixel config. It writes `post-provision-comparison.json` before enforcing the comparison, so a mismatch remains durable failure evidence. Acceptance requires unchanged normalized records for both protected simulators, the exact protected Pixel hash, exactly the two owned simulator-ID additions, exactly the owned AVD/serial additions, no device removals, and exact equality of the complete adb forward table. Forward normalization trims whitespace, collapses whitespace separators, and sorts rows; it retains every entry and duplicate.

The helper contains no global shutdown, teardown, signal, process-pattern kill, protected-device mutation, default runner-home write, source build, or cleanup command. A later cleanup helper can consume `grantiva.task9.primary-ownership.v1`, including partial ownership left by a failed provisioning run.

## Static and synthetic verification

- Python compilation and AST parsing passed.
- Static checks confirmed all exact names, runtimes, device type, image/device identifiers, serial, port, session, and Java 21 binding.
- Ordering checks confirmed gate validation and all baseline/unused checks occur before the first device create.
- Ownership ordering checks confirmed pending command records precede creation and owned identifiers/PIDs precede boot waits.
- An extracted synthetic timeout call confirmed partial streams and terminal timeout metadata are written before `TimeoutExpired` is re-raised.
- Static and synthetic deadline checks confirmed each boot-property poll is capped at three seconds and the whole readiness window uses a 120-second monotonic deadline.
- Synthetic before/after inventories confirmed only the two recorded iOS IDs and exact Android AVD/serial satisfy the addition predicate; protected simulator or Pixel hash changes fail before acceptance.
- Forward-table checks accepted only whitespace/order differences and rejected an added, removed, or changed entry before acceptance.
- Forbidden global command and broad-signal strings are absent.
- A synthetic zero-gate with a Markdown review and passing cleanup JSON was accepted by the specified schema logic. Negative cases for `passed: false`, candidate hash mismatch, review hash mismatch, and cleanup `passed: false` were rejected.

The gate schema has no preparation blocker: the independent review may remain a hash-bound document, while cleanup is the referenced machine-readable passing JSON. The controller still must create the final gate and Task 9 candidate; this preparation does not claim either exists.

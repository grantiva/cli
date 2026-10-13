# IOS-058 contract triage and secondary-AVD lifecycle review

## IOS-058: stale matrix expectation, preserve the recorded fail until Task 6

The attempt-29 observation is reliable: the browse flow had already passed and the keep-alive hold was armed; SIGINT then released the hold, exited 0, and left both group and flow `passed`. This contradicts IOS-058's literal demand that the ready file become `interrupted`, so the current fail must remain until the matrix is corrected.

It does **not** support a product defect. The later binding rulings explicitly distinguish interruption during flow execution from release after the hold:

- coverage-pass plan line 34 / B3-L36.2: during-flow stop records `interrupted`; after the hold is armed, release exits with the earned status and keeps `passed`/`failed`;
- coverage-pass plan line 49 / B3-L56.1: release after a completed passing hold exits 0, never 130; a completed failing hold exits 1 and preserves its failure summary.

IOS-058 still carries the older unconditional-interruption wording even though its setup says the ready file is present and its sibling IOS-047 defines that point as the post-flow hold. Proposed Task 6 correction: require the same cleanup as Ctrl-C, exit with the earned status, retain terminal `passed`/`failed`, and require no flow to remain `running`. Keep a separate during-flow row for `interrupted` behavior (already B3-L36.2/B3-L56 coverage). This changes the expectation classification only; it does not erase the exact attempt-29 raw evidence.

## Secondary AVD lifecycle verdict

Approved: the newly graded AND-003/004/005/006/007/008/009/010/014/109/146 rows match their exact matrix clauses.

- AND-004 establishes a fresh, distinct `cov3-android-2` with `--no-boot`; stdout is exactly the name and the immediate adb inventory contains only primary emulator-5554.
- AND-005/006 use the preserved config's `emulator: cov3-android-2`; the booted secondary is emulator-5556 and its exact QEMU process contains `-no-window`.
- AND-007's retained AVD config identifies `android-35`, `google_apis`, and `arm64-v8a` with no system-image override.
- AND-003 re-ensures the same name and returns the same emulator-5556 serial.
- AND-008 and AND-009 retain decoded JSON: ensure reports the named secondary, serial, Booted state and `created:false`; sessions lists both campaign-started AVDs with live PID/serial/state fields.
- AND-010 targets emulator-5556, stops its owned runner, removes its forward/session, and kills that AVD. The post-teardown adb inventory still contains primary emulator-5554.
- AND-014/146 returns valid `{deleted:true,name:"cov3-android-2"}` and the retained post-delete AVD inventory omits the secondary.
- AND-109 recreates the secondary, deletes it externally, then retains `created-after.json` as only `["cov3-android"]`, proving next-call pruning.

The before/final AVD inventories are identical and retain both pre-existing primary entries (`cov3-android`, `Pixel_8_API_35`). `started-before.json` and `created-before.json` establish primary ownership state, while the final cleanup leaves the primary AVD and its emulator intact. No unsupported rows or lifecycle side effects were found in this completed batch.

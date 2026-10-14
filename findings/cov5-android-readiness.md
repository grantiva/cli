# cov5 Android slice readiness

Status: **PREPARED, NOT AUTHORIZED TO EXECUTE**.

The fresh worktree is `cov5/android` at base `6bfa12d3`. The slice is bound to candidate4 manifest SHA-256 `714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783`, QA CLI SHA-256 `2a4e90e655b2a43234b4c1c5cac403042df17aa43e3e6bd0d011743e38fb9fb5`, runner home `/private/tmp/grantiva-completion-candidate4-x_i_t3pq/runner-home`, and session `cov5-android`.

Device allocation is intentionally unresolved. The capture wrapper refuses to run while any primary/home/extra placeholder remains unknown. Root must supply the fresh home, exact primary AVD/serial/PID, reserved extra name, protected-device inventory, candidate smoke-gate approval, and standing lifecycle/build/quiet delegations before execution.

The approved stable manual-emulator helper was copied unchanged at SHA-256 `6d4a99694878ccbe9b5a3790b0bfc869a0b961724128c8a3313800d9254a1397`. Its fix1 snapshot and fix1-to-fix2 diff are retained alongside it. It remains fixed to the previously approved extra literal and port, so root must either allocate that exact name/port or issue a reviewed rebinding before any use.

Known blocked expectations are carried without execution: `AND-002` missing-image environment, `AND-012` forbidden global teardown, `AND-088` credentials, `B-I06.2 [android]` unobservable `/wda/keys`, and `N-08 [android]` root requirement. Environment changes may alter only the controller-approved disposition; the slice will not manufacture them.

No live command, app build, source test, device inventory, adb/emulator operation, network action, result grading, or old-pass transfer occurred during preparation. The results file has not been created, so all 522 Android keys remain ungraded.

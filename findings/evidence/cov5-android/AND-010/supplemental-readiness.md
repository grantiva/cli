# AND-010 missing-clause supplemental readiness

The first capture proves authenticated targeted teardown of owned PID 59061, removal of its started-ledger record, serial absence, and no remaining forward. Its `before-forwards.stdout` is empty, however, and there is no active UIAutomator2-server precondition. It therefore does not physically exercise the matrix clauses that teardown stops UIAutomator2 and removes that serial's forwards.

Preserve every first-capture file. During the next controller-authorized exclusive Android window, execute only this missing leg:

1. Authenticate the then-current external `cov5-android-2` PID/serial/AVD identity. With explicit lifecycle authorization, target-force teardown that exact external process and prove PID/serial absence and fixed-port release.
2. Ensure the existing `cov5-android-2` through Grantiva and bind its replacement PID, start time, executable, argv, serial, AVD name, and started-ledger record.
3. Start the Android runner detached against that exact serial and frozen application ID: `grantiva runner start --platform android --device emulator-5556 --application-id com.kylebrowning.landmarks --detach --json`.
4. Prove the session/runner identity, the live UIAutomator2 package/process state, and at least one exact `adb forward --list` entry for `emulator-5556` before teardown.
5. Run the literal targeted `grantiva emulator teardown --serial emulator-5556` once. Capture its raw result, bounded runner/session termination, authenticated emulator PID death, serial absence, started-ledger pruning, and exact absence of every previously recorded `emulator-5556` forward.

Do not repeat AND-011–018. Do not use `--all`, pattern signals, or a foreign device. This supplemental leg requires an active exclusive Android lifecycle window and must retain host load and all candidate identity records.

# Android AND-010–018 static readiness

The approved stable manual-emulator helper was copied unchanged as `tools/stable-manual-emulator.cov4-before.py` (SHA-256 `6d4a99694878ccbe9b5a3790b0bfc869a0b961724128c8a3313800d9254a1397`) and rebound only from AVD `cov4-android-2` to `cov5-android-2`. Port `5556` and derived serial `emulator-5556` remain explicit.

Prepared helper SHA-256: `e33151977d9d0fd20d354b6f98167d340310b3116320f0cc95a9d7c0d5ed731d`.

Rebind diff: `tools/stable-manual-emulator-cov4-to-cov5.diff`, SHA-256 `47e24006533d25594628dbe6e09f06d3ed3067a807c32572ffde233a97fa1987`.

`python3 -m py_compile` passed. This preparation performed no emulator, adb, device, build, or network command. Live execution remains gated by the controller's exclusive Android window and the prepared reservation.

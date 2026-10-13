# Android N2-06 parent review

PASS. The seven exact environment modes use a row-created AVD and record its actual qemu argv, with teardown between modes. Captured stdout with CI/headless unset opens a window; CI=true and CI=1 are windowless; CI=0, CI=false and CI=empty open a window; GRANTIVA_EMULATOR_HEADLESS=1 is windowless. All seven match their literal expected rule. Preserved emulator/run/build helps and docs describe that stdout alone never implies headless. The AVD is removed afterward and primary emulator5554 remains.

Evidence: cov3-android/findings/evidence/cov3-android/N2-06-headless-matrix-rerun1/. K27's additional real-TTY leg remains separate and is not inferred from the captured-stdout case.

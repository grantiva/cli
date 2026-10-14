# CLI-147 candidate5 clause assessment

Verdict: **PASS**.

Expected: `--serial and --all are mutually exclusive; pass one.` (64); `--serial <udid> is a simulator UDID, not an emulator serial. Use `grantiva simulator teardown` for simulators.` (src EmulatorCommand.swift:146,154)

Fresh current-candidate raw confirms the required validation/result before compiler or live-device work. Evidence: `CLI-147-run-2/ios-uuid.command.json`, `CLI-147-run-2/mutual.command.json`.

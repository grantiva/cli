# Ambiguous-platform doctor advice appears under Project

Severity: contract
Component: cli / doctor
Row: CLI-025
Candidate: CLI 8f2cff67.
Status: confirmed by the completed round-3 coverage pass; open for the round-4 fix wave.

## Expected

In a directory with both an Xcode project and Gradle settings, without a selecting flag/environment/config, `run` rejects ambiguous platform selection. `doctor` diagnoses both toolchains as advice, reports the Platform ambiguity under Advisory, and exits 0. CLI-025 cites the accepted C12 advice alternative and K35 advisory exit behavior.

## Actual

`run` rejects correctly, and `doctor` exits 0 with the expected warning and selection guidance. The Platform warning appears under Project in text and has `"section": "Project"` in JSON, contrary to the required Advisory section.

## Evidence and repro

- CLI slice `findings/evidence/cov3-cli/CLI-025/commands.txt` records the ambiguous scratch directory, exact run/doctor/JSON commands and exit codes.
- Adjacent `doctor.out` and `doctor_json.out` record the wrong section; the failing-toolchains variant preserves exit 0.
- Candidate `Sources/GrantivaCLI/DoctorCommand.swift:51-59` constructs the warning with `section: .project`.
- `Sources/GrantivaCore/Doctor/DoctorCheck.swift` defines distinct Project and Advisory values.
- Independent triage: CLI `findings/round3-cli-doc-triage.md`.

## Cause

The ambiguous-platform advice is explicitly assigned to the Project section. Do not change the matrix to accept that section; the Advisory requirement is binding.

## Acceptance criteria

- Put the ambiguous Platform warning under Advisory in both text and JSON.
- Preserve the useful selection guidance, advisory toolchain treatment, and doctor exit 0 even when the inspected toolchains are unavailable.
- Keep `run`'s ambiguity rejection unchanged.
- Add or adjust meaningful doctor tests for the text/JSON section and exit behavior, then re-run CLI-025 on the fixed candidate.

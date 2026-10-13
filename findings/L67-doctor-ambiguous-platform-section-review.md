# Independent review: L67 doctor ambiguous-platform section

Verdict: **APPROVE**. The draft is evidence-backed, narrowly scoped, and consistent with the accepted matrix contract.

CLI-025 raw evidence proves every asserted behavior: ambiguous `run` exits 1 with the required selection error; text `doctor` exits 0 but places `Platform` under Project; JSON encodes `section: "Project"`; and the failing-toolchains variant still exits 0. Matrix CLI-025 explicitly requires the warning under Advisory and treats both toolchains as advice. Candidate `8f2cff67` defines distinct Advisory and Project sections, while `DoctorCommand.platformSelection` constructs this specific warning with `section: .project`, directly supporting the stated cause.

The acceptance criteria preserve the correct selection guidance, `run` rejection, advisory toolchain treatment, and exit behavior while changing only the warning's section and requiring meaningful text/JSON coverage. That matches the CLI triage and does not weaken or rewrite the matrix expectation. No unrelated behavior or unsupported claim should be added to this brief.

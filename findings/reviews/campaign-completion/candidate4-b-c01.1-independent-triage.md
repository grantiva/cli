# Candidate 4 B-C01.1 independent triage

Ruling: **expectation/fixture grading conflict, not a candidate4 product regression.** Do not open a product fix solely for the fresh-home lock and empty `versions/` directory.

The CLI actor's run-2 wrapper does not expose the product error because its `cmp before.sha256 after.sha256` fails under `set -e` before the later `cat product.stderr`. The retained inner file at `/private/tmp/grantiva-cov5-cli-gtwQZB/batch8/c01/product.stderr` does contain the expected clean Grantiva error. The wrapper exit therefore proves the before/after mismatch but is not the product exit status.

I reproduced the product once with the exact frozen binary copied alone to a new scratch `bin/`, no adjacent bundle, both runner-home variables pointed to the same freshly empty scratch home, API key unset, and no device/compiler command. Direct `subprocess.run` records exit 1, no signal, empty stdout, and stderr:

> Extracting runner...  
> Error: The grantiva_GrantivaCore.bundle resource bundle was not found next to the grantiva executable, so the embedded runner cannot be extracted. Reinstall grantiva, or keep the bundle beside the binary when copying it.

Candidate binding is exact: source and copied binary SHA-256 are both `2a4e90e655b2a43234b4c1c5cac403042df17aa43e3e6bd0d011743e38fb9fb5`; candidate manifest SHA-256 is `714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783`; the copied bundle path is absent.

The fresh home changes from zero entries to:

- `locks/`
- zero-byte `locks/install-1.1.28-grantiva.15+android-drivers-2.lock`
- empty `versions/`

There is no `versions/<stamp>/` directory, runner payload, version file, driver payload, report, session, or lease. The reproduction evidence is `findings/evidence/completion-coverage/B-C01.1-independent-repro/`.

The literal round-4 matrix sentence still says the scratch runner home must remain exactly unchanged, so a strict reading produces the CLI actor's fail. Later accepted contract documents supersede that strict residue rule:

- K48 explicitly permits the install lock after a fresh failure and requires only that `fresh/versions/` contain no stamp directory.
- L28 calls the fresh missing-bundle half passing when it exits 1 clearly and leaves no `versions/<stamp>/`.
- The accepted round-3 B-C01.1 result applies that interpretation: only the install lock plus empty versions directory remain; the existing install and default home remain untouched.

Candidate4 matches that later contract exactly. The smallest correction is to regrade B-C01.1 against the accepted K48/L28 interpretation or clarify the matrix wording to allow lock coordination metadata while forbidding a stamp/payload. The original run-2 evidence and its strict verdict should remain preserved as the record of the stale expectation.

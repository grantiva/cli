# B2-K48 candidate5 joined clause assessment

Verdict: **PASS**.

Expected: Re-running the repro (fresh home): exit 1 with a message naming the bundle path and saying it is from another release: either both versions (when the runner tarball is present and reports a version) or which expected file is missing (`android-drivers.tar.gz`) plus "Reinstall grantiva so the binary and its bundle match". Never the bare `Runner binary not found` text. • After the failure `fresh/versions/` contains no directory for the stamp (the lock file may stay). • An existing current install keeps working with a mismatched bundle (exit 0, untouched); README:186 is reworded to say the check runs when an install is needed, or `runner install` warns when the bundle beside the binary does not match. • GrantivaCoreTests/RunnerManagerTests: `extractEmbedded` with a bundle missing `android-drivers.tar.gz` throws an error whose text names the bundle path; `installIfNeeded` whose `extract` throws leaves no `baseDir`. (brief K48 Acceptance criteria; Platforms: n/a)

Fresh `../B3-L28-run-1/` proves missing-bundle failure and current-install success. This directory records byte manifests before/after the existing-install command; they are identical. Controller `B-C01.1-disposition.json` supplies accepted fresh-home residue semantics.

No historical runtime verdict is transferred; all runtime references above are current candidate5 captures. Source joins use `/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/reviews/campaign-completion/candidate5-source-evidence-joins.json`.

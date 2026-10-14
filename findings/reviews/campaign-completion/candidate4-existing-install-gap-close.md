# Existing-install preservation gap closure

APPROVED. Fresh candidate4 `cov5-cli/findings/evidence/cov5-cli/B3-L28-run-2/` captures the installed versions tree's file hashes and symlink targets before and after one exact binary-without-bundle `runner install` invocation. All four commands exit0; before/after outputs are byte-identical (598 lines, SHA25660fcc0e2fcb831f8e5975e5ef443f73542c5a25282dbe9afc1a1b981d7eb724f), and the standalone cmp exits0. The direct install uses both runner-home variables bound to the same seeded scratch home and emits the existing-install warning.

This closes the missing current-candidate existing-install-content proof for B-C01.1, B2-K48 and D2-01 when joined with their exact fresh error/bundle clauses and the explicit K48/L28 expectation disposition. It does not erase original insufficient captures or strict B-C01.1 failure. No runtime pass is transferred from an older candidate.

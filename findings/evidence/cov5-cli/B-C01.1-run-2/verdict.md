# B-C01.1 verdict

Result: **fail**

The copied binary without its bundle exited nonzero with a clean GrantivaError and no SIGTRAP, but it did not leave the isolated runner home unchanged: an initially empty home gained `locks/install-1.1.28-grantiva.15+android-drivers-2.lock` plus `versions/`. `before.sha256` is empty while `after.sha256` records the new lock. Run1 is preserved but lacked before/after proof; run2 is the grading evidence.

# CLI-153 verdict

Result: **pass**

The README commands were run in order in the scratch Xcode copy: doctor exited 0; init exited 0 and warned about the unowned default-name simulator; runner install exited 0 against the isolated home; after resolving init’s documented multiple-scheme prompt in the fixture, the exact `ci run` command parsed and ended only at the expected unauthenticated error. `auth login` is n/a. Earlier run1/run2 scheme-fixture failures remain preserved.

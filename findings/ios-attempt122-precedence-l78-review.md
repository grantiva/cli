# iOS attempt122 precedence and L78 scoped review

## Attempt122 / IOS-126

**Approve the IOS-126 pass.** The request called this “IOS122,” but the four-branch precedence row exercised by `cov3-ios-attempt122` is matrix row **IOS-126**; IOS-122 is the separate session-less capacity row already graded from attempt106c.

The attempt122 harness makes each branch discriminating rather than merely observing four successful launches:

- `flag`: config and flow both name `com.example.Cov3Wrong`; `--bundle-id com.kylebrowning.Landmarks` wins.
- `config`: config names Landmarks while both the supplied Wrong.app and flow header name the wrong ID; config wins.
- `appfile`: config omits the ID, the real Landmarks app file conflicts with the wrong flow header; the app-file ID wins.
- `flow`: config omits the ID and no app file/flag is supplied; the literal Landmarks flow header wins under `--no-build`.

All four commands exit 0, all four retained reports identify `app.id = com.kylebrowning.Landmarks`, and all flows pass. Attempt66 adds the variable-header tail: `${APP_ID}` is not treated as a literal ID; no-build fails with the documented guidance, while the build-enabled control detects Landmarks and passes. This exactly covers the matrix order `flag > config > app-file > literal flow header > project detection`, including the variable/no-build boundary.

One evidence-packaging defect does not undermine runtime: `README-precedence.excerpt` captured lines 165–180 and therefore contains alerts/example YAML, not the precedence paragraph. The actual exact-head documentation is `/Users/kyle/Developer/grantiva-cli/.worktrees/release-main/README.md:184`. The ledger should cite that absolute source line or refresh the excerpt; it should not describe the existing excerpt as precedence evidence.

## L78 brief

**Substance and severity are accurate.** The brief stays narrowly scoped to the transient post-SIGINT log-stream lifetime, explicitly says the process disappears within two seconds, preserves IOS-064 as the literal failing row and B2-K33 as passing, and does not claim a persistent leak. Its source hypothesis is framed as suspected and its acceptance criteria avoid broad process-name killing.

One factual path typo should be corrected: the Repro section says `findings/evidence/cov3-ios/run-attempt119b.sh`, but the preserved harness is `findings/evidence/cov3-ios-attempt119b/harness.sh`. The statement that SIGINT targets the recorded positive CLI PID is correct; it was not a process-group signal. No severity or acceptance change is needed.

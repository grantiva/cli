# Invalid historical import — excluded from round-3 grading

These files came from the round-2 iOS evidence directory and do not certify the round-3 QA binary or `.13` runner.

Import command (2026-10-12):

```sh
rsync -a --ignore-existing /Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/evidence/cov2-ios/ findings/evidence/cov3-ios/
```

Because `--ignore-existing` was used, no file already present in `findings/evidence/cov3-ios/` was overwritten. Imported-only top-level directories were moved here intact. The two `ios-round2-*-files.txt` manifests were generated independently by the controller and identify byte-identical and differing paths after the import. Any imported file added inside one of the pre-existing round-3 directories remains there to avoid deleting ambiguous material, but is excluded from grading unless the pre-import inventory explicitly recorded that path.

The copied and mechanically renamed round-2 result table is preserved as `findings/cov3-ios-results.imported-invalid.md`. It is excluded from active results.

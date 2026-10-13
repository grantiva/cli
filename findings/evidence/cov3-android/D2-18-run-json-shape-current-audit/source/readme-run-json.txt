failure messages name flow files as you wrote them or by their project-relative path, never by
the staged copy grantiva hands the runner: `runFlow: 14-runflow-sub.yaml` reads the same in the
text and in `--json`, and so does every file a `runFlow` cycle error lists.

`run --json` has the same shape whether the run passed or failed. `screens`
holds one entry per configured screen (`"kind": "screen"`) and one per flow
(`"kind": "flow"`); each entry has `name`, `kind`, `passed`, `steps` (the
runner's commands with `action`, `status`, `duration` in seconds — `null`
when the runner measured none — and, on failure, `message`) and `screenshots`
(`name` and `path` of each `takeScreenshot` capture; the path is relative to
the working directory when the file is under it, absolute otherwise). The
same `duration` rule holds for `diff capture --json` steps. `reportDir` is present whenever `--report-dir` was
given and the directory exists; `error` appears only on failure:

```json
{"allPassed": true, "reportDir": "/ci/out", "screens": [
  {"name": "01-browse", "kind": "flow", "passed": true,
   "steps": [{"action": "launchApp", "status": "passed", "duration": 1.9}],
   "screenshots": [{"name": "01-browse-cmd-003-Home", "path": ".grantiva/run-captures/01-browse-cmd-003-Home.png"}]}]}
{"allPassed": false, "reportDir": "/ci/out", "error": "Runner failed (exit 1): 02-exact-negative: assertVisible: ...", "screens": [
  {"name": "02-exact-negative", "kind": "flow", "passed": false,
   "steps": [{"action": "assertVisible: ...", "status": "failed", "duration": 12.6, "message": "Element not visible: ..."}],
   "screenshots": []}]}
```

The `error` names the failed step and its message, so it stands on its own
under `--json`. A failure before any flow ran prints
`{"allPassed": false, "screens": [], "error": "..."}`. The exit status stays non-zero.


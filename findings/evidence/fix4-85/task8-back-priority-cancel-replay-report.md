# iOS 26 Cancel replay helper report

Prepared `task8-back-priority-cancel-replay.py` for one reviewed, controller-run diagnostic replay. It has not been executed.

## Binding and scope

The helper requires the existing source manifest and ownership manifest, a controller-created fresh project directory, and a nonexistent output path. Before touching the device it verifies:

- non-final/non-accepted source schema;
- exact CLI HEAD `6cad3f2b4081f0862cd0e93140eda11c2816b9ba`, clean checkout, and literal reviewed release-binary SHA-256 `f9b8161b00049b71b5ffb84176dad97232d89640e24182132e88daffb7c63c78` in both the manifest declaration and actual bytes;
- unchanged runner source and installed runner hash;
- unchanged demo source, frozen app manifest, and identical installed app manifest;
- exact owned iOS 26 UUID `DE2663B5-C24E-42DA-998D-20F7A80054B3`, runtime, name, and `fix4-85` ownership;
- live simulator inventory identity.

It neither creates nor deletes a simulator. It starts the source-built CLI against only the exact owned UUID and records the exact positive runner PID.

## One replay

The MCP client performs readiness, then only `Deep Links → Edit Landmark → Name`. It retains the standard MCP requests, replies, command metadata, stdout, and stderr.

The helper obtains the actual WDA session ID from `GET /status`, then records each production-shaped HTTP operation separately:

1. preferred Cancel predicate;
2. broad Cancel predicate;
3. click of the broad query's first concrete element ID;
4. independent simulator screenshot immediately after the successful click;
5. 500 ms delay;
6. first `GET /source`;
7. one `GET /source` retry;
8. independent screenshot after the two bounded source attempts.

Every WDA operation writes its exact method, URL, body, start/end timestamps, timeout, status/error, and raw response. The HTTP timeout defaults to 15 seconds and is constrained to at most 30 seconds. Source timeouts are evidence rather than helper crashes, allowing the retry and second screenshot to run.

The lookup, click, and `GET /source` paths and bodies match production. The required independent screenshot immediately after click adds a measured subprocess delay before the 500 ms sleep and first source request, so this is a diagnostic decomposition rather than an exact timing reproduction of `UITools.tap`. Its timestamps make that difference explicit.

The helper writes `replay-result.json` with `acceptanceRegraded: false` and `originalFailurePreserved: true`. The original immutable device logs remain at `task8-back-priority-live-26/wda-runner.raw` and `task8-back-priority-live-27/wda-runner.raw`.

## Cleanup

The `finally` block closes MCP, validates the project session still belongs to the exact owned iOS UUID, stops it with the same source binary, waits for the exact recorded runner PID to disappear, and records session/PID cleanup. It explicitly records that no simulator creation or deletion was attempted.

The controller should capture the helper process's terminal stdout/stderr and exit metadata around this invocation:

`python3 task8-back-priority-cancel-replay.py --source-manifest <same-source-26.json> --ownership <same-ownership-26.json> --project <fresh-project> --output <fresh-output>`

## Review

- Helper SHA-256: `12daecfc227bf7e52428b25b91d0c804f00727f22559889c81c4a4ec0127b397`.
- Static validation: Python source compiled in memory successfully; no helper, device, build, or product test was executed.
- Product source changes: none.

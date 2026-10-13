# Android B2-K86-b and B2-K105 review

## B2-K86-b [android]

**Partial: behavior works, but the literal implicit-selection input remains unproven.** `B2-K86-b-live-cli-capture-rerun1` validly proves a detached runner starts and answers hierarchy, CLI `diff capture --no-build` exits 0 with all five named PNGs, the same live session answers `runner dump-hierarchy` afterward, and stop exits 0. The six decoded checks and raw outputs support those facts.

However, `capture.command.txt` includes `--device emulator-5554`. The row's defect and acceptance criterion are specifically about choosing the live runner session's device **with no flag/config simulator**, and the named source test injects a live session with no explicit target. This run bypasses that selection tier, so it cannot close the full row. The smallest complement is the same sequence from a config with no device field and a capture command with neither `--device` nor equivalent environment override, while preserving the post-capture dump. Existing K55/MCP VRT evidence supports session capture semantics but does not prove CLI implicit target resolution.

## B2-K105 [android]

**Approve pass by joined evidence.** `wait-runflow-contracts-rerun1/runflow-{plain,report,json}` already proves both top-level forms print `runFlow: 14-runflow-sub.yaml` and `▸ Run 14-runflow-sub.yaml`, preserve the as-written YAML in report flow data, and resolve from the alternate/configless invocation context. Exact-head resolver and fake-runner tests pin as-written rewriting and invocation-directory resolution.

The new `B2-K105-nested-runflow-rerun1` supplies the remaining nested `commands:` branch. Its frozen input places `runFlow: 14-runflow-sub.yaml` inside `repeat.commands`; the command exits 0. Verbose stderr prints the exact relative `▸ Run 14-runflow-sub.yaml` header, the child tap and assertion pass, and no rewritten absolute sub-flow path leaks. The posthoc decoder correctly captures those six facts. The original wrapper's `asWrittenStep`, `reportNestedRunFlow`, and `subcommandsPass` failures are invalid expectations: the runner represents the outer command as `repeat` in the top-level step/report summary and renders the nested child operations under its live header. The matrix requires the nested reference to map back, not a separate flattened top-level report step. No further runtime is needed for K105.

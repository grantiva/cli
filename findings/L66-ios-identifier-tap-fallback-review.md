# Review — L66 iOS identifier tap fallback

Verdict: **APPROVE**, with one clarification recommended for the fix scope.

The brief accurately reflects the round-3 evidence and candidate `8f2cff67`:

- Two independent live MCP attempts tap `Favorites` and then fail `heart` with `Element not found`.
- The same demo state succeeds through the runner using the explicit predicate `identifier ==[c] 'heart'`, so the evidence rules out a stale fixture as the likely cause.
- Candidate `Sources/GrantivaCore/WDA/WDAClient.swift:245-246` maps the promised identifier fallback to WDA `name` and never queries `identifier`.
- Candidate tests script the second `/elements` response; they verify ordering and the returned `LabelMatch`, but cannot establish that a `name` predicate has identifier semantics on live WDA.
- The brief correctly excludes the malformed coordinate and Edit-navigation attempts from the defect evidence.

The acceptance criteria appropriately require a real-demo reproduction, preservation of ordering/escaping/application exclusion/retry behavior, attribute-level tests, and full reruns of IOS-102, B2-K78, and iOS D2-36.

Recommended clarification: explicitly require updating the misleading `docs/mcp.md` parenthetical and source comment that call WDA `name` the accessibility identifier. The fixed implementation should query the true `identifier` attribute for the identifier leg; documentation should name the actual queried attributes and only retain a `name` fallback if its separate semantics and priority are intentionally specified and tested.

No additional live iOS work is needed to accept this triage brief.

Follow-up review: **ACCEPTED AS UPDATED**. The brief now explicitly requires the
true `identifier` attribute for the identifier leg, updates both the source
comment and `docs/mcp.md`, and requires any retained `name` fallback to have
separate documented and tested semantics and priority. This resolves the sole
clarification from the initial review.

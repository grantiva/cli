# Candidate 2 iOS MCP quoted-label diagnosis

**Diagnosis verdict: HELPER OVER-ESCAPE; NO PRODUCT DEFECT.** The MCP call with label `Mount "Denali"` succeeded and returned the expected decoded user-facing text. The helper incorrectly requires JSON serialization backslashes to remain in `Client.text()` after JSON decoding.

## Evidence

- `04-mcp-ios/helper/active/requests.jsonl` records the wire request as valid JSON: `{"label": "Mount \"Denali\""}`. Decoding that line yields the exact application label `Mount "Denali"`; the backslashes are JSON syntax and are not part of the label value.
- The assertion payload in `invocation/stderr.log` records the successful decoded reply text: `Tapped on "Mount "Denali"". Updated hierarchy:`. The helper had already required `good(reply)` before checking the prefix, so the tool returned a normal result and completed the tap. The updated hierarchy following that text further shows that this was a successful live operation.
- `mcp_client.py` implements `Client.text()` by joining the already-decoded `result.content[].text` strings. It does not return raw JSON bytes. A prefix passed to this function must therefore contain the intended display characters, not JSON escape characters.
- `mcp_smoke.py:47` supplies Python source `'Tapped on "Mount \\"Denali\\""'`. In a single-quoted Python literal, `\\"` evaluates to a literal backslash plus quote. The helper consequently expects `Tapped on "Mount \"Denali\""`, which cannot prefix the correctly decoded product string. The failure at line 51 is fully explained by that mismatch.

## Acceptance-contract comparison

L66 requires label -> identifier -> placeholder priority, application-node exclusion, winning-attribute annotation, and correct literal/quote escaping. “Quotes are escaped” concerns safe predicate/request construction and JSON transport; it does not require user-facing decoded text to display JSON backslashes. The retained request proves correct JSON escaping, while the successful live tap proves the quoted label reached and matched the app element.

Prior final L66 evidence accepted the same decoded behavior. `task-5-demo-final-review.md` records quoted `Mount "Denali"` among the passing final selector sequence, and `task8-persistent-tab-full-live-review.md` records the quoted label annotation/selection matching its helper assertions. Those helpers pass the semantic label as a Python string and assess decoded reply content; they do not require transport escape characters in the decoded text. The stock quoted-label flow also passed with selector value `Mount "Denali"`.

The sequence before this assertion independently reached the quoted row after successful ordinary-label, selected/unselected `heart` identifier, script-tap, and `Name` placeholder cases. Nothing in the failure indicates a selector-priority, escaping, transport, or tap regression. It occurs only in the controller's final decoded-string prefix comparison.

## Disposition

Preserve this failed invocation. Correct the helper expectation to the decoded prefix `Tapped on "Mount "Denali""` (or compare a structured semantic value) before retrying the incomplete remainder of the MCP phase. No CLI, runner, demo, or product change is warranted by this evidence. The completed runner stop with exit 0 is consistent with scoped phase cleanup but does not make the interrupted MCP phase complete.

**Spec diagnosis: the observed product behavior satisfies the bounded L66 quoted-label requirement.**

**Quality diagnosis: the phase failure is caused solely by a helper assertion that conflates raw JSON escaping with decoded content.**

# Scoped review: iOS attempt 58, iOS B3-L23, and Android B2-K08

Candidate provenance: CLI `8f2cff67`; runner `fd9d8e8`. No live calls were made.

## iOS attempt 58

**B2-K109 [ios] is supported.** The five scratch configs separately preserve a 5000 ms visible wait with ID tap/assert, a 2000 ms absent-element wait, a 2000 ms not-visible wait, a 5000 ms exact-text wait, and a no-timeout assertion. The runtime artifacts distinguish these forms rather than inferring them from one command: visible, not-visible, exact and no-timeout variants pass; the absent element exits 1 after about 2.5 seconds with the 2000 ms timeout represented in the staged action/error. Exact-head `MaestroStandardFormsTests.testExtendedWaitUntilKeepsItsTimeout` and the FlowGenerator assertions cover the generated timeout-bearing form.

**B-C08.2 [ios] is supported by the permitted runtime/source join.** `visible-5s.yml` runs `tapOn {id: clock}` and `assertVisible {id: clock}`, and the output names `id="clock"` for both passing actions. Exact-head `MaestroStandardFormsTests.testIdSelectorsAreCarriedForEveryCommand` semantically inspects tap, assertVisible, assertNotVisible, scrollUntilVisible, and extendedWaitUntil ID forms, while its generated-YAML assertions prove those mappings reach FlowGenerator. The row does not claim live execution of all five forms; its remaining forms are satisfied through the plan-authorized semantic source assertion.

## iOS B3-L23

The attempt56 join fully supports the pass. Decoding `mcp/mcp-capture.json` yields eight steps; decoding `bare-capture.out` yields eight steps. Every step in both has a present numeric duration greater than zero. In particular, the Home `Launch app` durations are approximately 3.049 and 3.075 seconds. There are no zero or omitted duration keys, satisfying the stricter whole-document check as well as the Home-specific clause.

## Android B2-K08

The pass is supported. All ten `K08-wait-*` reports preserve the exact `extendedWaitUntil: notVisible text="Loading…"` command, exit successfully, and measure it at 2420–2505 ms, under the four-second runtime threshold. `source/runner-tests.txt` is an exact-head excerpt of `pkg/driver/uiautomator2/not_visible_wait_test.go`: it covers not-displayed and zero-bounds nodes, disappearance during polling, displayed-node timeout within timeout plus one poll, and the still-matched text/bounds error. This is the named runner-test acceptance clause, inspected semantically rather than accepted by test name alone.

No unsupported criterion or new runtime request remains for these four grades.

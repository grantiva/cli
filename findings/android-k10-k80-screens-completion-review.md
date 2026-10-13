# Android B2-K10/K80 screens completion review

`B2-K10-K80-screens-timeout-interrupt-rerun1` is valid evidence. The wrapper's two failed `NoRunning` assertions search serialized text for the word `running`; that is an invalid proxy because the required `summary.running` key must remain present. Decoding gives the required value zero in both cases.

The screens-timeout report is failed with `summary.running: 0`, one failed flow, and the exact timeout error naming screen `Slow`. Its ready file is failed with the flow failed and `reportDir` set; JUnit records failure. Stderr ends with the Grantiva timeout sentence and contains no later interrupt acknowledgement. This completes B2-K10's screens-timeout and B2-K80's screens-finalization variants.

The genuine SIGINT leg proves the process was active, exits 130, narrates the interrupt, and yields report status interrupted, flow status interrupted with `Runner interrupted`, `summary.running: 0`, and a matching interrupted ready file with `reportDir`; JUnit records failure. This completes B2-K80's interrupt variant and B2-K10's genuine-Ctrl-C control.

Joined with the retained flow-timeout evidence and exact-head timeout/report-finalizer tests, B2-K10 `[android]` and B2-K80 `[android]` are fully supported. Wrapper exit 1 reflects only its two malformed string assertions.

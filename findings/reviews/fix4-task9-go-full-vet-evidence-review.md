# Task 9 Go full, vet and L53 scratch evidence review

**APPROVED as retained command evidence within this scope.** Full Go, vet and the L53 scratch control have their expected successful outcomes. This does not make the source window or candidate clean: the separately preserved Swift full-suite failure remains NONPASS, AND-111 is separate, and row joins remain ungraded.

The durable archive is `findings/evidence/round4-coverage/source-window/go-full-vet`; original root is `/private/tmp/grantiva-round4-source-window-1stf8uih/go-full-vet`. All 19 retained files independently match their originals byte-for-byte. Their metadata/raw sizes and hashes match the manifest. Manifest SHA-256 is `aa5d9b521d78d3d8e85bfca2a70b373a14ab64cd495c241a6d91a96e1354f1fb`, agreeing with the archive record.

## Package and source bindings

All five `goInventoryInputs` references were independently rehashed. Package artifact `6f4b340d404022551c2470e89b4f2ebd841aab36885f56ac2fd7a40bead1f6c2` retains the approved review binding and 26 unique ordered literal packages. Full argv is exactly `go test -count=1` followed by those 26 individual arguments; vet is exactly `go vet` followed by the same vector. Neither command contains recursive package syntax or an unresolved marker.

Candidate identity remains `d833797d30a794d8cfe9d2dc4646329d4f791667eb8dfa5d17cf417d827f744e`. Recorded runner proofs agree across command start/postflight and window before/after: HEAD `ba9008f4b2cd2c7320a9c46e04faed612b0958a2`, clean status, 1,383 tracked files, no tracked issues, tree SHA-256 `0441413eb528a92aa1702a76aca00f700b34034f780d2e9f5941d1960a863173`. All three postflights pass without failure reasons. Commands use three separate command-local GOCACHE paths and record the API key unset. No timeout or terminal failure is recorded.

## Observed outcomes

| Operation | Observed result |
|---|---|
| Full Go tests | Exit 0, 401.114 seconds; exactly 24 `ok` package lines and two `[no test files]` lines |
| Go vet | Exit 0, 6.371 seconds; empty stdout/stderr |
| L53 scratch build | Exit 0, 5.927 seconds; empty stdout/stderr |
| L53 explicit empty-device invocation | Exit 64, 0.513 seconds; empty stdout and exact early argument diagnostic |

Full output accounts for every approved package in the approved order. The root module and `drivers` package are the two without test files. Package success is not a per-case/subtest event log and does not prove that every individual case was unskipped; no such claim or invented count is made here.

L53's literal control is the scratch executable followed by `--platform`, `ios`, `--device`, an actual empty argument, `test`, and `findings/fixtures/optional-miss.yaml`. Its stderr is exactly `Error: invalid argument: --device must not be empty` plus newline, SHA-256 `cb18b68e5f8d71eee838335f2daea4aa6999ace4285ea1378a7ef7689e248fcf`. Static inspection of frozen `pkg/cli/test.go:662–681` places this rejection at the start of `runTest`, before banner/update check and subsequent discovery/signing work. This supports the required early-rejection interpretation without claiming an independently observed device trace.

The scratch binary resides only at the window's `l53-runner-home/bin/grantiva-runner`. Its current 37,433,410 bytes independently hash to the manifest's `a9737f4eb32f8af32815512c93fdf12eb4d2e2741ff38cf900f007b680a80e38`. It is not the frozen installed candidate binary and cannot satisfy candidate provenance or the separate installed-runner/public control.

## Retention limits and scope

As declared in the archive record, caches and scratch executable are not copied into the repository archive. Their full hash inventory is retained; the original scratch executable was independently verified during this review. This review does not claim to have rehashed all Go cache contents. No gap was found in retained command metadata or raw streams.

No test, build, Go invocation, device operation, network request or source edit was performed. Only local evidence comparisons and a read of the frozen early-rejection source were used. No retry was requested, no matrix verdict was changed, and only this review document was added.

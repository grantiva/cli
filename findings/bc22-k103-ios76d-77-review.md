# B-C22.2 / B2-K103 and iOS attempts 76d/77 review

Scoped read-only review against the round-3 matrix, original K103/C22 requirements and candidate `8f2cff676b3c12e951478920fa20e600cdca4e29`.

## B2-K103: binding matrix conflicts with the accepted compatibility design

The literal row cannot pass: current JSON intentionally contains the 16 documented snake_case aliases beside equal camelCase keys. Its demanded test that “assert[s] no key contains `_`” directly contradicts exact-head `JSONKeyCasingContractTests`, which permits only entries from `LegacyJSONKeys.renamed` when their camelCase twin is present. This is deliberate one-release compatibility, not an unnoticed product regression.

The implemented contract is coherent and documented. README lines 493–516 state that every JSON document uses camelCase, explain the temporary aliases, list all 16 old/new pairs, and name their writers. `LegacyJSONKeys.renamed` is the same 16-pair source table. `testTheReadmeListsEveryLegacyAlias` ties the public list to that table; `testEveryJSONDocumentUsesCamelCaseKeys` covers representative command documents recursively and rejects every undocumented underscore key. Runner start/session app names are checked per platform, including Android `applicationId` plus its compatibility twins. Current N2-07 audits provide the runtime proof on each platform.

The README alias paragraph also satisfies the release-note purpose: it explicitly tells consumers which keys were renamed, which form to read, and that aliases will be removed later. CHANGELOG removal #179 therefore creates no separate documentation omission under binding matrix lines 924–925.

Task 6 should correct B2-K103 from “no key contains `_`” to “no undocumented snake_case key; each temporary documented alias must have its equal camelCase twin,” and replace the impossible test wording with the exact implemented semantic assertion. Preserve the requirement that every result has camelCase and that runner start/session name the app consistently. Until that correction, the literal row is a matrix failure/pending correction rather than an unqualified pass or product defect.

## B-C22.2: runtime/source clauses pass; public change note is missing

Current iOS and Android session JSON documents use ISO-8601 `acquiredAt` strings, and attempt 77's cleanup JSON independently emits an ISO-8601 `createdAt`. Exact-head `JSONOutput.encoder` and `compactString` both set `.iso8601`; `JSONOutputTests.testDatesEncodeAsISO8601` pins epoch zero to `1970-01-01T00:00:00Z`. These support the implementation and both-platform runtime portions.

The remaining clause explicitly requires a public change note. CHANGELOG was removed, so matrix lines 924–925 allow README, public docs, or release notes. Exact-head public searches find the camelCase migration note but no note that date-valued JSON fields changed to ISO-8601. L70 covers baseline filename migration only and cannot satisfy or relax C22. B-C22.2 therefore remains a documentation-contract failure tracked by L74; no runtime change is needed.

## iOS attempt 76d: D2-41 [ios] supported

Although there is no separate `completed.txt`, the evidence is terminal: `client.exit.txt` is 0, all four shell legs exit 0, `commands.txt` records `finished_utc`, and `all-files.sha256` freezes the set. A freshly relaunched Home hierarchy is accepted only after it contains Landmarks and no `focused:true`. Live `grantiva_vrt_capture` then returns MCP `isError:true` with exactly `Screen "Type Without Focus", step 1 (Type "hello"): No focused text field: tap a field before typing "hello".` The subsequent tools/list succeeds, proving the server remains responsive, and the exact owner session stops cleanly. Attempts 76/76b and proposal 76c remain excluded.

## iOS attempt 77: IOS-018 supported

The isolated runner home starts with exactly two newly created, row-owned devices. Both created/session ledgers contain exactly those UUIDs; one is explicitly shut down and the other remains active. `simulator cleanup --json` exits 0, returns only the shutdown UUID with ISO timestamp, deletes that simulator, removes only its created record, and retains the active device/session/created record. SHA-256 checks prove both global campaign ledgers are unchanged. Exact scratch-session teardown then deletes the active device, and the final and guarded EXIT inventories contain neither row UUID. The renamed attempt-local devices preserve the required lifecycle states without reusing the deleted campaign identity.

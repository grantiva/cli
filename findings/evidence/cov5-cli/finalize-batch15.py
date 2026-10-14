from pathlib import Path
import json
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov5-cli');ev=root/'findings/evidence/cov5-cli'
passes={
'B2-K59':'All three fresh empty-project MCP VRT failures are structured isError results with one shared `Error: ` prefix; capture names missing config and compare/approve share the no-captures text.',
'B2-K60':'A fresh MCP approve screen argument containing shell metacharacters stayed one JSON argument, failed normally, and the retained marker-absence command exited 0; approved source tests cover argv construction.',
'B2-K61':'Fresh captures of all required help pages name both platform drivers and app artifacts; current-tree docs/source inspection and accepted named tests cover corpus equality.',
'B2-K62':'Fresh docs/source inspection finds the error status filter and encoded status vocabulary; approved named tests cover exact encoding.',
'B2-K63':'Fresh docs inspection, runner version, and installed versions directory show the documented stamp form and actual stamped directory.',
'B2-K64':'Fresh docs inspection confirms lifecycle material is user-facing/current; any version hits under docs/superpowers are outside the shipped-doc criterion.',
'B2-K65':'Fresh installed cache listing contains iOS 26.0, 26.2, 26.4, and 27.0 WDA builds and docs inspection matches.',
'B2-K66':'Fresh README inspection documents copying the binary and adjacent resource bundle; current-candidate isolated install behavior is proven in B2-K45.',
'B2-K96':'Fresh read-only MCP booted/all listings use the five-column header, raw simctl states, and friendly iOS runtime names.',
'B2-K100.1':'Fresh resource reads return -32002 no-session errors for hierarchy/screenshot and typed -32600 for an unknown URI, never -32603; server initialization succeeds.',
'B2-K101':'Fresh stdio transport capture proves parse error id null, malformed-with-id echoes 7, no replies for id-less malformed/response messages, empty-batch typed error, and subsequent valid initialize succeeds.',
'B2-K107-b':'Fresh source/CI inspection locates the test-isolation guard and fresh-home handling; approved current-tree full-suite disposition supplies the runtime join without rerunning tests.',
'N2-02':'Fresh runner group/status usage failures and help prove the command set; version text/JSON report 1.1.28-grantiva.15 and installed-stamp behavior is recorded by B2-K45.',
'N2-10':'Current-candidate CLI-153 init warning, fresh MCP schemas, and fresh source inspection prove the shared newest-device default and bounded lookup.',
'N2-19':'Fresh device-free MCP calls cover missing sim/AVD, missing name, and no-session tools; every response is isError, has exactly one Error prefix, and preserves the required label partition.',
'N2-20':'Fresh source inspection locates tests that skip mdia-less and hdlr-less extra tracks while holding the real video track; approved named-test disposition joins execution.',
'D2-03':'Current-candidate CLI-153 init capture proves the optional/default simulator output and exact warning for a pre-existing non-Grantiva simulator without device action.',
'D2-15':'B2-K45 freshly proves first/second isolated installs; this row adds fresh current-home JSON with extracted false.',
'D2-16':'Fresh doctor JSON under invalid DEVELOPER_DIR records the current status vocabulary; B2-K62 docs/source join covers the filter contract.',
'D2-17':'Fresh README/source inspection binds the alias list to LegacyJSONKeys and platformTwins; accepted named tests cover pair behavior.',
'D2-27':'Fresh captures of all six required help pages retain accepted headless/environment/CI wording.',
'D2-32':'Fresh installed-cache listing contains prebuilt WDA directories for 26.0, 26.2, 26.4, and 27.0.',
'D2-33':'Fresh B2-K46 and B2-K47 captures on this candidate prove the exact no-session variants and format validation ordering.',
'D2-34':'Fresh N2-19/B2-K59/B2-K100 evidence plus accepted MCP transport source tests prove tool failures remain isError and protocol errors remain JSON-RPC errors, including cancellation.',
'D2-40':'Fresh B2-K96 read-only all/booted captures prove headers, states, runtimes, availability, and filtering; current-tree tests cover shutdown filtering.',
'D2-43':'Fresh B2-K100.1 resources evidence proves -32002 no-session and -32600 unknown URI, never -32603.',
'D2-46':'Fresh B2-K101 stdio evidence proves the core malformed-input shapes and recovery; accepted current-tree MCP transport tests cover batch-member cases.',
'D2-47':'Fresh B2-K61 and D2-27 help captures cover the semantic inventory; approved exact-tree docs/output smoke and source tests join canonical corpus equality.',
'D2-48':'Fresh B2-K50 evidence proves --version prints the CLI version and --release-version parses through to authentication.'}
pending={'N2-04':'Synthetic capture/baseline fixture has not yet been executed; pending its direct artifact behavior capture.','D2-01':'Missing-bundle fresh/current behavior awaits the fresh B3-L28 control so exact binary-copy evidence can be shared.','D2-23':'Synthetic comparison fixture remains to be captured.','D2-42':'MCP synthetic stray/new-screen fixture remains to be captured.'}
source={'B2-K60','B2-K61','B2-K62','B2-K64','B2-K66','B2-K107-b','N2-10','N2-20','D2-17','D2-34','D2-40','D2-46','D2-47'}
for row,text in {**passes,**pending}.items():
 d=ev/f'{row}-run-1';d.mkdir(exist_ok=True); result='pending' if row in pending else 'pass';(d/'verdict.md').write_text(f'# {row} verdict\n\nResult: **{result}**\n\n{text}\n')
 (d/'joined-evidence.json').write_text(json.dumps({'candidateManifestSHA256':'714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783','sourceDispositionSHA256':'9ba930ea42e8712a1c79ab5dca8e603ec64a9d38547e33d2cde3a95f6fafcfe3','sameSliceEvidence':True},indent=2)+'\n')
ledger=root/'findings/cov5-cli-results.md';s=ledger.read_text().replace('| 326 | 319 | 0 | 0 | 2 | 5 | 99 |','| 359 | 348 | 0 | 0 | 6 | 5 | 66 |')
ids=[x.split('\t')[1] for x in (ev/'direct-row-order.txt').read_text().splitlines()[326:359]]
s+='\n'+'\n'.join(f'| {r} | {"pending" if r in pending else "pass"} | `findings/evidence/cov5-cli/{r}-run-1/` |' for r in ids)+'\n';ledger.write_text(s)

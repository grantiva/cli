from pathlib import Path
import json
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov5-cli');ev=root/'findings/evidence/cov5-cli'
texts={
'B2-K35':'Fresh source inspection plus current-candidate CLI-025 both-platform text/JSON and CLI-081 required-iOS text/JSON evidence satisfy the advisory-versus-required partition, summaries, and exit behavior. See `../CLI-025-rerun-1/` and `../CLI-081-run-2/`.',
'B2-K37.1':'Fresh source inspection locates the shared default implementation/tests. Current-candidate `../CLI-153-run-1/init.stdout` proves init warned that the stock-name simulator was not Grantiva-created and named the Grantiva-specific override.',
'B2-K38':'Current-candidate `../CLI-153-run-1/init.stdout` proves exact two-scheme warning with both names and override advice; fresh source inspection locates the shared detection and named regressions joined by the approved source disposition.',
'B2-K39':'Fresh runs prove both setup and usage failures write failed ready files with exact errors and no reportDir when no report directory exists; retained directory listing confirms none was created. Approved current-tree tests cover the post-directory setup path.',
'B2-K40':'Fresh parser captures exit 64 and enumerate all allowed snapshot, hierarchy format, and platform values before any target work.',
'B2-K41':'Fresh captures prove spaced/equal negative run timeouts and timeout 5 all emit the range error; the ready file records it. Hierarchy and record emit their own range errors. All exit 64.',
'B2-K42':'Fresh captures cover empty/malformed UDID, empty session, mutually exclusive selectors, hierarchy, and dump-hierarchy. All exit 64 with direct validation text and no `Invalid argument:` prefix.',
'B2-K43':'All six exact platform-mismatch repro commands freshly exited 1 before target work with the shared long-form platform-resolution text; source inspection locates the single helper and regressions.',
'B2-K45':'Two fresh installs into one isolated current-candidate home prove the first says Extracting/installed and the second says already installed with no Extracting line.',
'B2-K46':'Fresh no-session dump, hierarchy, and MCP screenshot captures share the backtick-quoted start/run remedies, omit `Invalid argument:`, and MCP returns structured isError while remaining responsive.',
'B2-K47':'Fresh bogus format exits 64 and lists tree/json/xml before session lookup; mixed-case XML parses and reaches only the no-session check. The explicit conflicting json/tree pair is rejected as usage.',
'B2-K49':'Fresh CLI and MCP unknown-screen calls return the single clear sentence; before/after hashes prove Home.png unchanged and the file listing proves no baseline was written.',
'B2-K50':'Fresh update help contains inherited `--version` exactly once and renamed `--release-version`; `--version` prints 2.1.0 exit 0, while a release-version invocation parses then reaches authentication.',
'B2-K51':'Fresh iOS/Android compare and approve failures leave no `.grantiva` directory, proven by the retained find output.',
'B2-K52':'Fresh run, no-build run, and capture calls in an Xcode-shaped no-config directory return the identical missing-config sentence before scheme/device work. Empty `.maestro` variants share the exact no-flow diagnostic.',
'B2-K58':'Fresh MCP context captures prove an Android-only directory forced to iOS does not borrow the Android flow app ID, while an iOS `.maestro`-only directory works and identifies `source: .maestro/ (no grantiva.yml)`. Inventory text was read-only and no target action occurred.'}
source_rows={'B2-K35','B2-K37.1','B2-K38','B2-K39','B2-K43','B2-K58'}
for row,text in texts.items():
 d=ev/f'{row}-run-1'; (d/'verdict.md').write_text(f'# {row} verdict\n\nResult: **pass**\n\n{text}\n')
 if row in source_rows:
  (d/'source-join.json').write_text(json.dumps({'candidateManifestSHA256':'714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783','sourceDispositionSHA256':'9ba930ea42e8712a1c79ab5dca8e603ec64a9d38547e33d2cde3a95f6fafcfe3'},indent=2)+'\n')
d=ev/'B2-K48-run-1';d.mkdir(exist_ok=True)
(d/'verdict.md').write_text('# B2-K48 verdict\n\nResult: **pending**\n\nThe fresh-home mismatch behavior and permitted residue are accepted by the current-candidate B-C01.1 controller disposition, but the existing-current-install-unchanged clause awaits the fresh B3-L28 capture at direct ordinal 369. No historical runtime pass is transferred.\n')
(d/'disposition-link.json').write_text(json.dumps({'path':'/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/evidence/completion-coverage/B-C01.1-disposition.json'},indent=2)+'\n')
ledger=root/'findings/cov5-cli-results.md';s=ledger.read_text().replace('| 309 | 303 | 0 | 0 | 1 | 5 | 116 |','| 326 | 319 | 0 | 0 | 2 | 5 | 99 |')
order=['B2-K35','B2-K37.1','B2-K38','B2-K39','B2-K40','B2-K41','B2-K42','B2-K43','B2-K45','B2-K46','B2-K47','B2-K48','B2-K49','B2-K50','B2-K51','B2-K52','B2-K58']
s+='\n'+'\n'.join(f'| {r} | {"pending" if r=="B2-K48" else "pass"} | `findings/evidence/cov5-cli/{r}-run-1/` |' for r in order)+'\n';ledger.write_text(s)

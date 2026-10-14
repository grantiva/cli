from pathlib import Path
import json
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov5-cli');ev=root/'findings/evidence/cov5-cli'
rows={
'B3-L09':'Fresh Android init in a settings.gradle-shaped scratch wrote emulator Pixel_8_API_35 and emitted the exact unowned-existing-AVD warning and Grantiva-specific remedy, without device action.',
'B3-L14.1':'Fresh source inspection locates all immediate/delayed/unknown cancellation transport regressions; approved exact-tree 2,027-test disposition supplies execution without rerunning the suite.',
'B3-L15.1':'Fresh MCP calls prove exact missing-name, unknown-tool, and no-session error shapes as structured isError results; accepted current-tree tool-contract tests cover every-tools/list enumeration.',
'B3-L16':'Fresh CLI three/mixed/single missing-screen calls and MCP call name every missing screen; the retained baseline listing is empty, proving no partial approval.',
'B3-L17':'Fresh forced-platform and auto-detected context calls name the searched realpath/config candidates, give the init remedy, and mark booted inventory as a hint only.',
'B3-L25':'Fresh exact source excerpt contains both malformed-extra-track orders and no-hdlr cases; approved named-test disposition joins execution.',
'B3-L26-a':'Fresh iOS/Android extension and zero-duration calls all exit64 with plain Error, Usage, and See-help shape before target work.',
'B3-L26-b':'Fresh record/run/capture/install/start calls all reject device+emulator with the exact usage error, exit64, before config/target resolution.',
'B3-L27':'Fresh isolated relative and absolute runner-home install/version calls print only canonical absolute realpaths; default home remains untouched and source tests cover it.',
'B3-L28':'Fresh current install seeded by candidate4 remains untouched under a binary-alone install: text/JSON exit0 and emit the exact one-line warning. A fresh binary-alone home exits1 naming the missing bundle.',
'B3-L29':'Fresh required help pages and docs/source inspection prove build-build omits public boot flags while the six device pages retain them; accepted tests cover hidden compatibility without invoking a compiler.',
'B3-L30':'Fresh shipped-doc/version scan and DocsContractTests inspection prove no internal docs/plans surface and preserve documented versions.',
'B3-L31':'Fresh CI/script/test inspection locates the fresh-home guard; controller-recorded PR216 CI 38482057908 pass and approved exact-tree suite provide the current-candidate CI join.',
'B3-L42-b':'Fresh malformed iOS/Android run and capture calls report file, line, config path, and accepted tap shape with one Error prefix and no decoder internals, before target resolution.',
'B3-L53':'Fresh packaged runner calls reject empty device and udid alias at usage exit64 before signing/device lookup; serial is an unknown flag. CLI runner-start rejects unsupported empty udid/serial flags at usage parsing. This is the accepted improved behavior.',
'N3-08':'Fresh five reference usage errors all exit64 with the shared Error/Usage/See-help shape and no Invalid argument prefix.',
'N3-11':'Fresh binary-alone commands over a current isolated install record exactly one warning on runner install, while version/hierarchy/start retain their own non-bundle behavior and no command fails because the install is unavailable.',
'N3-15':'Fresh doctor text/JSON both identify the booted simulator and append the unowned default-name note; exit remains0.',
'N3-16':'Fresh docs/source inspection plus accepted candidate4 docs/output smoke prove round-three public additions and canonical help corpus; no lineage claim is introduced.'}
for row,text in rows.items():
 d=ev/f'{row}-run-1';d.mkdir(exist_ok=True); (d/'verdict.md').write_text(f'# {row} verdict\n\nResult: **pass**\n\n{text}\n')
 (d/'joined-evidence.json').write_text(json.dumps({'candidateManifestSHA256':'714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783','sourceDispositionSHA256':'9ba930ea42e8712a1c79ab5dca8e603ec64a9d38547e33d2cde3a95f6fafcfe3'},indent=2)+'\n')
# exact fresh L28 sibling resolutions; preserve earlier pending/strict files
for row,run,text in [
 ('B-C01.1','run-4','Fresh B3-L28 current-candidate raw (`../B3-L28-run-1/`) proves a seeded existing install is unchanged and succeeds when the adjacent bundle is absent; fresh-home residue/error remains accepted by the controller disposition. Explicit runner-home overrides mean the default home was not addressed.'),
 ('B2-K48','run-2','Fresh B3-L28 current-candidate raw (`../B3-L28-run-1/`) proves the existing install remains usable and untouched with a mismatched/missing adjacent bundle. The controller disposition supplies exact fresh-home residue proof.'),
 ('D2-01','run-2','Fresh binary-alone failure is retained in `../B3-L28-run-1/copy-fresh.*`; this directory contains a fresh adjacent binary+bundle install that exits0. Both use isolated homes.')]:
 d=ev/f'{row}-{run}';d.mkdir(exist_ok=True);(d/'verdict.md').write_text(f'# {row} corrected verdict\n\nResult: **pass**\n\n{text}\n')
ledger=root/'findings/cov5-cli-results.md';s=ledger.read_text().replace('| 359 | 348 | 0 | 0 | 6 | 5 | 66 |','| 378 | 370 | 0 | 0 | 3 | 5 | 47 |')
s=s.replace('| B-C01.1 | pending | `findings/evidence/cov5-cli/B-C01.1-run-3/` |','| B-C01.1 | pass | `findings/evidence/cov5-cli/B-C01.1-run-4/` |').replace('| B2-K48 | pending | `findings/evidence/cov5-cli/B2-K48-run-1/` |','| B2-K48 | pass | `findings/evidence/cov5-cli/B2-K48-run-2/` |').replace('| D2-01 | pending | `findings/evidence/cov5-cli/D2-01-run-1/` |','| D2-01 | pass | `findings/evidence/cov5-cli/D2-01-run-2/` |')
ids=[x.split('\t')[1] for x in (ev/'direct-row-order.txt').read_text().splitlines()[359:378]]
s+='\n'+'\n'.join(f'| {r} | pass | `findings/evidence/cov5-cli/{r}-run-1/` |' for r in ids)+'\n';ledger.write_text(s)

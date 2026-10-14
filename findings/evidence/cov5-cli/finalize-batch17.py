from pathlib import Path
import json
root=Path('/Users/kyle/Developer/grantiva-cli/.worktrees/cov5-cli');ev=root/'findings/evidence/cov5-cli'
pending={'B4-L75.1':'Exact public nested-cycle output requires a named live target; fresh absent-UUID control reached missing-device resolution before the runner-side cycle check. Source regression is accepted but does not replace this public-output clause.',
'B4-L75.2':'Root/screens public cycle output requires a named live target; fresh absent-UUID control reached missing-device resolution first. Source regression is accepted.',
'B4-L75.3':'Absolute-path public cycle preservation requires a named live target; source regression is accepted.',
'B4-L75.5':'The /tmp and /private/tmp source rewrite regression is accepted, but exact public nested-cycle output awaits a named live target.',
'B4-L85.5':'Pending root-owned final full-campaign gate by explicit assignment; source/full-suite and smoke components are retained but this sole final join is not graded here.'}
def detail(row):
 if row.startswith('B4-L53.'):
  return 'Fresh candidate/runner source inspection plus B3-L53 packaged-runner public captures prove empty device/udid rejection before lookup, preserved udid alias, serial unknown-flag control, and CLI target parsing. Approved exact-tree Swift and runner test dispositions supply the named regression joins.'
 if row.startswith('B4-L67.'):
  return 'Fresh doctor source inspection and current-candidate CLI-025 text/JSON/run evidence prove ambiguous Platform is Advisory, guidance/toolchain treatment and exit0 remain, run still rejects ambiguity, and named tests are covered by the approved source disposition.'
 if row.startswith('B4-L70.'):
  return 'Fresh README/implementation/test inspection records literal filenames, legacy percent-encoded compatibility, automatic approval migration, and no manual-rename implication; approved source tests preserve the implementation evidence.'
 if row.startswith('B4-L74.'):
  return 'Fresh docs/source/test inspection records ISO-8601 UTC as the public JSON date representation and preserves the `.iso8601` encoder semantic test; the accepted exact-tree suite supplies execution.'
 if row=='B4-L75.4': return 'Fresh source inspection locates the focused final merged output-map regression for nested ../ operands; accepted exact-tree test execution supplies the source clause.'
 if row.startswith('B4-L81.'):
  return 'Fresh DoctorRunner/DoctorTests inspection plus current-candidate N3-15 text/JSON prove the booted non-default result includes the unowned default-name note with Advisory/ok/exit0 behavior; accepted exact-tree tests cover ordering, owned/no-default/no-boot/failure siblings.'
 if row.startswith('B4-L82.'):
  return 'Fresh production source/test inspection is joined to the controller-approved candidate4 L82 source provenance, focused/full fresh-home tests, review, CI, merge, rebuilt identity, and smoke gate; no live substitute is claimed.'
 if row.startswith('B4-L83.'):
  return 'Fresh unchanged runner source/test inspection is joined to approved exact runner focused/full/vet evidence and candidate4 provenance, covering tracked owned-port cleanup for UIAutomator2/DeviceLab and required release gates.'
 if row.startswith('B4-L84.'):
  return 'Fresh CLI source/test inspection is joined to controller-approved candidate4 L84 source/live review, focused/full fresh-home suite, CI/merge/rebuild and smoke provenance, covering ownership-safe orphan cleanup and preserved public siblings.'
 if row.startswith('B4-L85.'):
  return 'Fresh selector source/test inspection is joined to the approved current exact-tree full 2,027-test mapping, covering back-button preference within label stage and the required transport/fallback/error/retry siblings.'
 if row.startswith('B4-PC.'):
  return 'Fresh unchanged runner source/test inspection locates the exact deadline/cancellation/stabilization/action-budget production regressions; approved runner focused/full/vet evidence and exact runner provenance supply execution.'
 raise KeyError(row)
ids=[x.split('\t')[1] for x in (ev/'direct-row-order.txt').read_text().splitlines()[378:425]]
for row in ids:
 d=ev/f'{row}-run-1';d.mkdir(exist_ok=True);ispend=row in pending;text=pending[row] if ispend else detail(row)
 (d/'verdict.md').write_text(f'# {row} verdict\n\nResult: **{"pending" if ispend else "pass"}**\n\n{text}\n')
 (d/'provenance-join.json').write_text(json.dumps({'candidateManifestSHA256':'714715a6890ae340395083e195eecfa3d95e28abdc102e69e7c66533dea5c783','sourceDisposition':'/Users/kyle/Developer/grantiva-cli/.worktrees/regression/findings/evidence/completion-coverage/source-evidence-disposition.json','sourceDispositionSHA256':'9ba930ea42e8712a1c79ab5dca8e603ec64a9d38547e33d2cde3a95f6fafcfe3'},indent=2)+'\n')
ledger=root/'findings/cov5-cli-results.md';s=ledger.read_text().replace('| 378 | 370 | 0 | 0 | 3 | 5 | 47 |','| 425 | 412 | 0 | 0 | 8 | 5 | 0 |')
s+='\n'+'\n'.join(f'| {r} | {"pending" if r in pending else "pass"} | `findings/evidence/cov5-cli/{r}-run-1/` |' for r in ids)+'\n';ledger.write_text(s)

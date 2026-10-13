#!/bin/zsh
set -u
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt31-cleanup"
SRC="$WT/findings/evidence/cov3-ios-attempt31/owned-new-devices.tsv"
if [[ -e "$ROOT" ]]; then print -u2 'refusing overwrite attempt31 cleanup'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"; cp "$SRC" "$ROOT/owned-new-devices.tsv"
xcrun simctl list devices --json > "$ROOT/before.json"
python3 - "$ROOT/before.json" "$SRC" <<'PY'
import json,sys
j=json.load(open(sys.argv[1])); amap={d['udid']:d.get('name') for xs in j['devices'].values() for d in xs}
for line in open(sys.argv[2]):
 _,u,n=line.rstrip('\n').split('\t')
 if amap.get(u)!=n: raise SystemExit('refusing name/UDID mismatch '+repr((u,amap.get(u),n)))
PY
if [[ $? -ne 0 ]]; then exit 74; fi
while IFS=$'\t' read -r label udid name; do
 xcrun simctl delete "$udid" > "$ROOT/delete-$label.out" 2> "$ROOT/delete-$label.err"; echo $? > "$ROOT/delete-$label.exit.txt"
done < "$SRC"
xcrun simctl list devices --json > "$ROOT/after.json"
python3 - "$ROOT/after.json" "$SRC" <<'PY'
import json,sys
j=json.load(open(sys.argv[1])); ids={d['udid'] for xs in j['devices'].values() for d in xs}; left=[]
for line in open(sys.argv[2]):
 _,u,_=line.rstrip('\n').split('\t')
 if u in ids:left.append(u)
if left: raise SystemExit('owned lifecycle devices still exist: '+repr(left))
PY
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"

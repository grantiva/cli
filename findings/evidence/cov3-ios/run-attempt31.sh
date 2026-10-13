#!/bin/zsh
set -u
export GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
export GRANTIVA_RUNNER_HOME=/Users/kyle/.grantiva-qa/runner
export GRANTIVA_SESSION_ID=cov3-ios-lifecycle31
unset GRANTIVA_API_KEY
WT=/Users/kyle/Developer/grantiva-cli/.worktrees/cov3-ios
ROOT="$WT/findings/evidence/cov3-ios-attempt31"
if [[ -e "$ROOT" ]]; then print -u2 'refusing overwrite attempt31'; exit 73; fi
mkdir -p "$ROOT"; cp "$0" "$ROOT/harness.sh"
GRANTIVA=/Users/kyle/.grantiva-qa/bin/grantiva
N5='cov3-ios-31a iPhone 17'; N6='cov3-ios-31b iPhone 17'; N7='cov3-ios-31c-no-model'; N8='cov3-ios-31d iPhone 17'
runone() { local name=$1; shift; print -r -- "$*" > "$ROOT/$name.command.txt"; "$@" > "$ROOT/$name.out" 2> "$ROOT/$name.err"; print -r -- "$?" > "$ROOT/$name.exit.txt"; }
{
 echo "started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"; shasum -a 256 "$GRANTIVA"; echo "session_id=$GRANTIVA_SESSION_ID"
 printf 'names=%s | %s | %s | %s\n' "$N5" "$N6" "$N7" "$N8"
} > "$ROOT/commands.txt"
xcrun simctl list devices > "$ROOT/simctl-before.txt"
xcrun simctl list devices --json > "$ROOT/simctl-before.json"
python3 - "$ROOT/simctl-before.json" "$N5" "$N6" "$N7" "$N8" <<'PY'
import json,sys
j=json.load(open(sys.argv[1])); names={d.get('name') for xs in j['devices'].values() for d in xs}
found=[n for n in sys.argv[2:] if n in names]
if found: raise SystemExit('refusing pre-existing lifecycle names: '+repr(found))
PY
if [[ $? -ne 0 ]]; then exit 74; fi
runone ios005 "$GRANTIVA" simulator ensure --name "$N5" --device-type 'iPhone 17' --runtime 'iOS 26.0' --no-boot
U5=$(tr -d '[:space:]' < "$ROOT/ios005.out")
xcrun simctl list devices > "$ROOT/ios005-simctl.txt"
runone ios006-new "$GRANTIVA" simulator ensure --json --name "$N6" --device-type 'iPhone 17' --runtime 'iOS 26.0' --no-boot
U6=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["udid"])' "$ROOT/ios006-new.out")
runone ios006-reuse "$GRANTIVA" simulator ensure --json --name "$N6" --no-boot
runone ios007 "$GRANTIVA" simulator ensure --name "$N7" --no-boot
(
 "$GRANTIVA" simulator ensure --json --name "$N8" --device-type 'iPhone 17' --runtime 'iOS 26.0' --no-boot > "$ROOT/ios008-a.out" 2> "$ROOT/ios008-a.err"; echo $? > "$ROOT/ios008-a.exit.txt"
) & P1=$!
(
 "$GRANTIVA" simulator ensure --json --name "$N8" --device-type 'iPhone 17' --runtime 'iOS 26.0' --no-boot > "$ROOT/ios008-b.out" 2> "$ROOT/ios008-b.err"; echo $? > "$ROOT/ios008-b.exit.txt"
) & P2=$!
wait $P1; wait $P2
xcrun simctl list devices > "$ROOT/simctl-after-ensure.txt"
xcrun simctl list devices --json > "$ROOT/simctl-after-ensure.json"
python3 - "$ROOT" "$N5" "$N6" "$N8" <<'PY'
import json,re,sys
root,n5,n6,n8=sys.argv[1:]
before=json.load(open(root+'/simctl-before.json')); after=json.load(open(root+'/simctl-after-ensure.json'))
bids={d['udid'] for xs in before['devices'].values() for d in xs}; amap={d['udid']:d.get('name') for xs in after['devices'].values() for d in xs}
vals=[]
plain=open(root+'/ios005.out').read().strip(); vals.append(('ios005',plain,n5))
vals.append(('ios006',json.load(open(root+'/ios006-new.out'))['udid'],n6))
for tag in ['a','b']:
 try: vals.append(('ios008-'+tag,json.load(open(root+'/ios008-'+tag+'.out'))['udid'],n8))
 except Exception: pass
uniq=[]
for label,u,name in vals:
 if not re.fullmatch(r'[0-9A-Fa-f-]{36}',u): raise SystemExit('invalid owned UUID '+repr((label,u)))
 if u in bids: raise SystemExit('refusing pre-existing UDID '+u)
 if amap.get(u)!=name: raise SystemExit('new-device name mismatch '+repr((u,amap.get(u),name)))
 if u not in [x[1] for x in uniq]: uniq.append((label,u,name))
if not any(x[0].startswith('ios008') for x in uniq): raise SystemExit('no concurrent owned UDID recovered')
with open(root+'/owned-new-devices.tsv','w') as f:
 for x in uniq: f.write('\t'.join(x)+'\n')
PY
if [[ $? -ne 0 ]]; then print -u2 'ownership validation failed; preserving devices and refusing any guessed teardown'; exit 75; fi
while IFS=$'\t' read -r label udid devname; do
 runone "teardown-$label" "$GRANTIVA" simulator teardown --udid "$udid" --force --json
done < "$ROOT/owned-new-devices.tsv"
xcrun simctl list devices > "$ROOT/simctl-after-teardown.txt"
{
 echo "ios005_udid=$U5"; echo "ios006_udid=$U6"; cat "$ROOT/owned-new-devices.tsv"; echo "finished_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} >> "$ROOT/commands.txt"
find "$ROOT" -type f ! -name all-files.sha256 -print0 | sort -z | xargs -0 shasum -a 256 > "$ROOT/all-files.sha256"

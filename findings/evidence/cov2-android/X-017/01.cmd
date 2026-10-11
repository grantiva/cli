$GRANTIVA doctor --platform android --json > $E/X-017/android.json; echo rc=$?; $GRANTIVA doctor --platform ios --json > $E/X-017/ios.json; echo rc=$?; python3 -I -c "
import json
for p in [\"android\",\"ios\"]:
  d=json.load(open(\"$E/X-017/\"+p+\".json\"))
  print(p, type(d).__name__, sorted(d.keys()) if isinstance(d,dict) else \"\")
  checks=d[\"checks\"] if isinstance(d,dict) else d
  print(\" keysets\", sorted({tuple(sorted(c.keys())) for c in checks}), \"statuses\", sorted({c[\"status\"] for c in checks}))
"

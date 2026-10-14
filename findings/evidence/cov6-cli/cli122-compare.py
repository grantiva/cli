import json,re,sys
from pathlib import Path
doc=Path(sys.argv[1]).read_text()
rows=re.findall(r"^\| `(grantiva_[^`]+)` \| ([^|]+) \|",doc,re.M)
actual=json.loads(Path(sys.argv[2]).read_text())[1]["result"]["tools"]
names={x["name"] for x in actual}; expected={n for n,_ in rows}
print(json.dumps({"documented_count":len(expected),"live_count":len(names),"missing":sorted(expected-names),"extra":sorted(names-expected),"ios_only_test":dict(rows).get("grantiva_test"),"android_only_emulators":{n:p.strip() for n,p in rows if n.startswith("grantiva_emulator_")}},indent=2))
assert expected==names and len(names)==22
assert dict(rows)["grantiva_test"].strip()=="iOS only"
assert all(p.strip()=="Android only" for n,p in rows if n.startswith("grantiva_emulator_"))

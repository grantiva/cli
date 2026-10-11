$GRANTIVA doctor --platform android --json | python3 -c "import json,sys;d=json.load(sys.stdin);print(sorted(set(k for c in d for k in c)));print(sorted(set(c[\"status\"] for c in d)))"

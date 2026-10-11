$GRANTIVA diff capture --no-build --json > /Users/kyle/Developer/grantiva-cli/.worktrees/cov2-android/findings/evidence/cov2-android/B2-K17/session-capture.json; echo exit=$?; python3 -I -c "
import json;d=json.load(open(\"/Users/kyle/Developer/grantiva-cli/.worktrees/cov2-android/findings/evidence/cov2-android/B2-K17/session-capture.json\"))
for s in d[\"screens\"]: print(s[\"screenName\"],[(x[\"action\"],x[\"status\"],x.get(\"duration\")) for x in s[\"steps\"]])"

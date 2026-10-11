ls -la ~/.grantiva/android/; cat ~/.grantiva/android/created-avds.json; echo; cat ~/.grantiva/android/started.json 2>/dev/null; find ~/.grantiva -maxdepth 2 -name "*.json" -newer $S/env.sh

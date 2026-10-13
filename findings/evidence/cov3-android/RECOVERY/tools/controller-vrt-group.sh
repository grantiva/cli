#!/bin/bash
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd "$P"
cp grantiva-android.yml "$S/grantiva-android.stock.current.yml"
rec AND-108 "rm -rf .grantiva/captures/android; $GRANTIVA diff capture --device emulator-5554 --no-build --json; echo exit=\$?; find .grantiva/captures/android -maxdepth 1 -type f -print | sort"
rec B2-K89 "rm -rf .grantiva/baselines/android; $GRANTIVA diff approve --json; echo approve-exit=\$?; $GRANTIVA diff compare --json; echo compare-exit=\$?"
rec B2-K89 "$GRANTIVA diff approve --screen Home; echo approve-home-exit=\$?; $GRANTIVA diff compare; echo compare-exit=\$?; $GRANTIVA diff compare --json; echo compare-json-exit=\$?"
for i in 1 2 3 4 5 6 7 8 9 10; do rec B-A04.1 "$GRANTIVA diff capture --device emulator-5554 --no-build --json; echo run=$i exit=\$?; md5 -q .grantiva/captures/android/Home.png; md5 -q '.grantiva/captures/android/Deep Links.png'; stat -f 'home-bytes=%z' .grantiva/captures/android/Home.png"; done
cp .maestro/coverage/cfg/screens-steps.grantiva-android.yml grantiva-android.yml
rec AND-128 "rm -rf .grantiva/captures/android; $GRANTIVA diff capture --device emulator-5554 --no-build --verbose --json; echo exit=\$?; find .grantiva/captures/android -maxdepth 1 -type f -print | sort"
mkdir -p "$E/AND-128/captures"
cp -R .grantiva/captures/android/. "$E/AND-128/captures/"
cp "$S/grantiva-android.stock.current.yml" grantiva-android.yml

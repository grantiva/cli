#!/bin/bash
set -u
source /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov3-android/env.sh
cd "$P"
stamp=round3-diff-baseline-current
bk="$S/$stamp"; mkdir -p "$bk"
if [ -d .grantiva/baselines/android ]; then cp -R .grantiva/baselines/android "$bk/baselines.android.before"; fi
if [ -d .grantiva/captures/android ]; then cp -R .grantiva/captures/android "$bk/captures.android.before"; fi
restore() {
  rm -rf .grantiva/baselines/android .grantiva/captures/android
  if [ -d "$bk/baselines.android.before" ]; then mkdir -p .grantiva/baselines; cp -R "$bk/baselines.android.before" .grantiva/baselines/android; fi
  if [ -d "$bk/captures.android.before" ]; then mkdir -p .grantiva/captures; cp -R "$bk/captures.android.before" .grantiva/captures/android; fi
}
trap restore EXIT
rm -rf .grantiva/baselines/android .grantiva/captures/android
rec AND-085-exact "$GRANTIVA diff capture --device emulator-5554 --no-build --json; echo exit=\$?; find .grantiva/captures/android -maxdepth 1 -type f -print | sort"
mkdir -p "$E/AND-085-exact/captures"; cp -R .grantiva/captures/android/. "$E/AND-085-exact/captures/"
rec B2-K89-exact "$GRANTIVA diff compare; echo text-exit=\$?; $GRANTIVA diff compare --json; echo json-exit=\$?"
rec B2-K89-exact "$GRANTIVA diff approve --screen Home --json; echo approve-home-exit=\$?; $GRANTIVA diff compare; echo mixed-text-exit=\$?; $GRANTIVA diff compare --json; echo mixed-json-exit=\$?"
rec AND-086-exact "$GRANTIVA diff approve --json; echo exit=\$?; find .grantiva/baselines/android -maxdepth 1 -type f -print | sort"
rec AND-087-unchanged "$GRANTIVA diff compare; echo text-exit=\$?; $GRANTIVA diff compare --json; echo json-exit=\$?"

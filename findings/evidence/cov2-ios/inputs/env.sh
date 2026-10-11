export GRANTIVA="$HOME/.grantiva-qa/bin/grantiva"; export GRANTIVA_RUNNER_HOME="$HOME/.grantiva-qa/runner"; export GRANTIVA_SESSION_ID=cov2-ios; unset GRANTIVA_API_KEY
export S=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov2-ios
export APP=$S/ios
export W=/Users/kyle/Developer/grantiva-cli/.worktrees/cov2-ios
export E=$W/findings/evidence/cov2-ios
export RES=$W/findings/cov2-ios-results.md
[ -f $S/udids.sh ] && . $S/udids.sh
. $S/rr.sh

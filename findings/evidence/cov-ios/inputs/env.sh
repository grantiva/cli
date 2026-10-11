export GRANTIVA=$HOME/.grantiva-qa/bin/grantiva GRANTIVA_RUNNER_HOME=$HOME/.grantiva-qa/runner GRANTIVA_SESSION_ID=cov-ios
unset GRANTIVA_API_KEY
export S=/private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov-ios
export APP=$S/ios
export W=/Users/kyle/Developer/grantiva-cli/.worktrees/cov-ios
export E=$W/findings/evidence/cov-ios
[ -f $S/udids.sh ] && . $S/udids.sh
. /private/tmp/claude-501/-Users-kyle-Developer-grantiva-cli/b9f2e919-f7a5-4b94-a1bc-202f523560f4/scratchpad/cov-ios/rr.sh

$GRANTIVA build build --variant paidDebug --verbose 2>&1 | grep -E "assemble|Build succeeded|APK"; echo rc=$?

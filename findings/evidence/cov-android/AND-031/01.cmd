cp grantiva-android.yml $S/p-orig.yml; python3 -c "
p=\"grantiva-android.yml\"; s=open(p).read(); open(p,\"w\").write(s[:s.index(\"screens:\")]+\"flows: []
\")"; cat grantiva-android.yml; rm -rf $S/out031 $S/out031.ready; adb devices; $GRANTIVA run --report-dir $S/out031 --ready-file $S/out031.ready; echo rc=$?; ls $S/out031 2>&1; cat $S/out031.ready; cp $S/p-orig.yml grantiva-android.yml

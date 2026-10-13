# runflows.sh <TAG> <UDID> <flow paths...> : run each flow with a report dir; keep report.json + captures list
TAG=$1; U=$2; shift 2
for f in "$@"; do b=$(basename $f .yaml); rd=$S/reports/$TAG/$b; rm -rf $rd; rm -rf .grantiva/run-captures
  rr $TAG $b "\$GRANTIVA run --no-build --simulator $U --flow $f --report-dir $rd"
  mkdir -p $E/$TAG/$b-report; cp $rd/report.json $rd/*.log $E/$TAG/$b-report/ 2>/dev/null; ls -R $rd > $E/$TAG/$b-report/files.txt 2>&1
done

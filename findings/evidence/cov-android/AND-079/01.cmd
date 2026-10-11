$GRANTIVA record --json --duration 3 --frames-at 0,1000 --output "$S/cov rec/a.mp4"; echo rc=$?; ls -la "$S/cov rec" "$S/cov rec/"*frames* 2>/dev/null

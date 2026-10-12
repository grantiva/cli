#!/bin/bash
set +e
source "$(dirname "$0")/lib3.sh"
d=$(fd D2-42-rerun2); mkdir -p "$d/.grantiva/captures" "$d/.grantiva/baselines"
cat > "$d/grantiva.yml" <<'YAML'
bundle_id: com.example.app
simulator: cov-missing
screens:
  - name: A
    path: launch
  - name: B
    path: launch
diff:
  threshold: 0.02
  perceptual_threshold: 5
YAML
python3 "$T/mkpng2.py" "$d/.grantiva/captures/A.png" 10 10 0
python3 "$T/mkpng2.py" "$d/.grantiva/captures/B.png" 10 10 0
python3 "$T/mkpng2.py" "$d/.grantiva/captures/failure-123.png" 10 10 0
call 41 grantiva_vrt_compare '{}' | mcpq D2-42-rerun2 compare "$d" ios
call 42 grantiva_vrt_approve '{}' | mcpq D2-42-rerun2 approve "$d" ios
mv "$d/.grantiva/captures/A.png" "$d/.grantiva/captures/A.saved"
rm "$d/.grantiva/captures/B.png"
call 43 grantiva_vrt_compare '{}' | mcpq D2-42-rerun2 only_stray "$d" ios

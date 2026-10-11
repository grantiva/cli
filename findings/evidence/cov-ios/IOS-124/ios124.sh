UDID=$U1
install_result="$($GRANTIVA build install \
  --scheme "Landmarks (UI Testing)" \
  --simulator "$UDID" \
  --bundle-id com.kylebrowning.Landmarks \
  --derived-data-path "/private/tmp/grantiva-$UDID/Derived Data" \
  --no-launch \
  --json)"
echo "install exit=$?"
data_container="$(jq -r '.dataContainerPath' <<<"$install_result")"
echo "data_container=$data_container"; ls -d "$data_container"
$GRANTIVA run \
  --no-build \
  --flow .maestro/01-browse.yaml \
  --simulator "$UDID" \
  --bundle-id com.kylebrowning.Landmarks
echo "run exit=$?"

echo no | avdmanager create avd -n cov2-android-2 -k "system-images;android-35;google_apis;arm64-v8a" -d pixel_8 >/dev/null 2>&1; avdmanager list avd -c

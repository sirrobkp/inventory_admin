#!/usr/bin/env bash
# Android + iOS project preparation (Kibo Admin). Safe to re-run.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -d android ] || [ ! -d ios ]; then
  flutter create --org tz.co.kibo --project-name kibo_admin --no-pub --platforms android,ios .
fi
rm -f test/widget_test.dart
# Release builds need the INTERNET permission (the template only has it for debug builds)
M=android/app/src/main/AndroidManifest.xml
if ! grep -q 'android.permission.INTERNET' "$M"; then
  python3 - "$M" <<'PY'
import sys
p = sys.argv[1]
s = open(p).read()
s = s.replace('<application', '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
open(p, 'w').write(s)
PY
fi
echo "Admin Android/iOS preparation done."

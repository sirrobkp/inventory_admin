#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -d macos ]; then
  flutter create --org tz.co.kibo --project-name kibo_admin --no-pub --platforms macos .
fi
rm -f test/widget_test.dart
# The macOS sandbox blocks network access unless this entitlement is set
python3 - <<'PY'
import plistlib
for f in ['macos/Runner/DebugProfile.entitlements', 'macos/Runner/Release.entitlements']:
    d = plistlib.load(open(f, 'rb'))
    d['com.apple.security.network.client'] = True
    plistlib.dump(d, open(f, 'wb'))
print('entitlements patched')
PY

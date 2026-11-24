#!/usr/bin/env bash
# Pod resource bundles must not ask for a Development Team; the app keeps Flutter's default ad-hoc signing.
set -euo pipefail
cd "$(dirname "$0")/.."
if [ ! -f macos/Podfile ]; then echo "WARNING: macos/Podfile not found - skipping"; exit 0; fi
python3 - <<'PY'
import re
p = 'macos/Podfile'
s = open(p).read()
if 'CODE_SIGNING_ALLOWED' not in s:
    inject = """    if target.respond_to?(:product_type) && target.product_type == 'com.apple.product-type.bundle'
      target.build_configurations.each do |config|
        config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
      end
    end
"""
    new = re.sub(r"(flutter_additional_macos_build_settings\(target\)\n)", lambda m: m.group(1) + inject, s, count=1)
    if new == s:
        raise SystemExit('Could not find flutter_additional_macos_build_settings(target) in Podfile')
    open(p, 'w').write(new)
    print('Podfile patched')
PY

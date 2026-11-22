#!/usr/bin/env bash
# The CI job `ios` (on GitHub's macOS runner): an unsigned release build
# for iOS devices, with the licence page's notices and the required-reason
# APIs checked, then the XCTests of the native code on a simulator.
set -euo pipefail
# shellcheck source=tool/ci/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# The newest iOS runtime's first iPhone simulator.
ios_simulator() {
  xcrun simctl list devices available --json | python3 -I -c '
import json, re, sys
devices = json.load(sys.stdin)["devices"]
runtimes = [r for r in devices if ".SimRuntime.iOS-" in r]
runtimes.sort(key=lambda r: [int(n) for n in re.findall(r"\d+", r.rsplit(".", 1)[-1])], reverse=True)
for runtime in runtimes:
    for device in devices[runtime]:
        if device["name"].startswith("iPhone"):
            print(device["udid"])
            sys.exit()
sys.exit("error: no iPhone simulator available")
'
}

use_selected_xcode
setup_flutter
(cd "${repo_root}/app" && flutter build ios --release --no-codesign)
python3 -I "${repo_root}/tool/ci/ios_notices.py" "${repo_root}/app/build/ios/iphoneos/Runner.app"
python3 -I "${repo_root}/tool/ci/required_reason_apis.py" "${repo_root}/app/build/ios/iphoneos/Runner.app"
# RunnerTests has no host app (tool/add_runner_tests.rb), so this builds no
# Flutter app; the project needs the Swift package the build above generated.
simulator="$(ios_simulator)"
xcodebuild test -project "${repo_root}/app/ios/Runner.xcodeproj" -scheme RunnerTests \
  -destination "id=${simulator}" CODE_SIGNING_ALLOWED=NO

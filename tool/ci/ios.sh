#!/usr/bin/env bash
# The CI job `ios` (D86, on GitHub's macOS runner): an unsigned release build
# for iOS devices, with the licence page's notices and the required-reason
# APIs checked.
set -euo pipefail
# shellcheck source=tool/ci/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

use_selected_xcode
setup_flutter
(cd "${repo_root}/app" && flutter build ios --release --no-codesign)
python3 -I "${repo_root}/tool/ci/ios_notices.py" "${repo_root}/app/build/ios/iphoneos/Runner.app"
python3 -I "${repo_root}/tool/ci/required_reason_apis.py" "${repo_root}/app/build/ios/iphoneos/Runner.app"

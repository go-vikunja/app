#!/usr/bin/env bash
# The GitLab job `ios` (D73) on a Mac runner tagged macos: an unsigned
# release build for iOS devices, with the licence page's notices checked.
set -euo pipefail
# shellcheck source=tool/ci/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

use_selected_xcode
setup_flutter
(cd "${repo_root}/app" && flutter build ios --release --no-codesign)
python3 -I "${repo_root}/tool/ci/ios_notices.py" "${repo_root}/app/build/ios/iphoneos/Runner.app"

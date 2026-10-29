#!/usr/bin/env bash
# The GitLab job `ios` (D73) on a Mac runner tagged macos: an unsigned
# release build for iOS devices.
set -euo pipefail
# shellcheck source=tool/ci/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if [[ "$(xcode-select -p 2>/dev/null || true)" == */CommandLineTools && -d /Applications/Xcode.app ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
setup_flutter
(cd "${repo_root}/app" && flutter build ios --release --no-codesign)

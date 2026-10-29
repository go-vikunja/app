#!/usr/bin/env bash
# The GitLab job `android` (D73): the release APK with the debug key (no
# signing variables reach this job), its exported components and the
# widgets' Kotlin tests.
set -euo pipefail
# shellcheck source=tool/ci/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

setup_flutter
ci_gradle_memory
(cd "${repo_root}/app" && flutter build apk --release)
python3 -I "${repo_root}/tool/check_exported_components.py" --self-test
python3 -I "${repo_root}/tool/check_exported_components.py" \
  "${repo_root}/app/build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml"
# After the build, which writes gradlew, its wrapper jar and local.properties.
(cd "${repo_root}/app/android" && ./gradlew :app:testDebugUnitTest -x compileFlutterBuildDebug)

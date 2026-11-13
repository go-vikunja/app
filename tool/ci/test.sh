#!/usr/bin/env bash
# The tests of the GitLab job `checks` (D73), without the contract tests.
set -euo pipefail
# shellcheck source=tool/ci/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

setup_flutter
concurrency="--concurrency=$(flutter_test_concurrency)"
(cd "${repo_root}/app" && flutter test "$concurrency")
(cd "${repo_root}/packages/vikunja_domain" && flutter test "$concurrency")
# The date math around a DST change needs a zone that has one.
(cd "${repo_root}/packages/vikunja_logic" && flutter test "$concurrency" && TZ=Europe/Berlin flutter test "$concurrency" test/time)
(cd "${repo_root}/packages/vikunja_api" && flutter test "$concurrency" --exclude-tags contract)
(cd "${repo_root}/plugins/vikunja_widgets" && flutter test "$concurrency")

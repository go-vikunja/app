#!/usr/bin/env bash
# The tests of the CI job `checks`, without the contract tests
# (decision log: Releases).
set -euo pipefail
# shellcheck source=tool/ci/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

setup_flutter
concurrency="--concurrency=$(flutter_test_concurrency)"

# The date math around a DST change needs a zone that has one: the test files
# of the current package that import test/helpers/berlin.dart run once more
# there.
run_again_in_berlin() {
  local files=() file
  while IFS= read -r file; do
    files+=("$file")
  done < <(grep -rlF --include='*_test.dart' "helpers/berlin.dart'" test | sort)
  if [[ ${#files[@]} -eq 0 ]]; then
    echo "error: no test of $(basename "$PWD") imports test/helpers/berlin.dart" >&2
    return 1
  fi
  TZ=Europe/Berlin flutter test "$concurrency" "${files[@]}"
}

(cd "${repo_root}/app" && flutter test "$concurrency" && run_again_in_berlin)
(cd "${repo_root}/packages/vikunja_domain" && flutter test "$concurrency")
(cd "${repo_root}/packages/vikunja_logic" && flutter test "$concurrency" && run_again_in_berlin)
(cd "${repo_root}/packages/vikunja_api" && flutter test "$concurrency" --exclude-tags contract)
(cd "${repo_root}/plugins/vikunja_widgets" && flutter test "$concurrency")
(cd "${repo_root}/plugins/vikunja_storage_flush" && flutter test "$concurrency")

#!/usr/bin/env bash
# The CI job `contract` (D86): the contract tests against the Vikunja test
# server of test_servers/docker-compose.yaml, which the runner's own Docker
# publishes on 127.0.0.1. Locally the servers run in the developer's Docker
# and stay up, like tool/contract_tests.sh leaves them.
set -euo pipefail
# shellcheck source=tool/ci/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

compose_file="${repo_root}/test_servers/docker-compose.yaml"

if docker compose version >/dev/null 2>&1; then
  compose=(docker compose -f "$compose_file")
elif command -v docker-compose >/dev/null 2>&1; then
  compose=(docker-compose -f "$compose_file")
else
  echo "error: neither 'docker compose' nor 'docker-compose' is available" >&2
  exit 2
fi

cleanup() {
  local status=$?
  if ((status != 0)); then
    "${compose[@]}" ps --all || true
    "${compose[@]}" logs --no-color --timestamps || true
  fi
  exit "$status"
}
trap cleanup EXIT

"${compose[@]}" up -d --quiet-pull

setup_flutter
"${repo_root}/tool/wait_for_test_servers.sh"

# Every contract test lives in test/contract; naming it spares compiling the
# other test files only to skip them.
(cd "${repo_root}/packages/vikunja_api" && VIKUNJA_CONTRACT=1 flutter test --tags contract test/contract)
# Upcoming is compared with the server's filter strings in this zone. One
# file at a time: the app's files have not been run in parallel since the
# test server stopped answering parallel writes with "database is locked".
(cd "${repo_root}/app" && VIKUNJA_CONTRACT=1 TZ=Europe/Berlin flutter test --tags contract --concurrency=1 test/contract)

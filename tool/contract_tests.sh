#!/usr/bin/env bash
# Runs the vikunja_api contract tests against the Docker test servers, which
# `up -d` starts first, or recreates when VIKUNJA_APP_TEST_VIKUNJA_IMAGE names
# another image than the running one, so the tests always meet the requested
# release; a server that already runs it is left as it is.
#
# Usage: tool/contract_tests.sh [flutter test arguments ...]
# Example: tool/contract_tests.sh --plain-name '2.8.0'
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
compose_file="${repo_root}/test_servers/docker-compose.yaml"

if docker compose version >/dev/null 2>&1; then
  compose=(docker compose -f "$compose_file")
elif command -v docker-compose >/dev/null 2>&1; then
  compose=(docker-compose -f "$compose_file")
else
  echo "error: neither 'docker compose' nor 'docker-compose' is available" >&2
  exit 2
fi

"${compose[@]}" up -d

"${repo_root}/tool/wait_for_test_servers.sh"

cd "${repo_root}/packages/vikunja_api"
export VIKUNJA_CONTRACT=1
# Without a test path, only test/contract, where every contract test lives.
for arg in "$@"; do
  if [[ -e "${arg%%\?*}" ]]; then
    exec flutter test --tags contract "$@"
  fi
done
exec flutter test --tags contract "$@" test/contract

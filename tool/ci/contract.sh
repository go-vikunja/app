#!/usr/bin/env bash
# The CI job `contract` (D73 on GitLab, D86 on GitHub Actions): the contract
# tests against the Vikunja test servers of test_servers/docker-compose.yaml.
# On GitLab the servers run in the job's docker-in-docker service
# (DOCKER_HOST=tcp://docker:2376), which publishes them on 0.0.0.0 there; a
# forwarder brings them to localhost, where the tests, the servers' public URL
# and tool/wait_for_test_servers.sh expect them. On GitHub Actions the
# runner's own Docker publishes them on 127.0.0.1, so neither is needed.
# Locally the servers run in the developer's Docker and stay up, like
# tool/contract_tests.sh leaves them.
set -euo pipefail
# shellcheck source=tool/ci/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

compose_file="${repo_root}/test_servers/docker-compose.yaml"
port=34527
dind=0
if [[ "${DOCKER_HOST:-}" == tcp://docker:* ]]; then
  dind=1
fi

install_docker_cli() {
  local tmp plugins
  tmp="$(mktemp -d)"
  curl --fail --silent --show-error --location --retry 3 --output "${tmp}/docker.tgz" \
    "https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_CLI_VERSION}.tgz"
  verify_sha256 "${tmp}/docker.tgz" "$DOCKER_CLI_LINUX_AMD64_SHA256"
  tar -xzf "${tmp}/docker.tgz" -C "$tmp" docker/docker
  install -m 755 "${tmp}/docker/docker" /usr/local/bin/docker
  plugins="${HOME}/.docker/cli-plugins"
  mkdir -p "$plugins"
  curl --fail --silent --show-error --location --retry 3 --output "${tmp}/docker-compose" \
    "https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-x86_64"
  verify_sha256 "${tmp}/docker-compose" "$COMPOSE_LINUX_AMD64_SHA256"
  install -m 755 "${tmp}/docker-compose" "${plugins}/docker-compose"
  rm -rf "$tmp"
  if ! command -v socat >/dev/null 2>&1; then
    apt-get update -qq
    apt-get install -y -qq --no-install-recommends socat
  fi
  local deadline=$((SECONDS + 60))
  until docker info >/dev/null 2>&1; do
    if ((SECONDS >= deadline)); then
      echo "error: the docker-in-docker service did not answer within 60s" >&2
      return 1
    fi
    sleep 2
  done
}

if ((dind)); then
  install_docker_cli
fi

if docker compose version >/dev/null 2>&1; then
  compose=(docker compose -f "$compose_file")
elif command -v docker-compose >/dev/null 2>&1; then
  compose=(docker-compose -f "$compose_file")
else
  echo "error: neither 'docker compose' nor 'docker-compose' is available" >&2
  exit 2
fi

forwarders=()
cleanup() {
  local status=$?
  if ((status != 0)); then
    "${compose[@]}" ps --all || true
    "${compose[@]}" logs --no-color --timestamps || true
  fi
  if ((${#forwarders[@]} > 0)); then
    kill "${forwarders[@]}" 2>/dev/null || true
  fi
  exit "$status"
}
trap cleanup EXIT

"${compose[@]}" up -d --quiet-pull
if ((dind)); then
  socat "TCP-LISTEN:${port},bind=127.0.0.1,fork,reuseaddr" "TCP:docker:${port}" &
  forwarders+=("$!")
  socat "TCP6-LISTEN:${port},bind=[::1],fork,reuseaddr" "TCP:docker:${port}" 2>/dev/null &
  forwarders+=("$!")
fi

setup_flutter
"${repo_root}/tool/wait_for_test_servers.sh"

# Every contract test lives in test/contract; naming it spares compiling the
# other test files only to skip them.
(cd "${repo_root}/packages/vikunja_api" && VIKUNJA_CONTRACT=1 flutter test --tags contract test/contract)
# Upcoming is compared with the server's filter strings in this zone. One
# file at a time: the app's files have not been run in parallel since the
# test server stopped answering parallel writes with "database is locked".
(cd "${repo_root}/app" && VIKUNJA_CONTRACT=1 TZ=Europe/Berlin flutter test --tags contract --concurrency=1 test/contract)

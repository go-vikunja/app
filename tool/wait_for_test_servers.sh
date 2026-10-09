#!/usr/bin/env bash
# Polls GET /api/v1/info on each local Vikunja test server until it answers
# with a JSON document carrying a version, then prints a summary.
#
# Usage: tool/wait_for_test_servers.sh [port ...]
# Env:   VIKUNJA_TEST_HOST     host to probe (default: localhost)
#        WAIT_TIMEOUT_SECONDS  overall timeout (default: 180)
#
# Must run on macOS's bash 3.2: no associative arrays, no empty "${a[@]}".
set -euo pipefail

host="${VIKUNJA_TEST_HOST:-localhost}"
timeout_seconds="${WAIT_TIMEOUT_SECONDS:-180}"
poll_interval_seconds=2

if (($# > 0)); then
  ports=("$@")
else
  ports=(34510 34520 34523 34524 34527)
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "error: curl is required" >&2
  exit 2
fi

info_version() {
  local body version
  local json_object='^[[:space:]]*\{'
  body="$(curl --silent --fail --max-time 5 "http://${host}:$1/api/v1/info" 2>/dev/null)" || return 1
  [[ "$body" =~ $json_object ]] || return 1
  version="$(sed -n -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' <<<"$body")"
  version="${version%%$'\n'*}"
  [[ -n "$version" ]] || return 1
  printf '%s' "$version"
}

versions=()
for i in "${!ports[@]}"; do
  versions[i]=""
done

deadline=$((SECONDS + timeout_seconds))
echo "Waiting up to ${timeout_seconds}s for Vikunja on ${host}, ports: ${ports[*]}"
while true; do
  pending=0
  for i in "${!ports[@]}"; do
    if [[ -n "${versions[i]}" ]]; then
      continue
    fi
    if version="$(info_version "${ports[i]}")"; then
      versions[i]="$version"
    else
      pending=$((pending + 1))
    fi
  done
  if ((pending == 0 || SECONDS >= deadline)); then
    break
  fi
  sleep "$poll_interval_seconds"
done

echo
printf '%-7s %s\n' PORT VERSION
for i in "${!ports[@]}"; do
  printf '%-7s %s\n' "${ports[i]}" "${versions[i]:-NOT READY}"
done

if ((pending > 0)); then
  echo
  echo "error: ${pending} server(s) did not answer /api/v1/info within ${timeout_seconds}s" >&2
  exit 1
fi

#!/usr/bin/env bash
# Creates the end-to-end sign-in test user from test_servers/seed/e2e-user.env
# on local Vikunja test servers through POST /api/v1/register. Idempotent: an
# existing user is checked with one password login instead. Prints neither the
# password nor any token.
#
# Usage: tool/seed_e2e_user.sh [port | base URL ...]
#        (default: 34527, the `vikunja` test server)
# Env:   VIKUNJA_TEST_HOST  host for bare ports (default: localhost)
#        E2E_USER_ENV       credentials file (default: test_servers/seed/e2e-user.env)
#
# /register and /login share the server's sign-in limit (10 per minute per IP
# unless raised, as on the test servers; it cannot be disabled); a 429 is
# waited out once.
# Must run on macOS's bash 3.2.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
host="${VIKUNJA_TEST_HOST:-localhost}"
env_file="${E2E_USER_ENV:-${repo_root}/test_servers/seed/e2e-user.env}"
max_retry_after_seconds=65

for tool in curl jq; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "error: $tool is required" >&2
    exit 2
  fi
done

if [[ ! -r "$env_file" ]]; then
  echo "error: cannot read $env_file" >&2
  exit 2
fi

username=""
email=""
password=""
while IFS='=' read -r key value || [[ -n "$key" ]]; do
  case "$key" in
    E2E_USERNAME) username="$value" ;;
    E2E_EMAIL) email="$value" ;;
    E2E_PASSWORD) password="$value" ;;
  esac
done <"$env_file"
if [[ -z "$username" || -z "$email" || -z "$password" ]]; then
  echo "error: $env_file must set E2E_USERNAME, E2E_EMAIL and E2E_PASSWORD" >&2
  exit 2
fi

if (($# > 0)); then
  servers=("$@")
else
  servers=(34527)
fi

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Sets status, error_code and retry_after. The JSON body is built by jq from
# the environment and sent on stdin, so the password never appears in argv.
post_json() {
  local url="$1" body_filter="$2"
  rm -f "${tmp}/body" "${tmp}/headers"
  status="$(
    E2E_USERNAME="$username" E2E_EMAIL="$email" E2E_PASSWORD="$password" \
      jq -n "$body_filter" |
      curl --silent --show-error --max-time 15 \
        --request POST --header 'Content-Type: application/json' \
        --data-binary @- --dump-header "${tmp}/headers" \
        --output "${tmp}/body" --write-out '%{http_code}' "$url"
  )" || status="000"
  error_code=""
  retry_after=""
  if [[ -f "${tmp}/body" ]]; then
    error_code="$(jq -r '.code // empty' "${tmp}/body" 2>/dev/null || true)"
  fi
  if [[ -f "${tmp}/headers" ]]; then
    retry_after="$(tr -d '\r' <"${tmp}/headers" |
      sed -n -E 's/^[Rr]etry-[Aa]fter:[[:space:]]*([0-9]+).*/\1/p' | head -n 1)"
  fi
  rm -f "${tmp}/body" "${tmp}/headers"
}

post_json_waiting_out_429() {
  post_json "$@"
  if [[ "$status" == "429" ]]; then
    local wait_seconds="${retry_after:-60}"
    if ((wait_seconds > max_retry_after_seconds)); then
      wait_seconds=$max_retry_after_seconds
    fi
    echo "$1: rate limited, waiting ${wait_seconds}s" >&2
    sleep "$wait_seconds"
    post_json "$@"
  fi
}

register_body='{username: $ENV.E2E_USERNAME, email: $ENV.E2E_EMAIL, password: $ENV.E2E_PASSWORD}'
login_body='{username: $ENV.E2E_USERNAME, password: $ENV.E2E_PASSWORD}'

# Sets result, and ok=0 when the server does not end up with a usable user.
seed_server() {
  local base="$1"
  ok=1
  post_json_waiting_out_429 "${base}/api/v1/register" "$register_body"
  case "${status}:${error_code}" in
    200:*)
      result="created user ${username}"
      return
      ;;
    400:1001) ;;
    400:1002)
      ok=0
      result="${email} belongs to another user on this server"
      return
      ;;
    404:*)
      ok=0
      result="no /api/v1/register (registration disabled, or not Vikunja)"
      return
      ;;
    000:*)
      ok=0
      result="no response"
      return
      ;;
    *)
      ok=0
      result="register answered HTTP ${status}${error_code:+ code ${error_code}}"
      return
      ;;
  esac

  post_json_waiting_out_429 "${base}/api/v1/login" "$login_body"
  case "${status}:${error_code}" in
    200:*)
      result="user ${username} already exists, password matches"
      ;;
    403:1011)
      ok=0
      result="user ${username} exists with a different password; the server keeps its data in a tmpfs, so restarting its container resets it"
      ;;
    *)
      ok=0
      result="user ${username} exists, but the login check answered HTTP ${status}${error_code:+ code ${error_code}}"
      ;;
  esac
}

failed=0
for server in "${servers[@]}"; do
  if [[ "$server" =~ ^[0-9]+$ ]]; then
    base="http://${host}:${server}"
  else
    base="${server%/}"
  fi
  seed_server "$base"
  if ((ok)); then
    echo "${base}: ${result}"
  else
    echo "${base}: error: ${result}" >&2
    failed=1
  fi
done

exit "$failed"

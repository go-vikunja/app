#!/usr/bin/env bash
# Polls GET /api/v1/info on each local Vikunja test server until it answers
# with a JSON document carrying a version, then prints a summary.
#
# Usage: tool/wait_for_test_servers.sh [port ...]
#        tool/wait_for_test_servers.sh --tls [port ...]
# Env:   VIKUNJA_TEST_HOST     host to probe on plain ports (default: localhost)
#        WAIT_TIMEOUT_SECONDS  overall timeout (default: 180)
#        TLS_CERTS_DIR         certificates for --tls (default: test_servers/tls/generated)
#
# --tls waits for the opt-in `tls` compose profile (test_servers/tls/README.md)
# instead of 34527: 34531 over plain HTTP, 34528 with the self-signed key
# pinned, 34529 with the test CA and the client certificate, 34530 with the
# test CA and the access headers, all as https://localhost (SNI). Then it
# checks that each gate refuses a client without its credential. Only /info is
# requested, and the header values never appear in argv or output.
#
# Must run on macOS's bash 3.2: no associative arrays, no empty "${a[@]}".
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
host="${VIKUNJA_TEST_HOST:-localhost}"
timeout_seconds="${WAIT_TIMEOUT_SECONDS:-180}"
certs="${TLS_CERTS_DIR:-${repo_root}/test_servers/tls/generated}"
poll_interval_seconds=2

tls=0
if [[ "${1:-}" == "--tls" ]]; then
  tls=1
  shift
fi

targets=()
for port in "$@"; do
  targets+=("http:${port}")
done
if ((tls)); then
  targets+=(http:34531 pinned:34528 mtls:34529 headers:34530)
elif ((${#targets[@]} == 0)); then
  targets=(http:34527)
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "error: curl is required" >&2
  exit 2
fi

if ((tls)); then
  for file in selfsigned.pem ca.pem client.pem client.key wrong-client.pem wrong-client.key access.env; do
    if [[ ! -r "${certs}/${file}" ]]; then
      echo "error: ${certs}/${file} is missing; run tool/gen_tls_test_certs.sh first" >&2
      exit 2
    fi
  done
  if ! command -v openssl >/dev/null 2>&1; then
    echo "error: openssl is required for --tls" >&2
    exit 2
  fi
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  # curl's --pinnedpubkey takes the SHA-256 of the SubjectPublicKeyInfo.
  selfsigned_pin="sha256//$(openssl x509 -in "${certs}/selfsigned.pem" -pubkey -noout |
    openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl base64)"
  if ! grep -q '^VIKUNJA_APP_TEST_ACCESS_ID=' "${certs}/access.env"; then
    echo "error: ${certs}/access.env has no VIKUNJA_APP_TEST_ACCESS_ID (generated before the rename): run tool/gen_tls_test_certs.sh again" >&2
    exit 2
  fi
  access_id="$(sed -n 's/^VIKUNJA_APP_TEST_ACCESS_ID=//p' "${certs}/access.env")"
  access_secret="$(sed -n 's/^VIKUNJA_APP_TEST_ACCESS_SECRET=//p' "${certs}/access.env")"
  (
    umask 077
    printf 'CF-Access-Client-Id: %s\nCF-Access-Client-Secret: %s\n' "$access_id" "$access_secret" >"${tmp}/access-headers"
    printf 'CF-Access-Client-Id: %s\nCF-Access-Client-Secret: wrong-dummy-secret\n' "$access_id" >"${tmp}/wrong-access-headers"
  )
  unset access_id access_secret
fi

# kind, port, path, extra curl arguments...
fetch() {
  local kind="$1" port="$2" path="$3"
  shift 3
  case "$kind" in
    http) curl --silent --max-time 5 "$@" "http://${host}:${port}${path}" ;;
    pinned) curl --silent --max-time 5 --insecure --pinnedpubkey "$selfsigned_pin" "$@" "https://localhost:${port}${path}" ;;
    mtls | headers) curl --silent --max-time 5 --cacert "${certs}/ca.pem" "$@" "https://localhost:${port}${path}" ;;
  esac
}

credentials() {
  case "$1" in
    mtls) printf '%s\n' --cert "${certs}/client.pem" --key "${certs}/client.key" ;;
    headers) printf '%s\n' --header "@${tmp}/access-headers" ;;
  esac
}

info_version() {
  local kind="$1" port="$2" body version
  local json_object='^[[:space:]]*\{'
  local args=(--fail)
  while IFS= read -r arg; do
    args+=("$arg")
  done < <(credentials "$kind")
  body="$(fetch "$kind" "$port" /api/v1/info "${args[@]}" 2>/dev/null)" || return 1
  [[ "$body" =~ $json_object ]] || return 1
  version="$(sed -n -E 's/.*"version"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' <<<"$body")"
  version="${version%%$'\n'*}"
  [[ -n "$version" ]] || return 1
  printf '%s' "$version"
}

versions=()
for i in "${!targets[@]}"; do
  versions[i]=""
done

deadline=$((SECONDS + timeout_seconds))
echo "Waiting up to ${timeout_seconds}s for Vikunja: ${targets[*]}"
while true; do
  pending=0
  for i in "${!targets[@]}"; do
    if [[ -n "${versions[i]}" ]]; then
      continue
    fi
    if version="$(info_version "${targets[i]%%:*}" "${targets[i]#*:}")"; then
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
printf '%-7s %-8s %s\n' PORT ACCESS VERSION
for i in "${!targets[@]}"; do
  printf '%-7s %-8s %s\n' "${targets[i]#*:}" "${targets[i]%%:*}" "${versions[i]:-NOT READY}"
done

if ((pending > 0)); then
  echo
  echo "error: ${pending} server(s) did not answer /api/v1/info within ${timeout_seconds}s" >&2
  exit 1
fi

((tls)) || exit 0

gate_failures=0
# description, then a command that must succeed for the gate to hold
gate() {
  local description="$1"
  shift
  if "$@"; then
    printf '  ok    %s\n' "$description"
  else
    printf '  FAIL  %s\n' "$description"
    gate_failures=$((gate_failures + 1))
  fi
}

refused() {
  ! fetch "$@" --output /dev/null 2>/dev/null
}

redirected_off_host() {
  local answer
  answer="$(fetch "$@" --output /dev/null --write-out '%{http_code} %{redirect_url}' 2>/dev/null)" || return 1
  [[ "$answer" == 302\ https://* && "$answer" != *"//localhost"* ]]
}

echo
echo "Gates:"
gate "34528 fails verification without the pin" \
  refused mtls 34528 /api/v1/info
gate "34529 refuses a client without a certificate" \
  refused mtls 34529 /api/v1/info
gate "34529 refuses a certificate from another CA" \
  refused mtls 34529 /api/v1/info --cert "${certs}/wrong-client.pem" --key "${certs}/wrong-client.key"
gate "34530 redirects off the host without the access headers" \
  redirected_off_host headers 34530 /api/v1/info
gate "34530 redirects off the host with a wrong secret" \
  redirected_off_host headers 34530 /api/v1/info --header "@${tmp}/wrong-access-headers"

if ((gate_failures > 0)); then
  echo
  echo "error: ${gate_failures} gate(s) let a client through without its credential" >&2
  exit 1
fi

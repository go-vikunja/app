#!/usr/bin/env bash
# Generates the dummy TLS material for the opt-in `tls` compose profile
# (test_servers/tls/generated/, gitignored) or, with --fixtures, the committed
# unit-test set in app/test/fixtures/tls/. Every key, password and header value
# is a throwaway for local tests and is never trusted anywhere else.
#
# Usage: tool/gen_tls_test_certs.sh                     Docker set, random dummy password and access values
#        tool/gen_tls_test_certs.sh --fixtures          unit-test fixtures, fixed dummy password (see their README)
#        tool/gen_tls_test_certs.sh --renew-selfsigned  Docker set: only a new self-signed leaf (pin mismatch check)
# Env:   OPENSSL  OpenSSL 3 or newer to use (default: the first one found)
#
# Prints only the self-signed certificate's SHA-256 fingerprint, never the
# PKCS#12 password or the access header values.
# Must run on macOS's bash 3.2.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
docker_dir="${repo_root}/test_servers/tls/generated"
fixtures_dir="${repo_root}/app/test/fixtures/tls"
fixture_p12_password="dummy-fixture-password"

mode=docker
case "${1:-}" in
  "") ;;
  --fixtures) mode=fixtures ;;
  --renew-selfsigned) mode=renew ;;
  *)
    echo "usage: $0 [--fixtures | --renew-selfsigned]" >&2
    exit 2
    ;;
esac

if [[ "$mode" == fixtures ]]; then
  out_dir="$fixtures_dir"
  ca_days=7300
  selfsigned_days=7300
  # macOS applies Apple's TLS rules to CA-chained leaves even with custom
  # anchors: at most 825 days, so CA-trust tests on a Mac keep working.
  server_days=820
  client_days=7300
else
  out_dir="$docker_dir"
  ca_days=397
  selfsigned_days=397
  server_days=397
  client_days=397
fi

# LibreSSL (macOS's /usr/bin/openssl) lacks `-legacy` and OpenSSL 3's PKCS#12
# defaults (AES-256, PBKDF2), so only OpenSSL 3 or newer is accepted.
is_openssl3() {
  local version
  version="$("$1" version 2>/dev/null)" || return 1
  [[ "$version" =~ ^OpenSSL\ ([0-9]+)\. ]] || return 1
  ((BASH_REMATCH[1] >= 3))
}

find_openssl() {
  local candidate
  if [[ -n "${OPENSSL:-}" ]]; then
    if is_openssl3 "$OPENSSL"; then
      printf '%s' "$OPENSSL"
      return 0
    fi
    echo "error: OPENSSL=$OPENSSL is not OpenSSL 3 or newer" >&2
    return 1
  fi
  for candidate in openssl \
    /opt/homebrew/opt/openssl@3/bin/openssl \
    /opt/homebrew/bin/openssl \
    /usr/local/opt/openssl@3/bin/openssl \
    /usr/local/bin/openssl; do
    if command -v "$candidate" >/dev/null 2>&1 && is_openssl3 "$candidate"; then
      command -v "$candidate"
      return 0
    fi
  done
  echo "error: OpenSSL 3 or newer is required (LibreSSL is not enough): brew install openssl@3, or set OPENSSL" >&2
  return 1
}

openssl_bin="$(find_openssl)"

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
umask 077

cat >"${work}/openssl.cnf" <<'EOF'
[req]
distinguished_name = dn
prompt = no
[dn]
CN = unused
[ca_ext]
basicConstraints = critical,CA:TRUE,pathlen:0
keyUsage = critical,keyCertSign,cRLSign
subjectKeyIdentifier = hash
[selfsigned_ext]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = serverAuth
subjectAltName = DNS:localhost,IP:127.0.0.1
subjectKeyIdentifier = hash
[server_ext]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = serverAuth
subjectAltName = DNS:localhost,IP:127.0.0.1
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
[client_ext]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = clientAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always
EOF

ossl() {
  "$openssl_bin" "$@"
}

serial() {
  printf '0x%s' "$(ossl rand -hex 16)"
}

new_key() {
  ossl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out "${work}/$1.key"
}

subject() {
  printf '/O=Rurana tests (dummy)/CN=%s' "$1"
}

# name, common name, days, extension section
self_signed() {
  new_key "$1"
  ossl req -x509 -new -key "${work}/$1.key" -subj "$(subject "$2")" \
    -config "${work}/openssl.cnf" -extensions "$4" \
    -days "$3" -sha256 -set_serial "$(serial)" -out "${work}/$1.pem"
}

# name, common name, days, extension section, issuing CA name
ca_signed() {
  new_key "$1"
  ossl req -new -key "${work}/$1.key" -subj "$(subject "$2")" \
    -config "${work}/openssl.cnf" -out "${work}/$1.csr"
  ossl x509 -req -in "${work}/$1.csr" -CA "${work}/$5.pem" -CAkey "${work}/$5.key" \
    -extfile "${work}/openssl.cnf" -extensions "$4" \
    -days "$3" -sha256 -set_serial "$(serial)" -out "${work}/$1.pem" 2>"${work}/x509.log" || {
    cat "${work}/x509.log" >&2
    return 1
  }
}

# name, issuing CA name, certificate name, extra pkcs12 options...
pkcs12() {
  local name="$1" ca="$2" source="$3"
  shift 3
  RURANA_P12_PASSWORD="$p12_password" ossl pkcs12 -export "$@" \
    -inkey "${work}/${source}.key" -in "${work}/${source}.pem" \
    -certfile "${work}/${ca}.pem" -name "Rurana test client (dummy)" \
    -passout env:RURANA_P12_PASSWORD -out "${work}/${name}.p12"
}

fingerprint() {
  local value
  value="$(ossl x509 -in "$1" -noout -fingerprint -sha256)"
  printf '%s' "${value#*=}"
}

# date field (-startdate or -enddate) of a certificate as ISO 8601 UTC
cert_date() {
  local value
  value="$(ossl x509 -in "$1" -noout "$2" -dateopt iso_8601)"
  value="${value#*=}"
  printf '%s' "${value/ /T}"
}

cert_name() {
  local value
  value="$(ossl x509 -in "$1" -noout "$2" -nameopt compat)"
  printf '%s' "${value#*=}"
}

# manifest key, certificate file
manifest_entry() {
  local sha
  sha="$(fingerprint "$2")"
  printf '    "%s": {\n' "$1"
  printf '      "subject": "%s",\n' "$(cert_name "$2" -subject)"
  printf '      "issuer": "%s",\n' "$(cert_name "$2" -issuer)"
  printf '      "sha256": "%s",\n' "${sha//:/}"
  printf '      "notBefore": "%s",\n' "$(cert_date "$2" -startdate)"
  printf '      "notAfter": "%s"\n' "$(cert_date "$2" -enddate)"
  printf '    }'
}

# directory holding the certificate PEM files
write_manifest() {
  local dir="$1"
  {
    printf '{\n  "certificates": {\n'
    manifest_entry selfsigned.pem "${dir}/selfsigned.pem"
    printf ',\n'
    manifest_entry ca.pem "${dir}/ca.pem"
    printf ',\n'
    manifest_entry server.pem "${dir}/server.pem"
    printf ',\n'
    manifest_entry client-ca.pem "${dir}/client-ca.pem"
    printf ',\n'
    manifest_entry client.pem "${dir}/client.pem"
    printf ',\n'
    manifest_entry wrong-client.p12 "${dir}/wrong-client.pem"
    printf '\n  }\n}\n'
  } >"${work}/manifest.json"
}

print_fingerprint() {
  if [[ "$mode" == fixtures ]]; then
    echo "Self-signed fixture certificate, SHA-256:"
  else
    echo "Self-signed certificate (port 34528), SHA-256:"
  fi
  echo "  $(fingerprint "$1")"
}

if [[ "$mode" == renew ]]; then
  for file in selfsigned.pem ca.pem server.pem client-ca.pem client.pem wrong-client.pem; do
    if [[ ! -f "${out_dir}/${file}" ]]; then
      echo "error: ${out_dir}/${file} is missing; run $0 without options first" >&2
      exit 1
    fi
  done
  self_signed selfsigned "Rurana test self-signed (dummy)" "$selfsigned_days" selfsigned_ext
  cp "${out_dir}/ca.pem" "${out_dir}/server.pem" "${out_dir}/client-ca.pem" \
    "${out_dir}/client.pem" "${out_dir}/wrong-client.pem" "$work/"
  write_manifest "$work"
  chmod 600 "${work}/selfsigned.key"
  chmod 644 "${work}/selfsigned.pem" "${work}/manifest.json"
  mv -f "${work}/selfsigned.key" "${work}/selfsigned.pem" "${work}/manifest.json" "$out_dir/"
  echo "Renewed the self-signed certificate in ${out_dir}."
  echo "Restart the proxy to serve it: docker compose -f test_servers/docker-compose.yaml --profile tls restart tls-proxy"
  print_fingerprint "${out_dir}/selfsigned.pem"
  exit 0
fi

if [[ "$mode" == fixtures ]]; then
  p12_password="$fixture_p12_password"
  access_id="0123456789abcdef0123456789abcdef.access"
  access_secret="fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210"
else
  p12_password="$(ossl rand -hex 12)"
  access_id="$(ossl rand -hex 16).access"
  access_secret="$(ossl rand -hex 32)"
fi

self_signed selfsigned "Rurana test self-signed (dummy)" "$selfsigned_days" selfsigned_ext
self_signed ca "Rurana test CA (dummy)" "$ca_days" ca_ext
ca_signed server "Rurana test server (dummy)" "$server_days" server_ext ca
self_signed client-ca "Rurana test client CA (dummy)" "$ca_days" ca_ext
ca_signed client "Rurana test client (dummy)" "$client_days" client_ext client-ca
self_signed wrong-client-ca "Rurana test other client CA (dummy)" "$ca_days" ca_ext
ca_signed wrong-client "Rurana test wrong client (dummy)" "$client_days" client_ext wrong-client-ca

pkcs12 client client-ca client
pkcs12 client-legacy client-ca client -legacy
pkcs12 wrong-client wrong-client-ca wrong-client

printf '%s' "$p12_password" >"${work}/client-p12-password.txt"
{
  echo "# Dummy Cloudflare Access service token for the local test proxy only."
  echo "RURANA_TEST_ACCESS_ID=${access_id}"
  echo "RURANA_TEST_ACCESS_SECRET=${access_secret}"
} >"${work}/access.env"

write_manifest "$work"

if [[ "$mode" == fixtures ]]; then
  # The CA keys stay out of the repository: no test signs anything.
  files=(selfsigned.pem selfsigned.key ca.pem server.pem server.key
    client-ca.pem client.pem client.key client.p12 client-legacy.p12 wrong-client.p12
    client-p12-password.txt access.env manifest.json)
else
  files=(selfsigned.pem selfsigned.key ca.pem ca.key server.pem server.key
    client-ca.pem client-ca.key client.pem client.key client.p12 client-legacy.p12
    wrong-client-ca.pem wrong-client-ca.key wrong-client.pem wrong-client.key wrong-client.p12
    client-p12-password.txt access.env manifest.json)
fi

expiry() {
  cert_date "${work}/$1" -enddate
}

if [[ "$mode" == fixtures ]]; then
  cat >"${work}/README.md" <<EOF
# Dummy TLS fixtures (test only)

**Dummy, test only, never trusted anywhere.** These certificates, keys and
values exist only for the app's unit tests, which trust them inside a single
test run on 127.0.0.1. Never install them on a device or trust them in a real
client. The CA keys are not committed.

Regenerate the whole set with:

\`\`\`sh
tool/gen_tls_test_certs.sh --fixtures
\`\`\`

\`fixtures_expiry_test.dart\` fails 60 days before the CA-chained leaves expire.
The server leaf is valid for 820 days because macOS applies Apple's 825-day
limit to CA-chained server certificates, also with custom anchors.

PKCS#12 password (a dummy, also in \`client-p12-password.txt\`): \`${fixture_p12_password}\`

| File | What it is | notAfter |
|---|---|---|
| \`selfsigned.pem\`, \`selfsigned.key\` | Self-signed server leaf, no CA: only a pin trusts it. EC P-256, SAN \`DNS:localhost, IP:127.0.0.1\`, EKU serverAuth | $(expiry selfsigned.pem) |
| \`ca.pem\` | Test server CA | $(expiry ca.pem) |
| \`server.pem\`, \`server.key\` | Server leaf signed by \`ca.pem\`, SAN \`DNS:localhost, IP:127.0.0.1\`, EKU serverAuth | $(expiry server.pem) |
| \`client-ca.pem\` | Test client CA (what an mTLS server trusts and advertises) | $(expiry client-ca.pem) |
| \`client.pem\`, \`client.key\` | Client leaf signed by \`client-ca.pem\`, EKU clientAuth | $(expiry client.pem) |
| \`client.p12\` | \`client.pem\` + key + \`client-ca.pem\`, AES-256-CBC, PBKDF2, SHA-256 MAC | $(expiry client.pem) |
| \`client-legacy.p12\` | The same in the legacy format (3DES/RC2, SHA-1 MAC) | $(expiry client.pem) |
| \`wrong-client.p12\` | A client leaf from another CA, same password: an mTLS server trusting \`client-ca.pem\` refuses it | $(expiry wrong-client.pem) |
| \`client-p12-password.txt\` | The dummy PKCS#12 password, no trailing newline | |
| \`access.env\` | Dummy Cloudflare Access id and secret (\`RURANA_TEST_ACCESS_ID\`, \`RURANA_TEST_ACCESS_SECRET\`) | |
| \`manifest.json\` | Subject and issuer (as dart:io's \`X509Certificate\` prints them), SHA-256 of the DER (upper-case hex) and validity of each certificate | |
EOF
  files+=(README.md)
fi

(umask 022 && mkdir -p "$out_dir")
for file in "${files[@]}"; do
  case "$file" in
    *.key | *.p12 | client-p12-password.txt | access.env) chmod 600 "${work}/${file}" ;;
    *) chmod 644 "${work}/${file}" ;;
  esac
  mv -f "${work}/${file}" "${out_dir}/"
done

echo "Wrote ${#files[@]} files to ${out_dir}."
if [[ "$mode" == docker ]]; then
  echo "If the proxy runs, recreate it for the new access values: docker compose -f test_servers/docker-compose.yaml --profile tls up -d tls-proxy"
fi
print_fingerprint "${out_dir}/selfsigned.pem"

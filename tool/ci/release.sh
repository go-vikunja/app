#!/usr/bin/env bash
# The GitLab job `release` on a v* tag (D73): builds the Play bundle and the
# universal APK with the version from the tag, signed with the keys from the
# protected CI variables, checks them, and publishes a GitLab release with
# the APK, SHA256SUMS and the desugar_jdk_libs source. The bundle stays a job
# artifact for the manual Play upload.
#
# Usage: tool/ci/release.sh [--tag TAG] [--dry-run]
#
# --dry-run runs everything but the upload, with two throwaway keystores, a
# placeholder source URL and, while site/site.json has none, a placeholder
# site URL, and prints the release it would create; the tag defaults to
# v<the pubspec's version name>.
#
# CI variables (docs/releasing.md): RURANA_UPLOAD_KEYSTORE_BASE64,
# RURANA_UPLOAD_STORE_PASSWORD, RURANA_UPLOAD_KEY_ALIAS and
# RURANA_UPLOAD_KEY_PASSWORD sign the bundle, and the APK unless the four
# RURANA_APK_* variables are set too. The site URL is the site_url of
# site/site.json.
set -euo pipefail
# shellcheck source=tool/ci/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$repo_root"

usage() {
  echo "usage: tool/ci/release.sh [--tag TAG] [--dry-run]" >&2
  exit 2
}

tag=""
dry_run=0
while (($# > 0)); do
  case "$1" in
    --tag)
      (($# >= 2)) || usage
      tag="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    *) usage ;;
  esac
done

if [[ -z "$tag" ]]; then
  tag="${CI_COMMIT_TAG:-}"
fi
if [[ -z "$tag" ]]; then
  if ((dry_run)); then
    tag="v$(sed -n 's/^version:[[:space:]]*\([^+[:space:]]*\).*/\1/p' app/pubspec.yaml)"
  else
    echo "error: no tag: pass --tag or run in a tag pipeline" >&2
    exit 2
  fi
fi

version="$(python3 -I tool/ci/release_version.py "$tag")"
build_name="$(sed -n 's/^BUILD_NAME=//p' <<<"$version")"
build_number="$(sed -n 's/^BUILD_NUMBER=//p' <<<"$version")"
channel="$(sed -n 's/^CHANNEL=//p' <<<"$version")"
echo "Release ${tag}: build name ${build_name}, build number ${build_number}, ${channel}"

not_releasable=()
# Fails the real run; a warning and a reason in the dry run.
refuse() {
  if ((dry_run)); then
    echo "warning (dry run): $1" >&2
    not_releasable+=("$2")
  else
    echo "error: $1" >&2
    exit 1
  fi
}

# With a template, so that macOS's mktemp honours TMPDIR too.
work="$(mktemp -d "${TMPDIR:-/tmp}/rurana-release.XXXXXX")"
trap 'rm -rf "$work"' EXIT
trap 'exit 130' INT TERM

if ((dry_run)); then
  source_url=https://gitlab.example/rurana
  not_releasable+=("placeholder source URL" "throwaway keys")
  # Throwaway keys through the same variables and decoding as a real run.
  password="$(python3 -I -c 'import secrets; print(secrets.token_hex(20))')"
  for kind in UPLOAD APK; do
    alias_name="dry-run-$(tr '[:upper:]' '[:lower:]' <<<"$kind")"
    RURANA_DRY_RUN_PASSWORD="$password" keytool -genkeypair -noprompt -storetype PKCS12 \
      -keystore "${work}/dry-run-${kind}.p12" -alias "$alias_name" -keyalg RSA -keysize 2048 -validity 1 \
      -dname "CN=Rurana dry run ${kind}" -storepass:env RURANA_DRY_RUN_PASSWORD -keypass:env RURANA_DRY_RUN_PASSWORD
    encoded="$(base64 <"${work}/dry-run-${kind}.p12" | tr -d '\n')"
    printf -v "RURANA_${kind}_KEYSTORE_BASE64" '%s' "$encoded"
    printf -v "RURANA_${kind}_STORE_PASSWORD" '%s' "$password"
    printf -v "RURANA_${kind}_KEY_PASSWORD" '%s' "$password"
    printf -v "RURANA_${kind}_KEY_ALIAS" '%s' "$alias_name"
    rm -f "${work}/dry-run-${kind}.p12"
  done
  unset password encoded
else
  source_url="${CI_PROJECT_URL:-}"
  if [[ "$source_url" != https://?* ]]; then
    refuse "CI_PROJECT_URL (${source_url:-unset}) is not an https URL" "source URL"
  fi
  for name in CI_API_V4_URL CI_PROJECT_ID CI_JOB_TOKEN; do
    if [[ -z "${!name:-}" ]]; then
      refuse "${name} is not set: the release is published from GitLab's release job" "${name}"
    fi
  done
fi

# The website with the privacy policy and the legal notice, which the About
# page links (D76).
if ! site_url="$(python3 -I -c '
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    value = json.load(f).get("site_url")
print(value if isinstance(value, str) else "")' site/site.json)"; then
  echo "error: site/site.json cannot be read" >&2
  exit 1
fi
if [[ -z "$site_url" ]] && ((dry_run)); then
  site_url=https://rurana.example
  not_releasable+=("placeholder site URL")
elif [[ "$site_url" != https://?* ]]; then
  refuse "the site URL (${site_url:-empty}) is not an https URL: set site_url in site/site.json, the address of the website with the privacy policy" \
    "site URL"
elif ! python3 -I tool/build_site.py --check >/dev/null; then
  refuse "the website the app links cannot be built from site/site.json: fill it in until python3 -I tool/build_site.py --check passes" \
    "website incomplete"
fi

api="${CI_API_V4_URL:-https://gitlab.example/api/v4}/projects/${CI_PROJECT_ID:-0}"

# Out of the environment into unexported copies: no step but the build that a
# set signs gets its keystore and passwords (signed_build).
for kind in UPLOAD APK; do
  for field in KEYSTORE_BASE64 STORE_PASSWORD KEY_ALIAS KEY_PASSWORD; do
    name="RURANA_${kind}_${field}"
    printf -v "signing_${kind}_${field}" '%s' "${!name:-}"
    unset "$name"
  done
done

if [[ "${CI_PROJECT_VISIBILITY:-}" != public ]]; then
  refuse "the project is not public (CI_PROJECT_VISIBILITY=${CI_PROJECT_VISIBILITY:-unset}): the source link of a release must open for everyone (AGPL section 6)" \
    "project not public"
fi
# A public project can still keep single features to its members.
public_feature() {
  local status
  status="$(curl --silent --output /dev/null --write-out '%{http_code}' --retry 3 "${api}/$2" || true)"
  if [[ "$status" != 200 ]]; then
    refuse "anonymous users cannot read the project's $1 (GET ${api}/$2 answered ${status}): set it to \"Everyone With Access\" under Settings > General > Visibility; the source link and the release's files must open for everyone (AGPL section 6)" \
      "$1 not public"
  fi
}
if ((dry_run)); then
  echo "Would check that anonymous users can read the repository at ${tag}, the releases and the package registry."
else
  public_feature repository "repository/tree?ref=${tag}&per_page=1"
  public_feature releases "releases?per_page=1"
  public_feature "package registry" "packages?per_page=1"
fi
if ! python3 -I tool/build_android_notices.py --require-offer-contact >/dev/null 2>&1; then
  refuse "the written offer has no contact: set contact_email in site/site.json, then run python3 -I tool/build_android_notices.py to write app/assets/legal/android.md again" \
    "no written-offer contact"
fi

scope_hint="The signing variables are protected and scoped to the environment release: they reach only the release job of a protected v* tag (docs/releasing.md)."
# UPLOAD|APK: the names of the set's variables that are empty.
missing_signing_variables() {
  local field name names=()
  for field in KEYSTORE_BASE64 STORE_PASSWORD KEY_ALIAS KEY_PASSWORD; do
    name="signing_${1}_${field}"
    if [[ -z "${!name}" ]]; then
      names+=("RURANA_${1}_${field}")
    fi
  done
  echo "${names[*]:-}"
}
missing="$(missing_signing_variables UPLOAD)"
if [[ -n "$missing" ]]; then
  echo "error: ${missing} not set. ${scope_hint}" >&2
  exit 1
fi
missing="$(missing_signing_variables APK)"
if [[ -z "$missing" ]]; then
  apk_set=APK
elif [[ "$missing" == "RURANA_APK_KEYSTORE_BASE64 RURANA_APK_STORE_PASSWORD RURANA_APK_KEY_ALIAS RURANA_APK_KEY_PASSWORD" ]]; then
  apk_set=UPLOAD
  printf '%s\n' \
    '************************************************************************' \
    'warning: no RURANA_APK_* variables, so the upload key signs the public' \
    'APK as well. Sideloaded installs stay bound to the key of their first' \
    'APK for good. If the APK is meant to have a key of its own, cancel this' \
    'job and add the RURANA_APK_* variables (docs/releasing.md).' \
    '************************************************************************' >&2
else
  echo "error: the RURANA_APK_* set is incomplete (${missing} not set); set all four or none. ${scope_hint}" >&2
  exit 1
fi

# UPLOAD|APK: writes the set's keystore to ${work}/<set>.p12.
decode_keystore() {
  local name="signing_${1}_KEYSTORE_BASE64"
  if ! (umask 077 && printf '%s' "${!name}" | base64 --decode >"${work}/${1}.p12") 2>/dev/null ||
    [[ ! -s "${work}/${1}.p12" ]]; then
    rm -f "${work}/${1}.p12"
    echo "error: RURANA_${1}_KEYSTORE_BASE64 is not a base64 keystore" >&2
    return 1
  fi
}

# UPLOAD|APK: the SHA-256 of the set's certificate, lowercase hex without
# colons. Checks the keystore, its password and its alias before the long
# build, and leaves no keystore behind.
certificate_sha256() {
  local store_password="signing_${1}_STORE_PASSWORD" key_alias="signing_${1}_KEY_ALIAS" listing fingerprint
  decode_keystore "$1" || return 1
  if ! listing="$(RURANA_KEYTOOL_PASSWORD="${!store_password}" keytool -list -v -storetype PKCS12 \
    -keystore "${work}/${1}.p12" -alias "${!key_alias}" -storepass:env RURANA_KEYTOOL_PASSWORD 2>&1)"; then
    rm -f "${work}/${1}.p12"
    echo "error: RURANA_${1}_STORE_PASSWORD and RURANA_${1}_KEY_ALIAS do not open RURANA_${1}_KEYSTORE_BASE64: $(sed -n 1p <<<"$listing")" >&2
    return 1
  fi
  rm -f "${work}/${1}.p12"
  fingerprint="$(sed -n 's/^[[:space:]]*SHA256:[[:space:]]*//p' <<<"$listing" | sed -n 1p | tr -d ':' | tr '[:upper:]' '[:lower:]')"
  if [[ -z "$fingerprint" ]]; then
    echo "error: no certificate under RURANA_${1}_KEY_ALIAS in RURANA_${1}_KEYSTORE_BASE64" >&2
    return 1
  fi
  echo "$fingerprint"
}
upload_certificate="$(certificate_sha256 UPLOAD)"
apk_certificate="$upload_certificate"
if [[ "$apk_set" == APK ]]; then
  apk_certificate="$(certificate_sha256 APK)"
fi
echo "Certificates (SHA-256): bundle ${upload_certificate}, APK ${apk_certificate} (RURANA_${apk_set}_*)"

if ((dry_run)); then
  echo "Would check that ${api}/releases/${tag} and the package rurana/${build_name} do not exist."
else
  (umask 077 && printf 'JOB-TOKEN: %s\n' "$CI_JOB_TOKEN" >"${work}/token-header")
  status="$(curl --silent --output /dev/null --write-out '%{http_code}' --header "@${work}/token-header" \
    "${api}/releases/${tag}" || true)"
  case "$status" in
    404) ;;
    200)
      echo "error: release ${tag} exists; delete it in the UI to republish" >&2
      exit 1
      ;;
    *)
      echo "error: GET ${api}/releases/${tag} answered ${status}" >&2
      exit 1
      ;;
  esac
  existing="$(curl --fail-with-body --silent --show-error --header "@${work}/token-header" \
    "${api}/packages?package_type=generic&package_name=rurana&package_version=${build_name}")"
  if [[ "$existing" != "[]" ]]; then
    echo "error: delete package rurana/${build_name} first (Deploy > Package registry)" >&2
    exit 1
  fi
fi

# UPLOAD|APK, flutter build arguments: one build, the only step that gets the
# set's keystore and passwords, as the RURANA_SIGNING_* variables of
# app/android/app/build.gradle.kts.
signed_build() {
  local kind="$1"
  shift
  (
    trap 'rm -f "${work}/${kind}.p12"' EXIT
    decode_keystore "$kind"
    store_password="signing_${kind}_STORE_PASSWORD"
    key_alias="signing_${kind}_KEY_ALIAS"
    key_password="signing_${kind}_KEY_PASSWORD"
    export RURANA_SIGNING_STORE_FILE="${work}/${kind}.p12"
    export RURANA_SIGNING_STORE_PASSWORD="${!store_password}"
    export RURANA_SIGNING_KEY_ALIAS="${!key_alias}"
    export RURANA_SIGNING_KEY_PASSWORD="${!key_password}"
    cd app
    flutter build "$@" --release --build-name="$build_name" --build-number="$build_number" \
      --dart-define=SOURCE_CODE_URL="$source_url" --dart-define=SITE_URL="$site_url"
  )
}

setup_flutter
ci_gradle_memory

(cd app && flutter test --run-skipped --tags release --dart-define=SOURCE_CODE_URL="$source_url" \
  --dart-define=SITE_URL="$site_url")
python3 -I tool/build_android_notices.py --self-test
python3 -I tool/build_android_notices.py --check

signed_build UPLOAD appbundle
signed_build "$apk_set" apk

python3 -I tool/check_exported_components.py --self-test
python3 -I tool/check_exported_components.py \
  app/build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml

apk_built=app/build/app/outputs/flutter-apk/app-release.apk
aab_built=app/build/app/outputs/bundle/release/app-release.aab

apk_report="$("$(build_tool apksigner)" verify --verbose --print-certs "$apk_built")"
if ! grep -qx 'Verified using v2 scheme (APK Signature Scheme v2): true' <<<"$apk_report"; then
  echo "$apk_report" >&2
  echo "error: the APK has no valid v2 signature" >&2
  exit 1
fi
if ! grep -qx 'Number of signers: 1' <<<"$apk_report"; then
  echo "$apk_report" >&2
  echo "error: the APK does not have exactly one signer" >&2
  exit 1
fi
# apksigner up to build-tools 36 writes "Signer #1 certificate ...", from 37 "V2 Signer: certificate ...".
signer_line='^(Signer #1|V2 Signer:) certificate'
apk_signer="$(sed -E -n "s/${signer_line} SHA-256 digest: //p" <<<"$apk_report" | sed -n 1p)"
if [[ -z "$apk_signer" || "$apk_signer" != "$apk_certificate" ]]; then
  echo "error: the APK is signed by ${apk_signer:-nothing}, the RURANA_${apk_set}_* key is ${apk_certificate}" >&2
  exit 1
fi
if grep -Eq "${signer_line} DN: .*CN=Android Debug" <<<"$apk_report"; then
  echo "error: the APK is signed with a debug key" >&2
  exit 1
fi

aab_report="$(jarsigner -verify "$aab_built" 2>&1 || true)"
if ! grep -q '^jar verified\.' <<<"$aab_report"; then
  echo "$aab_report" >&2
  echo "error: the bundle's signature does not verify" >&2
  exit 1
fi
aab_certificate="$(keytool -printcert -jarfile "$aab_built")"
aab_signer="$(sed -n 's/^[[:space:]]*SHA256:[[:space:]]*//p' <<<"$aab_certificate" | sed -n 1p | tr -d ':' | tr '[:upper:]' '[:lower:]')"
if [[ -z "$aab_signer" || "$aab_signer" != "$upload_certificate" ]]; then
  echo "error: the bundle is signed by ${aab_signer:-nothing}, the RURANA_UPLOAD_* key is ${upload_certificate}" >&2
  exit 1
fi
if grep -q 'CN=Android Debug' <<<"$aab_certificate"; then
  echo "error: the bundle is signed with a debug key" >&2
  exit 1
fi

badging="$("$(build_tool aapt2)" dump badging "$apk_built")"
package_line="$(sed -n 1p <<<"$badging")"
if [[ "$package_line" != *" versionCode='${build_number}' versionName='${build_name}' "* ]]; then
  echo "error: the APK's version is not ${build_name} (${build_number}): ${package_line}" >&2
  exit 1
fi
echo "Verified: APK v2-signed by ${apk_signer} (RURANA_${apk_set}_*), bundle signed by ${aab_signer} (RURANA_UPLOAD_*), version ${build_name} (${build_number})."

out=build/release
apk_name="rurana-${build_name}.apk"
rm -rf "$out"
mkdir -p "$out"
cp "$apk_built" "${out}/${apk_name}"
cp "$aab_built" "${out}/app-release.aab"
source_archive="$(python3 -I tool/ci/desugar_source.py --fetch "$out")"
source_name="$(basename "$source_archive")"
desugar_commit="$(sed -n 's/^commit=//p' tool/android_notices/desugar_jdk_libs.source)"
(
  cd "$out"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$apk_name" "$source_name" >SHA256SUMS
  else
    shasum -a 256 "$apk_name" "$source_name" >SHA256SUMS
  fi
)
cat "${out}/SHA256SUMS"
echo "Bundle for Play (job artifact, not released): $(sha256_of "${out}/app-release.aab")  app-release.aab"
apk_sha256="$(sha256_of "${out}/${apk_name}")"

packages="${api}/packages/generic/rurana/${build_name}"
python3 -I - "$tag" "$build_name" "$channel" "$apk_name" "$apk_sha256" "$apk_signer" "$apk_set" \
  "${source_url}/-/tree/${tag}" "$source_name" "$desugar_commit" "$packages" >"${work}/release.json" <<'PYTHON'
import json
import sys

tag, name, channel, apk, apk_sha256, signer, apk_set, tree, source, commit, packages = sys.argv[1:]
beta = channel == 'beta'
description = '\n'.join([
    f'Rurana {name}' + (', a beta: it may still have rough edges.' if beta else '.'),
    '',
    f'- APK `{apk}`, SHA-256 `{apk_sha256}`',
    f'- APK signing certificate SHA-256 `{signer}`'
    + (' (the upload key of the Google Play bundles: no separate APK key was set)' if apk_set == 'UPLOAD' else ''),
    f'- Source code: {tree}',
    f'- `{source}`: the source code of desugar_jdk_libs at upstream commit {commit} (GPL-2.0 with the '
    'Classpath exception), which the app contains',
])
links = [
    {'name': f'{apk} (Android APK)', 'url': f'{packages}/{apk}', 'direct_asset_path': f'/{apk}',
     'link_type': 'package'},
    {'name': 'SHA256SUMS', 'url': f'{packages}/SHA256SUMS', 'direct_asset_path': '/SHA256SUMS',
     'link_type': 'other'},
    {'name': f'{source} (desugar_jdk_libs source)', 'url': f'{packages}/{source}', 'direct_asset_path': f'/{source}',
     'link_type': 'other'},
]
print(json.dumps({'name': f'Rurana {name}' + (' (beta)' if beta else ''), 'tag_name': tag,
                  'description': description, 'assets': {'links': links}}, indent=2))
PYTHON

uploads=("$apk_name" SHA256SUMS "$source_name")
if ((dry_run)); then
  echo
  echo "Would upload:"
  for file in "${uploads[@]}"; do
    echo "  PUT ${packages}/${file}"
  done
  echo "and create the release: POST ${api}/releases"
  cat "${work}/release.json"
  reasons="$(printf '%s, ' "${not_releasable[@]}")"
  echo "DRY RUN: NOT RELEASABLE (${reasons%, })"
  exit 0
fi

# A failure from here on leaves uploaded files without a release: delete the
# package rurana/<name> before retrying (docs/releasing.md).
for file in "${uploads[@]}"; do
  curl --fail-with-body --silent --show-error --header "@${work}/token-header" \
    --upload-file "${out}/${file}" "${packages}/${file}" >/dev/null
  echo "Uploaded ${file}"
done
curl --fail-with-body --silent --show-error --header "@${work}/token-header" \
  --header 'Content-Type: application/json' --data "@${work}/release.json" "${api}/releases" >/dev/null
echo "Released ${tag}: ${source_url}/-/releases/${tag}"

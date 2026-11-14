#!/usr/bin/env bash
# Signs the output of tool/ci/release_build.sh (D86): the bundle with the
# upload key (jarsigner), the APK with the APK key or else the upload key
# (apksigner). Checks both certificates against
# tool/ci/release_certificates.txt and writes build/release/signed/. GitHub's
# job `publish` in the environment release, and every dry run.
#
# Usage: tool/ci/release_sign.sh [--dry-run]
#
# Environment: KEYSTORE_BASE64 and KEY_PROPERTIES (storePassword, keyAlias,
# keyPassword), optionally APK_KEYSTORE_BASE64 and APK_KEY_PROPERTIES. With
# --dry-run, a dry-run build or no KEYSTORE_BASE64, throwaway keys sign.
set -euo pipefail
upload_keystore_base64="${KEYSTORE_BASE64:-}"
upload_key_properties="${KEY_PROPERTIES:-}"
apk_keystore_base64="${APK_KEYSTORE_BASE64:-}"
apk_key_properties="${APK_KEY_PROPERTIES:-}"
unset KEYSTORE_BASE64 KEY_PROPERTIES APK_KEYSTORE_BASE64 APK_KEY_PROPERTIES

# shellcheck source=tool/ci/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=tool/ci/release_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/release_lib.sh"
cd "$repo_root"

usage() {
  echo "usage: tool/ci/release_sign.sh [--dry-run]" >&2
  exit 2
}

dry_run=0
while (($# > 0)); do
  case "$1" in
    --dry-run)
      dry_run=1
      shift
      ;;
    *) usage ;;
  esac
done

unsigned_env="${release_unsigned_dir}/release.env"
unsigned_value() {
  release_env_value "$unsigned_env" "$1"
}
tag="$(unsigned_value TAG)"
build_name="$(unsigned_value BUILD_NAME)"
build_number="$(unsigned_value BUILD_NUMBER)"
channel="$(unsigned_value CHANNEL)"
source_url="$(unsigned_value SOURCE_URL)"
desugar_archive="$(unsigned_value DESUGAR_ARCHIVE)"
desugar_commit="$(unsigned_value DESUGAR_COMMIT)"
unsigned_aab_sha256="$(unsigned_value UNSIGNED_AAB_SHA256)"
unsigned_apk_sha256="$(unsigned_value UNSIGNED_APK_SHA256)"
desugar_sha256="$(unsigned_value DESUGAR_ARCHIVE_SHA256)"
build_dry_run="$(unsigned_value DRY_RUN)"
not_releasable="$(unsigned_value NOT_RELEASABLE)"

version="$(python3 -I tool/ci/release_version.py "$tag")"
for key in BUILD_NAME BUILD_NUMBER CHANNEL; do
  expected="$(sed -n "s/^${key}=//p" <<<"$version")"
  actual="$(unsigned_value "$key")"
  if [[ "$actual" != "$expected" ]]; then
    echo "error: ${unsigned_env} has ${key}=${actual}, the tag ${tag} gives ${expected}" >&2
    exit 1
  fi
done
if [[ "$build_dry_run" != 0 && "$build_dry_run" != 1 ]]; then
  echo "error: ${unsigned_env} has DRY_RUN=${build_dry_run}, not 0 or 1" >&2
  exit 1
fi
if [[ "$source_url" != https://?* || "$source_url" == *[[:space:]]* ]]; then
  echo "error: ${unsigned_env} has SOURCE_URL=${source_url}, not an https URL" >&2
  exit 1
fi
if [[ ! "$desugar_commit" =~ ^[0-9a-f]{40}$ ]]; then
  echo "error: ${unsigned_env} has DESUGAR_COMMIT=${desugar_commit}, not a commit id" >&2
  exit 1
fi
if [[ -z "$desugar_archive" || "$desugar_archive" == */* || "$desugar_archive" == .* ]]; then
  echo "error: ${unsigned_env} has DESUGAR_ARCHIVE=${desugar_archive}, not a file name" >&2
  exit 1
fi
verify_sha256 "${release_unsigned_dir}/app-release.aab" "$unsigned_aab_sha256"
verify_sha256 "${release_unsigned_dir}/app-release.apk" "$unsigned_apk_sha256"
verify_sha256 "${release_unsigned_dir}/${desugar_archive}" "$desugar_sha256"

add_reason() {
  not_releasable="${not_releasable:+${not_releasable}; }$1"
}

throwaway=0
if ((dry_run)) || [[ "$build_dry_run" == 1 ]]; then
  throwaway=1
elif [[ -z "$upload_keystore_base64" ]]; then
  throwaway=1
  printf '%s\n' \
    '************************************************************************' \
    'warning: no KEYSTORE_BASE64: signing with throwaway keys; nothing will be' \
    'published' \
    '************************************************************************' >&2
fi

work="$(release_work_dir)"
trap 'rm -rf "$work"' EXIT
trap 'exit 130' INT TERM

keytool="$(jdk_tool keytool)"
jarsigner="$(jdk_tool jarsigner)"
apksigner="$(build_tool apksigner)"
zipalign="$(build_tool zipalign)"
aapt2="$(build_tool aapt2)"

if ((throwaway)); then
  add_reason "throwaway keys"
  # A JKS with a key password of its own, like the old app's keystore.jks.
  store_password="$(python3 -I -c 'import secrets; print(secrets.token_hex(20))')"
  key_password="$(python3 -I -c 'import secrets; print(secrets.token_hex(20))')"
  VIKUNJA_APP_STORE_PASSWORD="$store_password" VIKUNJA_APP_KEY_PASSWORD="$key_password" \
    "$keytool" -genkeypair -noprompt -storetype JKS -keystore "${work}/dry-run.jks" -alias upload \
    -keyalg RSA -keysize 2048 -validity 1 -dname "CN=Vikunja app dry run" \
    -storepass:env VIKUNJA_APP_STORE_PASSWORD -keypass:env VIKUNJA_APP_KEY_PASSWORD
  upload_keystore_base64="$(base64 <"${work}/dry-run.jks" | tr -d '\n')"
  upload_key_properties="$(printf 'storeFile=dry-run.jks\nstorePassword=%s\nkeyAlias=upload\nkeyPassword=%s\n' \
    "$store_password" "$key_password")"
  rm -f "${work}/dry-run.jks"
  unset store_password key_password
  echo "Throwaway upload key: a JKS keystore, alias upload, with a key password of its own."
  apk_keystore_base64=""
  apk_key_properties=""
fi

if [[ -n "$apk_keystore_base64" && -n "$apk_key_properties" ]]; then
  apk_set=apk
elif [[ -z "$apk_keystore_base64" && -z "$apk_key_properties" ]]; then
  apk_set=upload
elif [[ -z "$apk_keystore_base64" ]]; then
  echo "error: APK_KEY_PROPERTIES is set but APK_KEYSTORE_BASE64 is not; set both or neither" >&2
  exit 1
else
  echo "error: APK_KEYSTORE_BASE64 is set but APK_KEY_PROPERTIES is not; set both or neither" >&2
  exit 1
fi

# file: JKS when the file starts with JKS's magic number, else PKCS12.
keystore_type() {
  if [[ "$(od -An -tx1 -N4 "$1" | tr -d ' \n')" == feedfeed ]]; then
    echo JKS
  else
    echo PKCS12
  fi
}

# upload|apk, keystore secret, properties secret, keystore base64, properties:
# writes ${work}/<set>.keystore and sets loaded_type, loaded_alias,
# loaded_store_password, loaded_key_password and loaded_certificate (SHA-256,
# lowercase hex without colons).
load_set() {
  local set="$1" keystore_name="$2" properties_name="$3" keystore="${work}/$1.keystore"
  local store_password key_alias key_password type listing fingerprint
  (
    umask 077
    export "${properties_name}=$5"
    exec python3 -I tool/ci/key_properties.py "$properties_name" >"${work}/${set}.props"
  )
  {
    IFS= read -r -d '' store_password
    IFS= read -r -d '' key_alias
    IFS= read -r -d '' key_password
  } <"${work}/${set}.props"
  rm -f "${work}/${set}.props"
  github_mask "$store_password"
  github_mask "$key_password"
  if ((!throwaway)); then
    github_mask "$key_alias"
  fi

  if ! (umask 077 && printf '%s' "$4" | base64 --decode >"$keystore") 2>/dev/null || [[ ! -s "$keystore" ]]; then
    rm -f "$keystore"
    echo "error: ${keystore_name} is not a base64 keystore" >&2
    return 1
  fi
  type="$(keystore_type "$keystore")"
  if ! listing="$(VIKUNJA_APP_STORE_PASSWORD="$store_password" "$keytool" -list -v -storetype "$type" \
    -keystore "$keystore" -alias "$key_alias" -storepass:env VIKUNJA_APP_STORE_PASSWORD 2>&1)"; then
    echo "error: ${properties_name}'s storePassword and keyAlias do not open ${keystore_name} (${type}): $(sed -n 1p <<<"$listing")" >&2
    return 1
  fi
  fingerprint="$(sed -n 's/^[[:space:]]*SHA256:[[:space:]]*//p' <<<"$listing" | sed -n 1p | tr -d ':' |
    tr '[:upper:]' '[:lower:]')"
  if [[ -z "$fingerprint" ]]; then
    echo "error: no certificate under ${properties_name}'s keyAlias in ${keystore_name}" >&2
    return 1
  fi
  loaded_type="$type"
  loaded_alias="$key_alias"
  loaded_store_password="$store_password"
  loaded_key_password="$key_password"
  loaded_certificate="$fingerprint"
  echo "${keystore_name}: ${type} keystore, certificate SHA-256 ${fingerprint}"
}

load_set upload KEYSTORE_BASE64 KEY_PROPERTIES "$upload_keystore_base64" "$upload_key_properties"
upload_keystore="${work}/upload.keystore"
upload_type="$loaded_type"
upload_alias="$loaded_alias"
upload_store_password="$loaded_store_password"
upload_key_password="$loaded_key_password"
upload_certificate="$loaded_certificate"
upload_label=KEYSTORE_BASE64
if ((throwaway)); then
  upload_label=throwaway
fi
if [[ "$apk_set" == apk ]]; then
  load_set apk APK_KEYSTORE_BASE64 APK_KEY_PROPERTIES "$apk_keystore_base64" "$apk_key_properties"
  apk_keystore="${work}/apk.keystore"
  apk_type="$loaded_type"
  apk_alias="$loaded_alias"
  apk_store_password="$loaded_store_password"
  apk_key_password="$loaded_key_password"
  apk_certificate="$loaded_certificate"
  apk_label=APK_KEYSTORE_BASE64
else
  apk_keystore="$upload_keystore"
  apk_type="$upload_type"
  apk_alias="$upload_alias"
  apk_store_password="$upload_store_password"
  apk_key_password="$upload_key_password"
  apk_certificate="$upload_certificate"
  apk_label="$upload_label"
fi
unset upload_keystore_base64 upload_key_properties apk_keystore_base64 apk_key_properties \
  loaded_store_password loaded_key_password

certificates_file=tool/ci/release_certificates.txt
committed_certificate() {
  local value
  value="$(sed -n "s/^$1=//p" "$certificates_file" | sed -n 1p)"
  if [[ -n "$value" && ! "$value" =~ ^[0-9a-f]{64}$ ]]; then
    echo "error: ${certificates_file}: $1=${value} is not a SHA-256 in lowercase hex without colons" >&2
    return 1
  fi
  echo "$value"
}
committed_upload="$(committed_certificate upload)"
committed_apk="$(committed_certificate apk)"
if ((throwaway)); then
  if [[ -z "$committed_upload" ]]; then
    add_reason "no committed certificate fingerprints (${certificates_file})"
  fi
else
  if [[ -z "$committed_upload" ]]; then
    echo "error: commit the upload certificate's SHA-256 in ${certificates_file} (docs/releasing.md)" >&2
    exit 1
  fi
  if [[ "$upload_certificate" != "$committed_upload" ]]; then
    echo "error: KEYSTORE_BASE64's certificate is ${upload_certificate}, ${certificates_file} has upload=${committed_upload}" >&2
    exit 1
  fi
  if [[ "$apk_set" == apk ]]; then
    if [[ -z "$committed_apk" ]]; then
      echo "error: APK_KEYSTORE_BASE64 is set: commit its certificate's SHA-256 as apk= in ${certificates_file} (docs/releasing.md)" >&2
      exit 1
    fi
    if [[ "$apk_certificate" != "$committed_apk" ]]; then
      echo "error: APK_KEYSTORE_BASE64's certificate is ${apk_certificate}, ${certificates_file} has apk=${committed_apk}" >&2
      exit 1
    fi
  elif [[ -n "$committed_apk" && "$committed_apk" != "$committed_upload" ]]; then
    echo "error: ${certificates_file} has apk=${committed_apk}, but no APK_KEYSTORE_BASE64 is set and the upload key would sign the APK" >&2
    exit 1
  fi
fi

rm -rf "$release_signed_dir"
mkdir -p "$release_signed_dir"
apk_file="vikunja-app-${build_name}.apk"
aab_signed="${release_signed_dir}/app-release.aab"
apk_signed="${release_signed_dir}/${apk_file}"

if ! VIKUNJA_APP_STORE_PASSWORD="$upload_store_password" VIKUNJA_APP_KEY_PASSWORD="$upload_key_password" \
  "$jarsigner" -keystore "$upload_keystore" -storetype "$upload_type" \
  -storepass:env VIKUNJA_APP_STORE_PASSWORD -keypass:env VIKUNJA_APP_KEY_PASSWORD \
  -signedjar "$aab_signed" "${release_unsigned_dir}/app-release.aab" "$upload_alias"; then
  echo "error: jarsigner could not sign the bundle with KEYSTORE_BASE64 (is KEY_PROPERTIES's keyPassword right?)" >&2
  exit 1
fi
if [[ "$apk_set" == apk ]]; then
  rm -f "$upload_keystore"
fi
sign_apk() {
  VIKUNJA_APP_STORE_PASSWORD="$apk_store_password" VIKUNJA_APP_KEY_PASSWORD="$apk_key_password" \
    "$apksigner" sign --ks "$apk_keystore" --ks-type "$apk_type" --ks-key-alias "$apk_alias" \
    --ks-pass env:VIKUNJA_APP_STORE_PASSWORD --key-pass env:VIKUNJA_APP_KEY_PASSWORD --v4-signing-enabled false \
    --out "$1" "${release_unsigned_dir}/app-release.apk"
}
if ! sign_apk "$apk_signed"; then
  echo "error: apksigner could not sign the APK with ${apk_label} (is the keyPassword of its properties right?)" >&2
  exit 1
fi
# A re-run of publish signs again, and dl.vikunja.io and the GitHub release
# skip only the same SHA-256: an EC or DSA signature differs every time.
if ! sign_apk "${work}/again.apk" || ! cmp -s "$apk_signed" "${work}/again.apk"; then
  echo "error: signing the APK twice with ${apk_label} gave two different files: a re-run could not match" \
    "an APK already published. Sign the APK with an RSA key (docs/releasing.md)" >&2
  exit 1
fi
rm -f "$upload_keystore" "$apk_keystore" "${work}/again.apk"
unset upload_store_password upload_key_password apk_store_password apk_key_password

if ! apk_report="$("$apksigner" verify --verbose --print-certs "$apk_signed")"; then
  echo "$apk_report" >&2
  echo "error: the signed APK does not verify" >&2
  exit 1
fi
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
# apksigner up to build-tools 36 writes "Signer #1 certificate ...", from 37
# "V2 Signer: certificate ...", or "V3.0 Signer: ..." for a v3 signature.
signer_line='^(Signer #1|V[0-9.]+ Signer:) certificate'
apk_signer="$(sed -E -n "s/${signer_line} SHA-256 digest: //p" <<<"$apk_report" | sort -u)"
if [[ -z "$apk_signer" || "$apk_signer" != "$apk_certificate" ]]; then
  echo "error: the APK is signed by ${apk_signer:-nothing}, the ${apk_label} key is ${apk_certificate}" >&2
  exit 1
fi
if grep -Eq "${signer_line} DN: .*CN=Android Debug" <<<"$apk_report"; then
  echo "error: the APK is signed with a debug key" >&2
  exit 1
fi
if ! "$zipalign" -c -P 16 4 "$apk_signed"; then
  echo "error: the APK is not aligned: 4 bytes, and native libraries at 16 KB pages" >&2
  exit 1
fi

aab_report="$("$jarsigner" -verify "$aab_signed" 2>&1 || true)"
if ! grep -q '^jar verified\.' <<<"$aab_report"; then
  echo "$aab_report" >&2
  echo "error: the bundle's signature does not verify" >&2
  exit 1
fi
aab_certificate="$("$keytool" -printcert -jarfile "$aab_signed")"
aab_signer="$(sed -n 's/^[[:space:]]*SHA256:[[:space:]]*//p' <<<"$aab_certificate" | sed -n 1p | tr -d ':' |
  tr '[:upper:]' '[:lower:]')"
if [[ -z "$aab_signer" || "$aab_signer" != "$upload_certificate" ]]; then
  echo "error: the bundle is signed by ${aab_signer:-nothing}, the ${upload_label} key is ${upload_certificate}" >&2
  exit 1
fi
if grep -q 'CN=Android Debug' <<<"$aab_certificate"; then
  echo "error: the bundle is signed with a debug key" >&2
  exit 1
fi

badging="$("$aapt2" dump badging "$apk_signed")"
package_line="$(sed -n 1p <<<"$badging")"
if [[ "$package_line" != *" versionCode='${build_number}' versionName='${build_name}' "* ]]; then
  echo "error: the APK's version is not ${build_name} (${build_number}): ${package_line}" >&2
  exit 1
fi

cp "${release_unsigned_dir}/${desugar_archive}" "${release_signed_dir}/${desugar_archive}"
(
  cd "$release_signed_dir"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$apk_file" "$desugar_archive" >SHA256SUMS
  else
    shasum -a 256 "$apk_file" "$desugar_archive" >SHA256SUMS
  fi
)
apk_sha256="$(sha256_of "$apk_signed")"
aab_sha256="$(sha256_of "$aab_signed")"
signing=release
if ((throwaway)); then
  signing=throwaway
fi
signed_dry_run=0
if ((dry_run)) || [[ "$build_dry_run" == 1 ]]; then
  signed_dry_run=1
fi

cat >"${release_signed_dir}/release.env" <<ENV
TAG=${tag}
BUILD_NAME=${build_name}
BUILD_NUMBER=${build_number}
CHANNEL=${channel}
SOURCE_URL=${source_url}
DESUGAR_ARCHIVE=${desugar_archive}
DESUGAR_COMMIT=${desugar_commit}
UNSIGNED_AAB_SHA256=${unsigned_aab_sha256}
UNSIGNED_APK_SHA256=${unsigned_apk_sha256}
DESUGAR_ARCHIVE_SHA256=${desugar_sha256}
DRY_RUN=${signed_dry_run}
APK_FILE=${apk_file}
APK_SHA256=${apk_sha256}
AAB_SHA256=${aab_sha256}
UPLOAD_CERT_SHA256=${upload_certificate}
APK_CERT_SHA256=${apk_certificate}
APK_SET=${apk_set}
SIGNING=${signing}
NOT_RELEASABLE=${not_releasable}
ENV
cat "${release_signed_dir}/release.env"
cat "${release_signed_dir}/SHA256SUMS"
echo "Verified: APK v2-signed by ${apk_signer} (${apk_label}) and aligned (zipalign -c -P 16 4), bundle verified and signed by ${aab_signer} (${upload_label}), version ${build_name} (${build_number})."

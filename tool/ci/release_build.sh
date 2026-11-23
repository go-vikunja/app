#!/usr/bin/env bash
# The unsigned Play bundle, the universal APK and the per-ABI APKs of a release
# tag, with the desugar_jdk_libs source and release.env, in
# build/release/unsigned/: GitHub's job `build` and the first step of
# tool/ci/release.sh (decision log: Releases). No secret reaches this script;
# release_sign.sh signs its output.
#
# Usage: tool/ci/release_build.sh [--tag TAG] [--dry-run]
#
# Anything but a tag run of go-vikunja/app on GitHub Actions is a dry run, whose
# failed checks become reasons in NOT_RELEASABLE. Outside GitHub Actions, only
# --dry-run runs. VIKUNJA_APP_ALLOW_INCOMPLETE_GERMAN, the repository variable
# of the same name in the job, names a patch release's tag that may go without
# every German text (check_german in release_lib.sh). VIKUNJA_APP_SENTRY_DSN,
# the repository variable of the same name, is the opt-in crash reports' Sentry
# DSN; a build without it has none, and one on another host than sentry.io fails
# (check_sentry_dsn in release_lib.sh; decision log: Diagnostics). The scripts
# never print it; GitHub's log still shows it with the step's env, unmasked as a
# variable, and every build carries it.
set -euo pipefail
# shellcheck source=tool/ci/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=tool/ci/release_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/release_lib.sh"
cd "$repo_root"

usage() {
  echo "usage: tool/ci/release_build.sh [--tag TAG] [--dry-run]" >&2
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

if [[ "${GITHUB_ACTIONS:-}" == true ]]; then
  host=github
elif ((dry_run)); then
  host=local
else
  echo "error: outside GitHub Actions, a release build is a dry run only: pass --dry-run" >&2
  exit 2
fi

not_releasable=""
add_reason() {
  not_releasable="${not_releasable:+${not_releasable}; }$1"
}
# Fails the real run; a warning and a reason in the dry run.
refuse() {
  if ((dry_run)); then
    echo "warning (dry run): $1" >&2
    add_reason "$2"
  else
    echo "error: $1" >&2
    exit 1
  fi
}

if ! official_release_run; then
  dry_run=1
  refuse "${NOT_OFFICIAL_REASON}: this build is a dry run" "$NOT_OFFICIAL_REASON"
fi

if [[ -z "$tag" && "$host" == github && "${GITHUB_REF_TYPE:-}" == tag ]]; then
  tag="${GITHUB_REF_NAME:-}"
fi
if [[ -z "$tag" ]]; then
  if ((dry_run)); then
    tag="v$(sed -n 's/^version:[[:space:]]*\([^+[:space:]]*\).*/\1/p' app/pubspec.yaml)"
  else
    echo "error: no tag: pass --tag or run on a tag" >&2
    exit 2
  fi
fi
if ((dry_run == 0)) && [[ "${GITHUB_REF_NAME:-}" != "$tag" ]]; then
  echo "error: GITHUB_REF_NAME (${GITHUB_REF_NAME:-unset}) is not ${tag}" >&2
  exit 1
fi

version="$(python3 -I tool/ci/release_version.py "$tag")"
build_name="$(sed -n 's/^BUILD_NAME=//p' <<<"$version")"
build_number="$(sed -n 's/^BUILD_NUMBER=//p' <<<"$version")"
channel="$(sed -n 's/^CHANNEL=//p' <<<"$version")"
echo "Release ${tag}: build name ${build_name}, build number ${build_number}, ${channel}"

github_repository_public() {
  [[ -n "${GITHUB_EVENT_PATH:-}" && -f "$GITHUB_EVENT_PATH" ]] || return 1
  python3 -I -c '
import json
import sys
with open(sys.argv[1], encoding="utf-8") as f:
    repository = json.load(f).get("repository") or {}
sys.exit(0 if repository.get("private") is False else 1)
' "$GITHUB_EVENT_PATH" 2>/dev/null
}

public=0
case "$host" in
  github)
    source_url="${GITHUB_SERVER_URL:-}/${GITHUB_REPOSITORY:-}/tree/${tag}"
    if github_repository_public; then
      public=1
    fi
    ;;
  local)
    source_url="https://source.example/vikunja-app/tree/${tag}"
    add_reason "placeholder source URL"
    ;;
esac
echo "Source code URL: ${source_url}"

if [[ "$source_url" != https://?* ]]; then
  refuse "the source URL ${source_url} is not an https URL" "source URL not https"
fi
if ((public)); then
  status="$(curl --silent --output /dev/null --write-out '%{http_code}' --retry 3 "$source_url" || true)"
  if [[ "$status" != 200 ]]; then
    refuse "${source_url} answered ${status} signed out: the source link of a release must open for everyone" \
      "source URL not public"
  else
    echo "OK: ${source_url} opens signed out."
  fi
else
  echo "Would check that ${source_url} opens signed out."
  if [[ "$host" != local ]]; then
    refuse "the repository is not public: the source link of a release must open for everyone" \
      "repository not public"
  fi
fi
if [[ "$host" == local ]]; then
  check_website_pages --would
else
  check_website_pages
fi
if ! python3 -I tool/build_android_notices.py --require-offer-contact >/dev/null 2>&1; then
  refuse "the written offer has no contact: set WRITTEN_OFFER_CONTACT in tool/build_android_notices.py, then run it to write app/assets/legal/android.md again" \
    "no written-offer contact"
fi
l10n_status=0
python3 -I tool/l10n_progress.py --shipped-list --min 50 || l10n_status=$?
if ((l10n_status == 1)); then
  echo "warning: a shipped language has less than 50 % of the English texts: translate it on Crowdin or take it out of app/lib/app/l10n/shipped_locales.dart (decision log: Languages)" >&2
elif ((l10n_status != 0)); then
  exit "$l10n_status"
fi
check_german "$tag"
check_sentry_dsn

rm -rf "$release_unsigned_dir"
apk_dir=app/build/app/outputs/flutter-apk
apk_built="${apk_dir}/app-release.apk"
aab_built=app/build/app/outputs/bundle/release/app-release.aab
abi_apks=()
for abi in "${RELEASE_APK_ABIS[@]}"; do
  abi_apks+=("${apk_dir}/app-${abi}-release.apk")
done
rm -f "$apk_built" "$aab_built" "${abi_apks[@]}"

setup_flutter
ci_gradle_setup
jarsigner="$(jdk_tool jarsigner)"
apksigner="$(build_tool apksigner)"
aapt2="$(build_tool aapt2)"

(cd app && flutter test --run-skipped --tags release --dart-define=SOURCE_CODE_URL="$source_url")
python3 -I tool/build_android_notices.py --self-test
python3 -I tool/build_android_notices.py --check

release_flutter_build() {
  (
    cd app
    VIKUNJA_APP_UNSIGNED=true flutter build "$@" --release --build-name="$build_name" \
      --build-number="$build_number" --dart-define=SOURCE_CODE_URL="$source_url" \
      --dart-define=VIKUNJA_APP_SENTRY_DSN="${VIKUNJA_APP_SENTRY_DSN:-}"
  )
}
must_exist() {
  if [[ ! -f "$1" ]]; then
    echo "error: the build wrote no $1" >&2
    exit 1
  fi
}
release_flutter_build appbundle
release_flutter_build apk
must_exist "$aab_built"
must_exist "$apk_built"
# Before the split build, which writes into the same folder.
mkdir -p "$release_unsigned_dir"
cp "$aab_built" "${release_unsigned_dir}/app-release.aab"
cp "$apk_built" "${release_unsigned_dir}/app-release.apk"
# Before the split build too, which moves the merged manifest into one folder
# per ABI.
python3 -I tool/check_exported_components.py --self-test
python3 -I tool/check_exported_components.py \
  app/build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml
# Without the property Flutter adds 1000 times the ABI's number to the version
# code, which would collide with the version codes of later releases.
release_flutter_build apk --split-per-abi --android-project-arg=force-version-code-ignoring-abi=true
for built in "${abi_apks[@]}"; do
  must_exist "$built"
  cp "$built" "${release_unsigned_dir}/"
done

aab_report="$("$jarsigner" -verify "${release_unsigned_dir}/app-release.aab" 2>&1 || true)"
if ! grep -q '^jar is unsigned\.' <<<"$aab_report"; then
  echo "$aab_report" >&2
  echo "error: the release build is signed (android/key.properties?)" >&2
  exit 1
fi
echo "Unsigned: jarsigner says \"jar is unsigned.\" of the bundle."
# apk, the ABIs of its native code
check_unsigned_apk() {
  local apk="$1" apk_report apk_error badging
  shift
  if apk_report="$("$apksigner" verify "$apk" 2>&1)"; then
    echo "error: $(basename "$apk") is signed (android/key.properties?)" >&2
    exit 1
  fi
  apk_error="$(grep -m 1 '^ERROR' <<<"$apk_report" || true)"
  echo "Unsigned: apksigner refuses $(basename "$apk"): ${apk_error:-DOES NOT VERIFY}"
  badging="$("$aapt2" dump badging "$apk")"
  check_apk_badging "$apk" "$badging" "$build_name" "$build_number" "$@"
}
check_unsigned_apk "${release_unsigned_dir}/app-release.apk" "${RELEASE_APK_ABIS[@]}"
for abi in "${RELEASE_APK_ABIS[@]}"; do
  check_unsigned_apk "${release_unsigned_dir}/app-${abi}-release.apk" "$abi"
done

desugar_archive="$(python3 -I tool/ci/desugar_source.py --fetch "$release_unsigned_dir")"
desugar_name="$(basename "$desugar_archive")"
desugar_commit="$(sed -n 's/^commit=//p' tool/android_notices/desugar_jdk_libs.source)"
aab_sha256="$(sha256_of "${release_unsigned_dir}/app-release.aab")"
apk_sha256="$(sha256_of "${release_unsigned_dir}/app-release.apk")"
desugar_sha256="$(sha256_of "${release_unsigned_dir}/${desugar_name}")"
abi_lines=""
abi_sums=()
for abi in "${RELEASE_APK_ABIS[@]}"; do
  abi_sha256="$(sha256_of "${release_unsigned_dir}/app-${abi}-release.apk")"
  abi_lines+="UNSIGNED_APK_$(release_abi_key "$abi")_SHA256=${abi_sha256}"$'\n'
  abi_sums+=("$abi_sha256" "app-${abi}-release.apk")
done

cat >"${release_unsigned_dir}/release.env" <<ENV
TAG=${tag}
BUILD_NAME=${build_name}
BUILD_NUMBER=${build_number}
CHANNEL=${channel}
SOURCE_URL=${source_url}
DESUGAR_ARCHIVE=${desugar_name}
DESUGAR_COMMIT=${desugar_commit}
UNSIGNED_AAB_SHA256=${aab_sha256}
UNSIGNED_APK_SHA256=${apk_sha256}
${abi_lines}DESUGAR_ARCHIVE_SHA256=${desugar_sha256}
DRY_RUN=${dry_run}
NOT_RELEASABLE=${not_releasable}
ENV
cat "${release_unsigned_dir}/release.env"
printf '%s  %s\n' "$aab_sha256" app-release.aab "$apk_sha256" app-release.apk "${abi_sums[@]}" \
  "$desugar_sha256" "$desugar_name"

#!/usr/bin/env bash
# The unsigned Play bundle and universal APK of a release tag, with the
# desugar_jdk_libs source and release.env, in build/release/unsigned/ (D86):
# GitHub's job `build` and the first step of tool/ci/release.sh. No secret
# reaches this script; release_sign.sh signs its output.
#
# Usage: tool/ci/release_build.sh [--tag TAG] [--dry-run]
#
# Anything but a tag run of go-vikunja/app on GitHub Actions is a dry run,
# whose failed checks become reasons in NOT_RELEASABLE. Outside GitHub
# Actions and GitLab CI, only --dry-run runs.
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
elif [[ "${GITLAB_CI:-}" == true ]]; then
  host=gitlab
elif ((dry_run)); then
  host=local
else
  echo "error: outside GitHub Actions and GitLab CI, a release build is a dry run only: pass --dry-run" >&2
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
  refuse "not a tag run of ${OFFICIAL_REPOSITORY} on GitHub Actions: this build is a dry run" \
    "not a tag run of go-vikunja/app on GitHub Actions"
fi

if [[ -z "$tag" && "$host" == github && "${GITHUB_REF_TYPE:-}" == tag ]]; then
  tag="${GITHUB_REF_NAME:-}"
fi
if [[ -z "$tag" ]]; then
  tag="${CI_COMMIT_TAG:-}"
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
  gitlab)
    source_url="${CI_PROJECT_URL:-}/-/tree/${tag}"
    if [[ "${CI_PROJECT_VISIBILITY:-}" == public ]]; then
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
  fi
else
  echo "Would check that ${source_url} opens signed out."
  if [[ "$host" != local ]]; then
    refuse "the repository is not public: the source link of a release must open for everyone" \
      "repository not public"
  fi
fi
if ! python3 -I tool/build_android_notices.py --require-offer-contact >/dev/null 2>&1; then
  refuse "the written offer has no contact: set WRITTEN_OFFER_CONTACT in tool/build_android_notices.py, then run it to write app/assets/legal/android.md again" \
    "no written-offer contact"
fi

rm -rf "$release_unsigned_dir"
apk_built=app/build/app/outputs/flutter-apk/app-release.apk
aab_built=app/build/app/outputs/bundle/release/app-release.aab
rm -f "$apk_built" "$aab_built"

setup_flutter
ci_gradle_setup
jarsigner="$(jdk_tool jarsigner)"
apksigner="$(build_tool apksigner)"
aapt2="$(build_tool aapt2)"

(cd app && flutter test --run-skipped --tags release --dart-define=SOURCE_CODE_URL="$source_url")
python3 -I tool/build_android_notices.py --self-test
python3 -I tool/build_android_notices.py --check

for kind in appbundle apk; do
  (
    cd app
    VIKUNJA_APP_UNSIGNED=true flutter build "$kind" --release --build-name="$build_name" \
      --build-number="$build_number" --dart-define=SOURCE_CODE_URL="$source_url"
  )
done

for built in "$aab_built" "$apk_built"; do
  if [[ ! -f "$built" ]]; then
    echo "error: the build wrote no ${built}" >&2
    exit 1
  fi
done

python3 -I tool/check_exported_components.py --self-test
python3 -I tool/check_exported_components.py \
  app/build/app/intermediates/merged_manifests/release/processReleaseManifest/AndroidManifest.xml

aab_report="$("$jarsigner" -verify "$aab_built" 2>&1 || true)"
if ! grep -q '^jar is unsigned\.' <<<"$aab_report"; then
  echo "$aab_report" >&2
  echo "error: the release build is signed (android/key.properties?)" >&2
  exit 1
fi
if apk_report="$("$apksigner" verify "$apk_built" 2>&1)"; then
  echo "error: the release build is signed (android/key.properties?)" >&2
  exit 1
fi
apk_error="$(grep -m 1 '^ERROR' <<<"$apk_report" || true)"
echo "Unsigned: jarsigner says \"jar is unsigned.\" of the bundle; apksigner refuses the APK: ${apk_error:-DOES NOT VERIFY}"

badging="$("$aapt2" dump badging "$apk_built")"
package_line="$(sed -n 1p <<<"$badging")"
if [[ "$package_line" != *" versionCode='${build_number}' versionName='${build_name}' "* ]]; then
  echo "error: the APK's version is not ${build_name} (${build_number}): ${package_line}" >&2
  exit 1
fi

mkdir -p "$release_unsigned_dir"
cp "$aab_built" "${release_unsigned_dir}/app-release.aab"
cp "$apk_built" "${release_unsigned_dir}/app-release.apk"
desugar_archive="$(python3 -I tool/ci/desugar_source.py --fetch "$release_unsigned_dir")"
desugar_name="$(basename "$desugar_archive")"
desugar_commit="$(sed -n 's/^commit=//p' tool/android_notices/desugar_jdk_libs.source)"
aab_sha256="$(sha256_of "${release_unsigned_dir}/app-release.aab")"
apk_sha256="$(sha256_of "${release_unsigned_dir}/app-release.apk")"
desugar_sha256="$(sha256_of "${release_unsigned_dir}/${desugar_name}")"

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
DESUGAR_ARCHIVE_SHA256=${desugar_sha256}
DRY_RUN=${dry_run}
NOT_RELEASABLE=${not_releasable}
ENV
cat "${release_unsigned_dir}/release.env"
printf '%s  %s\n' "$aab_sha256" app-release.aab "$apk_sha256" app-release.apk "$desugar_sha256" "$desugar_name"

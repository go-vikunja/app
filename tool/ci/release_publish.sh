#!/usr/bin/env bash
# The publish steps of .github/workflows/release.yaml (D86): the bundle to
# Google Play, the APK to dl.vikunja.io, the GitHub release. Publishes only
# from go-vikunja/app (release_lib.sh); otherwise prints what it would do.
# Each step skips what is already published with the same content, so
# re-running the job is the retry.
#
# Usage: tool/ci/release_publish.sh [--dry-run] scope|check|play|dl|github
#
#   scope   OUTSIDE_RELEASE_ENVIRONMENT=true|false: whether a release secret
#           is a repository or organisation secret (job secret-scope)
#   check   HAS_<secret>=true|false for the ten secrets of the publish job,
#           GITHUB_SHA; reads build/release/unsigned, the others
#           build/release/signed
#   play    GOOGLE_PLAY_SERVICE_ACCOUNT_JSON, VIKUNJA_APP_PLAY_ROLLOUT
#           (production's user fraction, default 0.1)
#   dl      S3_ACCESS_KEY, S3_SECRET_KEY, S3_ENDPOINT, S3_BUCKET, S3_REGION
#           (optional, default us-east-1)
#   github  GH_TOKEN, GITHUB_REPOSITORY, GITHUB_SHA
set -euo pipefail

# Unexported copies before any child process starts: only the one command
# that needs a secret gets it.
play_service_account="${GOOGLE_PLAY_SERVICE_ACCOUNT_JSON:-}"
s3_access_key="${S3_ACCESS_KEY:-}"
s3_secret_key="${S3_SECRET_KEY:-}"
s3_endpoint="${S3_ENDPOINT:-}"
s3_bucket="${S3_BUCKET:-}"
s3_region="${S3_REGION:-}"
unset GOOGLE_PLAY_SERVICE_ACCOUNT_JSON S3_ACCESS_KEY S3_SECRET_KEY S3_ENDPOINT S3_BUCKET S3_REGION

# shellcheck source=tool/ci/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=tool/ci/release_lib.sh
source "${repo_root}/tool/ci/release_lib.sh"
cd "$repo_root"

usage() {
  echo "usage: tool/ci/release_publish.sh [--dry-run] scope|check|play|dl|github" >&2
  exit 2
}

fail() {
  echo "error: $*" >&2
  exit 1
}

dry_run=0
if [[ "${1:-}" == --dry-run ]]; then
  dry_run=1
  shift
fi
(($# == 1)) || usage
step="$1"
case "$step" in
  scope | check | play | dl | github) ;;
  *) usage ;;
esac

# A job outside any environment sees only repository and organisation
# secrets: a release secret there is readable without the environment's
# reviewers, by any workflow pushed to any branch.
if [[ "$step" == scope ]]; then
  outside="KEYSTORE_BASE64, KEY_PROPERTIES, APK_KEYSTORE_BASE64, APK_KEY_PROPERTIES,"
  outside+=" GOOGLE_PLAY_SERVICE_ACCOUNT_JSON, S3_ACCESS_KEY or S3_SECRET_KEY"
  if ((dry_run)); then
    echo "Would check that no ${outside} is a repository or organisation secret of ${OFFICIAL_REPOSITORY}."
    exit 0
  fi
  case "${OUTSIDE_RELEASE_ENVIRONMENT:-}" in
    false)
      echo "No release secret is readable outside the environment release."
      exit 0
      ;;
    true)
      fail "${GITHUB_REPOSITORY:-this repository} can read ${outside} as a repository or organisation" \
        "secret, outside the reviewers of the environment release. Delete these repository secrets and remove" \
        "the repository from the access list of organisation secrets of these names; keep them in the" \
        "environment release only (docs/releasing.md)"
      ;;
    *) fail "OUTSIDE_RELEASE_ENVIRONMENT is ${OUTSIDE_RELEASE_ENVIRONMENT:-unset}, not true or false" ;;
  esac
fi

if [[ "$step" == check ]]; then
  release_dir="$release_unsigned_dir"
else
  release_dir="$release_signed_dir"
fi
env_file="${release_dir}/release.env"
value() {
  release_env_value "$env_file" "$1"
}

tag="$(value TAG)"
build_name="$(value BUILD_NAME)"
build_number="$(value BUILD_NUMBER)"
channel="$(value CHANNEL)"
source_url="$(value SOURCE_URL)"
desugar_archive="$(value DESUGAR_ARCHIVE)"
desugar_commit="$(value DESUGAR_COMMIT)"
desugar_sha256="$(value DESUGAR_ARCHIVE_SHA256)"
not_releasable="$(value NOT_RELEASABLE)"

# Consistency only: release_sign.sh already ran release_version.py, whose
# pubspec check would tie this script to the checked-out pubspec.
tag_pattern='^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-beta\.([1-9][0-9]*))?$'
if [[ ! "$tag" =~ $tag_pattern ]]; then
  fail "${env_file}: TAG (${tag}) is not a release tag"
fi
beta="${BASH_REMATCH[5]:-}"
expected_number=$((BASH_REMATCH[1] * 1000000 + BASH_REMATCH[2] * 10000 + BASH_REMATCH[3] * 100 + ${beta:-99}))
expected_channel=final
if [[ -n "$beta" ]]; then
  expected_channel=beta
fi
if [[ "$build_name" != "${tag#v}" || "$channel" != "$expected_channel" || "$build_number" != "$expected_number" ]]; then
  fail "${env_file}: BUILD_NAME (${build_name}), CHANNEL (${channel}) and BUILD_NUMBER (${build_number}) do not belong to ${tag}"
fi
name_pattern='^[A-Za-z0-9][A-Za-z0-9._-]*$'
commit_pattern='^[0-9a-f]{40}$'
sha256_pattern='^[0-9a-f]{64}$'
url_pattern='^https://[^[:space:]]+$'
fraction_pattern='^0\.[0-9]*[1-9][0-9]*$'
if [[ ! "$desugar_archive" =~ $name_pattern || ! "$desugar_commit" =~ $commit_pattern ||
  ! "$source_url" =~ $url_pattern ]]; then
  fail "${env_file}: DESUGAR_ARCHIVE, DESUGAR_COMMIT or SOURCE_URL is malformed"
fi

# file in the release directory, release.env key of its SHA-256
check_file() {
  local expected
  expected="$(value "$2")"
  if [[ ! -f "${release_dir}/$1" ]]; then
    fail "${release_dir}/$1 is missing"
  fi
  if [[ "$(sha256_of "${release_dir}/$1")" != "$expected" ]]; then
    fail "${release_dir}/$1 does not have the SHA-256 that $2 in ${env_file} records"
  fi
}

apk_file="vikunja-app-${build_name}.apk"
signing=""
if [[ "$step" == check ]]; then
  check_file app-release.aab UNSIGNED_AAB_SHA256
  check_file app-release.apk UNSIGNED_APK_SHA256
  check_file "$desugar_archive" DESUGAR_ARCHIVE_SHA256
else
  if [[ "$(value APK_FILE)" != "$apk_file" ]]; then
    fail "${env_file}: APK_FILE is not ${apk_file}"
  fi
  apk_sha256="$(value APK_SHA256)"
  apk_certificate="$(value APK_CERT_SHA256)"
  signing="$(value SIGNING)"
  if [[ ! "$apk_certificate" =~ $sha256_pattern ]]; then
    fail "${env_file}: APK_CERT_SHA256 is not a SHA-256"
  fi
  if [[ "$signing" != release && "$signing" != throwaway ]]; then
    fail "${env_file}: SIGNING is neither release nor throwaway"
  fi
  check_file "$apk_file" APK_SHA256
  check_file app-release.aab AAB_SHA256
  check_file "$desugar_archive" DESUGAR_ARCHIVE_SHA256
  if [[ ! -f "${release_dir}/SHA256SUMS" ]] ||
    [[ "$(sort "${release_dir}/SHA256SUMS")" != "$(printf '%s  %s\n%s  %s\n' "$apk_sha256" "$apk_file" \
      "$desugar_sha256" "$desugar_archive" | sort)" ]]; then
    fail "${release_dir}/SHA256SUMS does not list exactly ${apk_file} and ${desugar_archive}"
  fi
fi

reasons=()
if ! official_release_run && [[ "; ${not_releasable}; " != *"; ${NOT_OFFICIAL_REASON}; "* ]]; then
  reasons+=("$NOT_OFFICIAL_REASON")
fi
if [[ -n "$not_releasable" ]]; then
  reasons+=("$not_releasable")
fi
if [[ "${GITHUB_REF_NAME:-}" != "$tag" ]]; then
  reasons+=("GITHUB_REF_NAME (${GITHUB_REF_NAME:-unset}) is not ${tag}")
fi
if [[ "$step" != check && "$signing" != release && "; ${not_releasable}; " != *"; throwaway keys; "* ]]; then
  reasons+=("signed with throwaway keys")
fi
if ((dry_run)); then
  reasons+=(--dry-run)
fi

not_published() {
  local joined
  joined="$(printf '%s; ' "${reasons[@]}")"
  if ((dry_run)); then
    echo "Not published: ${joined%; }"
    exit 0
  fi
  echo "Not published: ${joined%; }" >&2
  exit 1
}

work="$(release_work_dir)"
trap 'rm -rf "$work"' EXIT
trap 'exit 130' INT TERM

dl_key="app/${build_name}/${apk_file}"
release_title="Vikunja app ${build_name}"
if [[ "$channel" == beta ]]; then
  play_track=beta
  play_fraction=""
  release_flags=(--prerelease --latest=false)
  release_kind="a prerelease, not marked latest"
else
  play_track=production
  play_fraction="${VIKUNJA_APP_PLAY_ROLLOUT:-0.1}"
  release_flags=(--latest)
  release_kind="marked latest"
fi

print_plan() {
  local rollout="status completed"
  if [[ "$play_track" == production ]]; then
    rollout="staged rollout (inProgress) to a user fraction of ${VIKUNJA_APP_PLAY_ROLLOUT:-VIKUNJA_APP_PLAY_ROLLOUT, 0.1 when unset}"
  fi
  echo "$1 ${tag} (${channel}, versionCode ${build_number}):"
  echo "  Google Play io.vikunja.app: track ${play_track}, ${rollout}"
  echo "  dl.vikunja.io: ${dl_key}"
  echo "  GitHub release \"${release_title}\" in ${GITHUB_REPOSITORY:-<GITHUB_REPOSITORY>}, ${release_kind}"
}

has() {
  local name="HAS_$1"
  [[ "${!name:-}" == true ]]
}

retry_hint="('Re-run failed jobs' keeps the build; 'Re-run all jobs' builds and signs again)"

# The tag may have been moved since the build (the tag ruleset should forbid
# it): the release must not attach these files to another commit's source.
check_tag() {
  local listing tagged
  if [[ ! "${GITHUB_SHA:-}" =~ $commit_pattern ]]; then
    fail "GITHUB_SHA (${GITHUB_SHA:-unset}) is not a commit id"
  fi
  if ! listing="$(GIT_TERMINAL_PROMPT=0 git ls-remote "https://github.com/${GITHUB_REPOSITORY}" \
    "refs/tags/${tag}" "refs/tags/${tag}^{}" 2>"${work}/git.err")"; then
    echo "error: git ls-remote failed:" >&2
    sed 's/^/  /' "${work}/git.err" >&2
    exit 1
  fi
  tagged="$(awk -v ref="refs/tags/${tag}" '$2 == (ref "^{}") { peeled = $1 } $2 == ref { direct = $1 }
    END { print (peeled != "" ? peeled : direct) }' <<<"$listing")"
  if [[ "$tagged" != "$GITHUB_SHA" ]]; then
    fail "the tag ${tag} points at ${tagged:-nothing} in ${GITHUB_REPOSITORY}, not at ${GITHUB_SHA}," \
      "the commit this run built: nothing more is published from this run"
  fi
  echo "The tag ${tag} still points at the built commit ${GITHUB_SHA}."
}

run_check() {
  local missing=() name
  if ((${#reasons[@]})); then
    print_plan "Would release"
    if ((dry_run)); then
      echo "The publish job uses these secrets of the environment release in ${OFFICIAL_REPOSITORY}:"
      echo "  KEYSTORE_BASE64                   the upload keystore, base64 (required)"
      echo "  KEY_PROPERTIES                    its storePassword, keyAlias and keyPassword (required)"
      echo "  APK_KEYSTORE_BASE64               a separate APK keystore (optional, with APK_KEY_PROPERTIES)"
      echo "  APK_KEY_PROPERTIES                its properties (optional, with APK_KEYSTORE_BASE64)"
      echo "  GOOGLE_PLAY_SERVICE_ACCOUNT_JSON  the Play service account's JSON key (required)"
      echo "  S3_ACCESS_KEY                     dl.vikunja.io's storage (required)"
      echo "  S3_SECRET_KEY                     (required)"
      echo "  S3_ENDPOINT                       an https URL or a host name, host and port only (required)"
      echo "  S3_BUCKET                         (required)"
      echo "  S3_REGION                         (optional; us-east-1 when unset, which Cloudflare R2 takes as auto)"
      echo "and the repository variable VIKUNJA_APP_PLAY_ROLLOUT (production's user fraction, 0.1 when unset)."
      echo "None of these secrets but S3_ENDPOINT, S3_BUCKET and S3_REGION may be a repository or organisation"
      echo "secret: the job secret-scope fails then. Before signing and before the GitHub release, the tag must"
      echo "still point at the built commit GITHUB_SHA (${GITHUB_SHA:-unset})."
      echo "Guard: GITHUB_ACTIONS=${GITHUB_ACTIONS:-unset} GITHUB_REPOSITORY=${GITHUB_REPOSITORY:-unset}" \
        "GITHUB_REPOSITORY_ID=${GITHUB_REPOSITORY_ID:-unset} GITHUB_REF_TYPE=${GITHUB_REF_TYPE:-unset}" \
        "GITHUB_REF_NAME=${GITHUB_REF_NAME:-unset}"
      if official_release_run; then
        echo "  a tag run of ${OFFICIAL_REPOSITORY} (id ${OFFICIAL_REPOSITORY_ID}) on GitHub Actions"
      else
        echo "  not official: only a tag run of ${OFFICIAL_REPOSITORY} (id ${OFFICIAL_REPOSITORY_ID}) on GitHub Actions publishes"
      fi
    fi
    not_published
  fi

  print_plan "This job releases"
  check_tag
  if has KEYSTORE_BASE64 && has KEY_PROPERTIES; then
    for name in GOOGLE_PLAY_SERVICE_ACCOUNT_JSON S3_ACCESS_KEY S3_SECRET_KEY S3_ENDPOINT S3_BUCKET; do
      has "$name" || missing+=("$name")
    done
  elif has KEYSTORE_BASE64; then
    missing+=(KEY_PROPERTIES)
  elif has KEY_PROPERTIES; then
    missing+=(KEYSTORE_BASE64)
  fi
  if has APK_KEYSTORE_BASE64 && ! has APK_KEY_PROPERTIES; then
    missing+=(APK_KEY_PROPERTIES)
  elif has APK_KEY_PROPERTIES && ! has APK_KEYSTORE_BASE64; then
    missing+=(APK_KEYSTORE_BASE64)
  fi
  if ((${#missing[@]})); then
    fail "secrets missing in the environment release: ${missing[*]} (docs/releasing.md)"
  fi
  if ! has KEYSTORE_BASE64; then
    printf '%s\n' \
      '************************************************************************' \
      'warning: no signing secrets in the environment release: this run signs' \
      'with throwaway keys, publishes nothing and fails at the publish step.' \
      '************************************************************************' >&2
    return
  fi
  echo "The environment release has every secret this release needs."
  if ! has S3_REGION; then
    echo "S3_REGION is not set: dl uses us-east-1, which Cloudflare R2 takes as auto."
  fi
}

run_play() {
  local arguments
  if [[ -n "$play_fraction" && ! "$play_fraction" =~ $fraction_pattern ]]; then
    fail "VIKUNJA_APP_PLAY_ROLLOUT (${play_fraction}) is not a fraction between 0 and 1 such as 0.1"
  fi
  arguments=(--package io.vikunja.app --bundle "${release_dir}/app-release.aab" --version-code "$build_number"
    --track "$play_track" --release-name "$build_name")
  if [[ -n "$play_fraction" ]]; then
    arguments+=(--user-fraction "$play_fraction")
  fi
  if [[ -n "${VIKUNJA_APP_PLAY_API_ROOT:-}" ]]; then
    arguments+=(--api-root "$VIKUNJA_APP_PLAY_API_ROOT")
  fi
  if ((${#reasons[@]})); then
    echo "Would upload app-release.aab to Google Play's ${play_track} track:"
    python3 -I tool/ci/play_upload.py "${arguments[@]}" --dry-run
    not_published
  fi
  if [[ -z "$play_service_account" ]]; then
    fail "GOOGLE_PLAY_SERVICE_ACCOUNT_JSON is empty"
  fi
  (umask 077 && printf '%s' "$play_service_account" >"${work}/play.json")
  play_service_account=""
  python3 -I tool/ci/play_upload.py "${arguments[@]}" --service-account-file "${work}/play.json"
  rm -f "${work}/play.json"
}

s3api() {
  AWS_ACCESS_KEY_ID="$s3_access_key" AWS_SECRET_ACCESS_KEY="$s3_secret_key" \
    AWS_DEFAULT_REGION="${s3_region:-us-east-1}" AWS_CONFIG_FILE="${work}/aws-config" \
    AWS_SHARED_CREDENTIALS_FILE=/dev/null AWS_EC2_METADATA_DISABLED=true \
    AWS_REQUEST_CHECKSUM_CALCULATION=when_required AWS_RESPONSE_CHECKSUM_VALIDATION=when_required \
    aws --endpoint-url "$s3_endpoint" s3api "$@"
}

aws_failed() {
  echo "error: aws s3api $1 failed:" >&2
  sed 's/^/  /' "${work}/aws.err" >&2
  exit 1
}

run_dl() {
  local missing=() host existing status=0 endpoint_shown="<S3_ENDPOINT>" bucket_shown="<S3_BUCKET>"
  if ((${#reasons[@]})); then
    if [[ -n "$s3_endpoint" ]]; then
      endpoint_shown="\$S3_ENDPOINT"
    fi
    if [[ -n "$s3_bucket" ]]; then
      bucket_shown="\$S3_BUCKET"
    fi
    echo "Would upload the APK to dl.vikunja.io:"
    echo "  aws --endpoint-url ${endpoint_shown} s3api put-object" \
      "--bucket ${bucket_shown} --key ${dl_key} --body ${apk_file}" \
      "--content-type application/vnd.android.package-archive --metadata sha256=${apk_sha256}"
    echo "  with path-style addressing, unless head-object finds the key: skipped with this sha256, an error with another"
    not_published
  fi
  [[ -n "$s3_access_key" ]] || missing+=(S3_ACCESS_KEY)
  [[ -n "$s3_secret_key" ]] || missing+=(S3_SECRET_KEY)
  [[ -n "$s3_endpoint" ]] || missing+=(S3_ENDPOINT)
  [[ -n "$s3_bucket" ]] || missing+=(S3_BUCKET)
  if ((${#missing[@]})); then
    fail "${missing[*]} not set"
  fi
  case "$s3_endpoint" in
    [Hh][Tt][Tt][Pp][Ss]://*) host="${s3_endpoint#*://}" ;;
    *://*) fail "S3_ENDPOINT is not https: give an https URL or a host name" ;;
    *) host="$s3_endpoint" ;;
  esac
  while [[ "$host" == */ ]]; do
    host="${host%/}"
  done
  # kolaente/s3-action, the old consumer of this secret, used only the host
  # and port; botocore would put a path before the bucket.
  if [[ "$host" == *[/?#]* ]]; then
    host="${host%%[/?#]*}"
    echo "S3_ENDPOINT has a path or query: only its host and port are used."
  fi
  if [[ -z "$host" || "$host" == *[@[:space:]]* ]]; then
    fail "S3_ENDPOINT has no host"
  fi
  s3_endpoint="https://${host}"
  (umask 077 && printf '[default]\ns3 =\n    addressing_style = path\n' >"${work}/aws-config")

  existing="$(s3api head-object --bucket "$s3_bucket" --key "$dl_key" --query Metadata.sha256 --output text \
    2>"${work}/aws.err")" || status=$?
  if ((status == 0)); then
    if [[ "$existing" == "$apk_sha256" ]]; then
      echo "dl.vikunja.io has ${dl_key} with this SHA-256 already: already published"
      return
    fi
    fail "dl.vikunja.io has ${dl_key} with the SHA-256 metadata ${existing}, not ${apk_sha256}:" \
      "delete it from the bucket to publish this build ${retry_hint}"
  fi
  if ! grep -Eq '404|Not Found' "${work}/aws.err"; then
    aws_failed head-object
  fi
  if ! s3api put-object --bucket "$s3_bucket" --key "$dl_key" --body "${release_dir}/${apk_file}" \
    --content-type application/vnd.android.package-archive --metadata "sha256=${apk_sha256}" \
    >/dev/null 2>"${work}/aws.err"; then
    aws_failed put-object
  fi
  echo "Published the APK on dl.vikunja.io: ${dl_key}"
}

release_notes() {
  local intro="."
  if [[ "$channel" == beta ]]; then
    intro=", a beta: it may still have rough edges."
  fi
  printf '%s\n' \
    "${release_title}${intro}" \
    "" \
    "- APK \`${apk_file}\`, SHA-256 \`${apk_sha256}\`" \
    "- APK signing certificate SHA-256 \`${apk_certificate}\`" \
    "- Source code: ${source_url}" \
    "- \`${desugar_archive}\`: the source code of desugar_jdk_libs at upstream commit ${desugar_commit} (GPL-2.0 with the Classpath exception), which the app contains"
}

run_github() {
  local files status=0 state url file
  files=("${release_dir}/${apk_file}" "${release_dir}/SHA256SUMS" "${release_dir}/${desugar_archive}")
  if ((${#reasons[@]})); then
    echo "Would create the GitHub release ${tag}:"
    echo "  gh release create ${tag} --repo ${GITHUB_REPOSITORY:-<GITHUB_REPOSITORY>} --verify-tag" \
      "--title \"${release_title}\" --notes-file notes.md ${release_flags[*]} ${apk_file} SHA256SUMS ${desugar_archive}"
    echo "  after checking that the tag still points at the built commit and deleting a leftover draft;"
    echo "  a published release with these three files, the same SHA-256 each, is left as it is"
    echo "with the notes:"
    release_notes | sed 's/^/  /'
    not_published
  fi
  command -v gh >/dev/null 2>&1 || fail "gh is not on PATH"
  [[ -n "${GH_TOKEN:-}" ]] || fail "GH_TOKEN is not set"
  [[ -n "${GITHUB_REPOSITORY:-}" ]] || fail "GITHUB_REPOSITORY is not set"
  check_tag
  release_notes >"${work}/notes.md"

  gh release view "$tag" --repo "$GITHUB_REPOSITORY" --json isDraft,assets >"${work}/release.json" \
    2>"${work}/gh.err" || status=$?
  if ((status != 0)); then
    if ! grep -q 'release not found' "${work}/gh.err"; then
      echo "error: gh release view failed:" >&2
      sed 's/^/  /' "${work}/gh.err" >&2
      exit 1
    fi
    state=absent
  else
    python3 -I - "${work}/release.json" "${files[@]}" >"${work}/state" <<'PYTHON'
import json
import os
import sys

with open(sys.argv[1], encoding='utf-8') as f:
    release = json.load(f)
expected = sorted((os.path.basename(path), os.path.getsize(path)) for path in sys.argv[2:])
actual = sorted((str(asset.get('name')), asset.get('size') if isinstance(asset.get('size'), int) else -1)
                for asset in release.get('assets') or [])
print('draft' if release.get('isDraft') else 'sizes' if actual == expected else 'other')
PYTHON
    read -r state <"${work}/state"
  fi
  case "$state" in
    absent) ;;
    draft)
      echo "Deleting the leftover draft of the release ${tag}"
      gh release delete "$tag" --repo "$GITHUB_REPOSITORY" --yes
      ;;
    sizes)
      mkdir "${work}/published"
      if ! gh release download "$tag" --repo "$GITHUB_REPOSITORY" --dir "${work}/published" 2>"${work}/gh.err"; then
        echo "error: gh release download failed:" >&2
        sed 's/^/  /' "${work}/gh.err" >&2
        exit 1
      fi
      for file in "${files[@]}"; do
        if [[ ! -f "${work}/published/${file##*/}" ||
          "$(sha256_of "${work}/published/${file##*/}")" != "$(sha256_of "$file")" ]]; then
          fail "the GitHub release ${tag} has a ${file##*/} with other content: delete the release on GitHub" \
            "to publish this build ${retry_hint}"
        fi
      done
      echo "The GitHub release ${tag} has these three files already: already published"
      return
      ;;
    *)
      fail "the GitHub release ${tag} exists with other files: delete it on GitHub to publish this build" \
        "${retry_hint}"
      ;;
  esac
  url="$(gh release create "$tag" --repo "$GITHUB_REPOSITORY" --verify-tag --title "$release_title" \
    --notes-file "${work}/notes.md" "${release_flags[@]}" "${files[@]}")"
  echo "Published the GitHub release: ${url}"
}

case "$step" in
  check) run_check ;;
  play) run_play ;;
  dl) run_dl ;;
  github) run_github ;;
esac

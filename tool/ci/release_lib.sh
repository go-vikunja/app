# shellcheck shell=bash
# Shared by the release scripts (D86): release.sh, release_build.sh,
# release_sign.sh and release_publish.sh source it after lib.sh.
# shellcheck disable=SC2034

OFFICIAL_REPOSITORY=go-vikunja/app
# The numeric id as well: another repository renamed to this name does not pass.
OFFICIAL_REPOSITORY_ID=395095540
# release_publish.sh finds it in the build's NOT_RELEASABLE by this text.
NOT_OFFICIAL_REASON="not a tag run of ${OFFICIAL_REPOSITORY} on GitHub Actions"

release_root="${VIKUNJA_APP_RELEASE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/build/release}"
release_unsigned_dir="${release_root}/unsigned"
release_signed_dir="${release_root}/signed"

# The only runs that publish: GitHub Actions on a tag of the official repository.
official_release_run() {
  [[ "${GITHUB_ACTIONS:-}" == true && "${GITHUB_REPOSITORY:-}" == "$OFFICIAL_REPOSITORY" &&
    "${GITHUB_REPOSITORY_ID:-}" == "$OFFICIAL_REPOSITORY_ID" && "${GITHUB_REF_TYPE:-}" == tag ]]
}

# file key: the value of the file's first KEY= line, empty without one.
release_env_value() {
  if [[ ! -f "$1" ]]; then
    echo "error: $1 is missing" >&2
    return 1
  fi
  sed -n "s/^$2=//p" "$1" | sed -n 1p
}

# GitHub masks a multi-line secret line by line, not the values inside it.
github_mask() {
  local value="$1"
  if [[ "${GITHUB_ACTIONS:-}" != true || -z "$value" ]]; then
    return 0
  fi
  value=${value//\%/%25}
  value=${value//$'\r'/%0D}
  value=${value//$'\n'/%0A}
  printf '::add-mask::%s\n' "$value"
}

# RUNNER_TEMP is emptied after every GitHub job.
release_work_dir() {
  mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/vikunja-app-release.XXXXXX"
}

# jdk_tool keytool|jarsigner: JAVA_HOME's copy, which ci_gradle_setup may
# have switched, else the one on PATH.
jdk_tool() {
  if [[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/$1" ]]; then
    echo "${JAVA_HOME}/bin/$1"
  else
    echo "$1"
  fi
}

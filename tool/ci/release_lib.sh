# shellcheck shell=bash
# Shared by the release scripts (D86): release.sh, release_build.sh,
# release_sign.sh, release_publish.sh and ios_release.sh source it after lib.sh.
# shellcheck disable=SC2034

OFFICIAL_REPOSITORY=go-vikunja/app
# The numeric id as well: another repository renamed to this name does not pass.
OFFICIAL_REPOSITORY_ID=395095540
# release_publish.sh finds it in the build's NOT_RELEASABLE by this text.
NOT_OFFICIAL_REASON="not a tag run of ${OFFICIAL_REPOSITORY} on GitHub Actions"

release_root="${VIKUNJA_APP_RELEASE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/build/release}"
release_unsigned_dir="${release_root}/unsigned"
release_signed_dir="${release_root}/signed"

# The per-ABI APKs beside the universal one, by Flutter's ABI names. They
# keep the universal APK's version code, so a device moves between them.
RELEASE_APK_ABIS=(arm64-v8a armeabi-v7a x86_64)

# abi: its part of a release.env key, ARM64_V8A for arm64-v8a.
release_abi_key() {
  printf '%s' "$1" | LC_ALL=C tr 'a-z-' 'A-Z_'
}

# apk, its `aapt2 dump badging`, build name, build number, ABI ...: exits
# unless the APK has this version and native code for exactly these ABIs.
check_apk_badging() {
  local apk="$1" badging="$2" name="$3" number="$4" package_line found expected
  shift 4
  package_line="$(sed -n 1p <<<"$badging")"
  if [[ "$package_line" != *" versionCode='${number}' versionName='${name}' "* ]]; then
    echo "error: the version of $(basename "$apk") is not ${name} (${number}): ${package_line}" >&2
    exit 1
  fi
  found="$(sed -n "s/^native-code: //p" <<<"$badging" | tr -d "'" | tr ' ' '\n' | sed '/^$/d' | LC_ALL=C sort |
    tr '\n' ' ')"
  expected="$(printf '%s\n' "$@" | LC_ALL=C sort | tr '\n' ' ')"
  if [[ "$found" != "$expected" ]]; then
    echo "error: $(basename "$apk") has native code for ${found% }, not for ${expected% }" >&2
    exit 1
  fi
}

# tag: German must have every English text (D88). A patch release (x.y.z with
# z > 0) may go without when VIKUNJA_APP_ALLOW_INCOMPLETE_GERMAN names its
# tag, so the override never carries over to the next release (owner,
# 2026-11-18); the log then says how many texts English stands in for.
# Refusals go to the caller's refuse MESSAGE REASON. Run from the repository.
check_german() {
  local tag="$1" allowed="${VIKUNJA_APP_ALLOW_INCOMPLETE_GERMAN:-}" report status=0 translated total
  local missing lacks patch='^v[0-9]+\.[0-9]+\.[1-9][0-9]*(-beta\.[0-9]+)?$'
  report="$(python3 -I tool/l10n_progress.py --min 100 de)" || status=$?
  if ((status == 0)); then
    if [[ -n "$allowed" ]]; then
      echo "German is complete: VIKUNJA_APP_ALLOW_INCOMPLETE_GERMAN (${allowed}) is not needed; unset it."
    fi
    return 0
  fi
  if ((status != 1)); then
    refuse "tool/l10n_progress.py could not count the German texts (exit ${status})" "German incomplete"
    return 0
  fi
  read -r _ translated _ total _ <<<"$report"
  missing=$((total - translated))
  lacks="German lacks ${missing} of the ${total} English texts"
  if [[ -z "$allowed" && "$tag" =~ $patch ]]; then
    refuse "${lacks}: a release needs every English text in German (D88); finish it on Crowdin and merge Crowdin's pull request, or for this patch release set VIKUNJA_APP_ALLOW_INCOMPLETE_GERMAN=${tag} (docs/releasing.md)" \
      "German incomplete"
  elif [[ -z "$allowed" ]]; then
    refuse "${lacks}: a release needs every English text in German (D88), and ${tag} is no patch release, so the translations must be complete; finish them on Crowdin and merge Crowdin's pull request" \
      "German incomplete"
  elif [[ "$allowed" != "$tag" ]]; then
    refuse "${lacks}, and VIKUNJA_APP_ALLOW_INCOMPLETE_GERMAN names ${allowed}, not ${tag}" "German incomplete"
  elif [[ ! "$tag" =~ $patch ]]; then
    refuse "${lacks}, and VIKUNJA_APP_ALLOW_INCOMPLETE_GERMAN is for patch releases only: ${tag} needs German complete" \
      "German incomplete"
  else
    echo "warning: ${lacks}; VIKUNJA_APP_ALLOW_INCOMPLETE_GERMAN releases the patch release ${tag} without them," \
      "and English stands in for them (D88)" >&2
    if [[ "${GITHUB_ACTIONS:-}" == true ]]; then
      echo "::warning title=German incomplete::${tag} is released with ${missing} of ${total} English texts not in German (VIKUNJA_APP_ALLOW_INCOMPLETE_GERMAN)"
    fi
  fi
}

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

# The vikunja.io pages that the app's About page (WebsitePage in
# app/lib/app/legal.dart) and the store listings (fastlane/metadata/, Play's
# account deletion URL in docs/store-listing.md) link, which the stores need
# live; test_website_pages.py keeps them equal. Links into Vikunja's docs are
# not release blockers.
RELEASE_WEBSITE_PAGES=(
  https://vikunja.io/help/mobile
  https://vikunja.io/help/mobile#delete-your-account
  https://vikunja.io/privacy/
  https://vikunja.io/privacy/#mobile-app
  https://vikunja.io/imprint/
)

# file id: whether the HTML file has an element with this id, in any form HTML
# allows (quoted or not, ID=, character references).
html_has_id() {
  python3 -I -c '
import html.parser
import sys


class Ids(html.parser.HTMLParser):
    found = False

    def handle_starttag(self, tag, attrs):
        self.found = self.found or ("id", sys.argv[2]) in attrs


parser = Ids()
with open(sys.argv[1], encoding="utf-8", errors="replace") as f:
    parser.feed(f.read())
sys.exit(0 if parser.found else 1)
' "$1" "$2"
}

# Each page must answer 200 signed out and have the element its fragment
# names. Redirects are followed over https only and must end on the page's own
# origin: a move within vikunja.io (a trailing slash) still opens for the
# reader, a move to another host does not pass. Failures go to the caller's
# refuse MESSAGE REASON after the cleanup, since refuse may exit. --would only
# names the checks.
check_website_pages() {
  local url page anchor origin result status final problem why body="" i failed_messages=() failed_reasons=()
  if [[ "${1:-}" != --would ]]; then
    body="$(mktemp "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/vikunja-app-page.XXXXXX")"
  fi
  for url in "${RELEASE_WEBSITE_PAGES[@]}"; do
    page="${url%%#*}"
    anchor="${url#"$page"}"
    anchor="${anchor#\#}"
    if [[ -z "$body" ]]; then
      echo "Would check that ${url} opens signed out${anchor:+ and has the id ${anchor}}."
      continue
    fi
    origin="${page#https://}"
    origin="https://${origin%%/*}"
    result="$(curl --silent --location --max-redirs 5 --proto =https --max-time 30 --retry 3 \
      --output "$body" --write-out '%{http_code} %{url_effective}' "$page" || true)"
    status="${result%% *}"
    final="${result#* }"
    problem=""
    if [[ "$status" != 200 ]]; then
      problem="answered ${status:-nothing}"
      why="the app or a store listing links it, so it must open for everyone signed out (docs/vikunja-io-drafts.md)"
    elif [[ "$final" != "$origin" && "$final" != "${origin}/"* ]]; then
      problem="ends on ${final}"
      why="a page the app or a store listing links must stay on ${origin}"
    elif [[ -n "$anchor" ]] && ! html_has_id "$body" "$anchor"; then
      problem="has no element with the id ${anchor}"
      why="the link would open at the top of the page (docs/vikunja-io-drafts.md)"
    fi
    if [[ -n "$problem" ]]; then
      failed_messages+=("${url} ${problem}: ${why}")
      failed_reasons+=("${url} ${problem}")
    else
      echo "OK: ${url} opens signed out${anchor:+ and has the id ${anchor}}."
    fi
  done
  if [[ -n "$body" ]]; then
    rm -f "$body"
  fi
  for ((i = 0; i < ${#failed_reasons[@]}; i++)); do
    refuse "${failed_messages[i]}" "${failed_reasons[i]}"
  done
}

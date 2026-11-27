#!/usr/bin/env bash
# The workflow "Crowdin" (.github/workflows/crowdin.yaml): the English
# source up to Vikunja's Crowdin project, its approved translations back in a
# pull request from the branch crowdin. Only a run on main of go-vikunja/app
# on GitHub Actions talks to Crowdin or pushes; --dry-run prints what it would
# do.
#
# Usage: tool/ci/crowdin_sync.sh [--dry-run] upload|download|pull-request
#
#   upload        CROWDIN_PERSONAL_TOKEN: app_en.arb into the file crowdin.yml
#                 names (dest) of its project
#   download      CROWDIN_PERSONAL_TOKEN, GITHUB_OUTPUT: the approved
#                 translations that differ from the checkout into
#                 build/crowdin/arb, and changed=true|false
#   pull-request  GH_TOKEN: build/crowdin/arb committed on the branch crowdin,
#                 reset from the checked-out main, pushed unless the branch
#                 holds exactly that, and a pull request opened, or the open
#                 one's text updated
#
# upload and download skip with a notice when the token is not set.
set -euo pipefail

# Unexported copies before any child process starts: only the command that
# needs a token gets it.
crowdin_token="${CROWDIN_PERSONAL_TOKEN:-}"
github_token="${GH_TOKEN:-}"
unset CROWDIN_PERSONAL_TOKEN CROWDIN_PROJECT_ID CROWDIN_BASE_URL CROWDIN_BASE_PATH GH_TOKEN GITHUB_TOKEN

# shellcheck source=tool/ci/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=tool/ci/release_lib.sh
source "${repo_root}/tool/ci/release_lib.sh"
cd "$repo_root"

ARB_DIR=app/lib/l10n/arb
WORK_DIR=build/crowdin
PR_BRANCH=crowdin
COMMIT_MESSAGE="chore(i18n): update translations via Crowdin"
# Vikunja's bot identity, which the old app's nightly sync committed as.
BOT_NAME="Frederick [Bot]"
BOT_EMAIL=bot@vikunja.io
ARB_NAME='^app_[a-z]{2,3}(_[A-Za-z0-9]{2,8})?\.arb$'
DROPPED_LINE='^[A-Za-z0-9._?-]{1,80}$'

usage() {
  echo "usage: tool/ci/crowdin_sync.sh [--dry-run] upload|download|pull-request" >&2
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
  upload | download | pull-request) ;;
  *) usage ;;
esac

official_run() {
  [[ "${GITHUB_ACTIONS:-}" == true && "${GITHUB_REPOSITORY:-}" == "$OFFICIAL_REPOSITORY" &&
    "${GITHUB_REPOSITORY_ID:-}" == "$OFFICIAL_REPOSITORY_ID" && "${GITHUB_REF:-}" == refs/heads/main ]]
}

require_official_run() {
  if ! official_run; then
    fail "only a run on main of ${OFFICIAL_REPOSITORY} (id ${OFFICIAL_REPOSITORY_ID}) on GitHub Actions" \
      "talks to Crowdin or pushes (GITHUB_ACTIONS=${GITHUB_ACTIONS:-unset} GITHUB_REPOSITORY=${GITHUB_REPOSITORY:-unset}" \
      "GITHUB_REPOSITORY_ID=${GITHUB_REPOSITORY_ID:-unset} GITHUB_REF=${GITHUB_REF:-unset}); try --dry-run"
  fi
}

output() {
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "$1" >>"$GITHUB_OUTPUT"
  fi
}

summary() {
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    printf '%s\n' "$@" >>"$GITHUB_STEP_SUMMARY"
  fi
}

# A notice and exit 0 without the token: a test repository, or before the
# secret exists.
require_token() {
  if [[ -z "$crowdin_token" ]]; then
    echo "::notice title=Crowdin skipped::CROWDIN_PERSONAL_TOKEN is not set, so nothing is uploaded to or downloaded from Crowdin (docs/releasing.md)."
    if [[ "$step" == download ]]; then
      output changed=false
    fi
    exit 0
  fi
}

# Sets cli: the pinned release checked against its SHA-256 on a CI runner,
# otherwise a crowdin already on PATH.
cli=""
find_cli() {
  local dir version tmp
  if ! on_ci_runner && command -v crowdin >/dev/null 2>&1; then
    cli=crowdin
    version="$(crowdin --version 2>/dev/null | tr -d '[:space:]' || true)"
    if [[ "$version" != "$CROWDIN_CLI_VERSION" ]]; then
      echo "warning: crowdin ${version:-of unknown version} on PATH, tool/ci/pins.sh pins ${CROWDIN_CLI_VERSION}" >&2
    fi
    return
  fi
  if [[ "$(uname -s)/$(uname -m)" != Linux/x86_64 ]]; then
    fail "no pinned Crowdin CLI for $(uname -s)/$(uname -m); install crowdin ${CROWDIN_CLI_VERSION}"
  fi
  dir="${repo_root}/.cache/crowdin/${CROWDIN_CLI_VERSION}"
  cli="${dir}/crowdin"
  if [[ ! -f "$cli" ]]; then
    mkdir -p "$dir"
    tmp="$(mktemp "${dir}/download.XXXXXX")"
    echo "Downloading the Crowdin CLI ${CROWDIN_CLI_VERSION}"
    curl --fail --silent --show-error --location --retry 3 --output "$tmp" \
      "https://github.com/crowdin/crowdin-cli/releases/download/${CROWDIN_CLI_VERSION}/crowdin-linux-x64"
    mv "$tmp" "$cli"
  fi
  verify_sha256 "$cli" "$CROWDIN_CLI_LINUX_X64_SHA256"
  chmod +x "$cli"
  "$cli" --version
}

run_cli() {
  echo "+ crowdin $*"
  CROWDIN_PERSONAL_TOKEN="$crowdin_token" "$cli" "$@"
}

# Each file of the ARB folder but app_de.arb, with its SHA-256.
arb_state() {
  local file
  find "$ARB_DIR" -type f ! -path "${ARB_DIR}/app_de.arb" | LC_ALL=C sort | while IFS= read -r file; do
    printf '%s %s\n' "$(sha256_of "$file")" "$file"
  done
}

# A symlink from the export would make cp and the JSON check read its target,
# any file on the runner.
no_symlinks() {
  if [[ -n "$(find "$ARB_DIR" -type l -print -quit)" ]]; then
    fail "the download wrote a symbolic link into ${ARB_DIR}"
  fi
}

# stdin: an ARB file; prints how many messages it has, -1 when it is no JSON
# object (which the checks after it refuse).
message_count() {
  python3 -I -c '
import json, sys
data = json.load(sys.stdin)
print(sum(1 for key in data if not key.startswith("@")) if isinstance(data, dict) else -1)'
}

# path: back to the checked-out version, or gone if git has none.
restore() {
  git checkout -q HEAD -- "$1" 2>/dev/null || rm -f "$1"
}

if [[ "$step" == upload ]]; then
  if ((dry_run)); then
    echo "Would upload ${ARB_DIR}/app_en.arb to the file of the Crowdin project that crowdin.yml names:" \
      "crowdin upload sources"
    exit 0
  fi
  require_token
  require_official_run
  find_cli
  run_cli upload sources
  exit 0
fi

download_flags=(--export-only-approved --skip-untranslated-strings)

if [[ "$step" == download ]]; then
  if ((dry_run)); then
    echo "Would download the approved translations of the file crowdin.yml names:"
    echo "  crowdin download translations ${download_flags[*]} --exclude-language de"
    echo "  crowdin download translations ${download_flags[*]} --language de"
    echo "German comes only from its own download: a file of the other download named app_de.arb or app_en.arb," \
      "or not app_<code>.arb, is not taken. The changed files would go into ${WORK_DIR}/arb."
    exit 0
  fi
  require_token
  require_official_run
  if [[ -n "$(git status --porcelain --untracked-files=all -- "$ARB_DIR")" ]]; then
    fail "${ARB_DIR} differs from the checkout before the download"
  fi
  find_cli
  rm -rf "$WORK_DIR"
  mkdir -p "${WORK_DIR}/arb"
  : >"${WORK_DIR}/dropped.txt"

  # Every language but German first. Swiss German without its project-level
  # mapping, or any other language whose two-letter code is de or en, would
  # be written over app_de.arb or app_en.arb here (decision log: Languages).
  run_cli download translations "${download_flags[@]}" --exclude-language de
  no_symlinks
  dropped=()
  for name in app_de.arb app_en.arb; do
    if [[ -n "$(git status --porcelain -- "${ARB_DIR}/${name}")" ]]; then
      restore "${ARB_DIR}/${name}"
      dropped+=("$name")
    fi
  done

  before="$(arb_state)"
  run_cli download translations "${download_flags[@]}" --language de
  no_symlinks
  if [[ "$(arb_state)" != "$before" ]]; then
    fail "the download of German alone changed other files than ${ARB_DIR}/app_de.arb"
  fi

  listing="$(mktemp)"
  trap 'rm -f "$listing"' EXIT
  git ls-files -z --modified --others --exclude-standard -- "$ARB_DIR" >"$listing"
  taken=()
  while IFS= read -r -d '' path; do
    name="${path#"${ARB_DIR}/"}"
    if [[ ! -f "$path" ]]; then
      fail "the download removed ${path}"
    fi
    if [[ "$name" =~ $ARB_NAME && "$name" != app_en.arb ]]; then
      count="$(message_count <"$path" 2>/dev/null)" || count=-1
      if [[ "$count" == 0 ]]; then
        had="$(git show "HEAD:${path}" 2>/dev/null | message_count 2>/dev/null)" || had=0
        restore "$path"
        if [[ "$had" != 0 ]]; then
          echo "::warning title=Crowdin export without texts::${name} came without a text and is not taken, as the checkout has ${had}."
          summary "- **Not taken:** \`${name}\`: the export has no text, the checkout has ${had}"
        fi
        continue
      fi
      cp "$path" "${WORK_DIR}/arb/${name}"
      taken+=("$name")
    else
      restore "$path"
      dropped+=("$(printf '%s' "$name" | LC_ALL=C tr -c 'A-Za-z0-9._-' '?' | cut -c1-80)")
    fi
  done <"$listing"

  if ((${#taken[@]})); then
    python3 -I - "${WORK_DIR}/arb" <<'PYTHON'
import json
import os
import sys

for name in sorted(os.listdir(sys.argv[1])):
    with open(os.path.join(sys.argv[1], name), encoding='utf-8') as f:
        if not isinstance(json.load(f), dict):
            sys.exit(f'error: {name} from Crowdin is not a JSON object')
PYTHON
  fi
  for name in ${dropped[@]+"${dropped[@]}"}; do
    echo "$name" >>"${WORK_DIR}/dropped.txt"
    case "$name" in
      app_de.arb) reason="a language other than German was exported as app_de.arb, likely Vikunja's Swiss German without its mapping to gsw (decision log: Languages); German comes from its own download" ;;
      app_en.arb) reason="a language was exported as app_en.arb, the English source" ;;
      *) reason="not a name gen-l10n reads (app_<code>.arb)" ;;
    esac
    echo "::warning title=Crowdin file not taken::${name}: ${reason}"
    summary "- **Not taken:** \`${name}\`: ${reason}"
  done
  if ((${#taken[@]})); then
    echo "Changed by Crowdin's export: ${taken[*]}"
    summary "Changed by Crowdin's export: ${taken[*]}"
    output changed=true
  else
    echo "Crowdin's export changes no ARB file of the checkout."
    summary "Crowdin's export changes no ARB file of the checkout."
    output changed=false
  fi
  exit 0
fi

# pull-request: the artifact of the download step, which ran Crowdin's CLI,
# is untrusted here: only ARB files by name, as JSON objects, are taken.
if [[ ! -d "${WORK_DIR}/arb" ]]; then
  fail "${WORK_DIR}/arb is missing"
fi
files=()
shopt -s nullglob dotglob
for path in "${WORK_DIR}/arb"/*; do
  name="${path##*/}"
  if [[ -L "$path" || ! -f "$path" || ! "$name" =~ $ARB_NAME || "$name" == app_en.arb ]]; then
    fail "${WORK_DIR}/arb has an entry that is no translation's ARB file"
  fi
  files+=("$name")
done
shopt -u nullglob dotglob
if ((${#files[@]} == 0)); then
  fail "${WORK_DIR}/arb has no ARB file"
fi
python3 -I - "${WORK_DIR}/arb" <<'PYTHON'
import json
import os
import sys

for name in sorted(os.listdir(sys.argv[1])):
    path = os.path.join(sys.argv[1], name)
    if os.path.getsize(path) > 4 * 1024 * 1024:
        sys.exit(f'error: {name} is larger than 4 MiB')
    with open(path, encoding='utf-8') as f:
        if not isinstance(json.load(f), dict):
            sys.exit(f'error: {name} is not a JSON object')
PYTHON
dropped=()
if [[ -f "${WORK_DIR}/dropped.txt" ]]; then
  while IFS= read -r line; do
    if [[ ! "$line" =~ $DROPPED_LINE ]]; then
      fail "${WORK_DIR}/dropped.txt has a line that is no file name"
    fi
    dropped+=("$line")
  done <"${WORK_DIR}/dropped.txt"
fi

changed=()
for name in "${files[@]}"; do
  if ! cmp -s "${WORK_DIR}/arb/${name}" "${ARB_DIR}/${name}"; then
    changed+=("$name")
  fi
done
if ((${#changed[@]} == 0)); then
  echo "The checkout has these translations already: no pull request."
  exit 0
fi

ship_notes=""

pr_body() {
  local name
  cat <<'BODY'
The approved translations of Vikunja's Crowdin project, exported by the workflow "Crowdin" (`.github/workflows/crowdin.yaml`). Each sync replaces the branch `crowdin` with the checked-out `main` and the current export, so do not push to it.

**The checks wait for a maintainer.** This pull request comes from the workflow's own token, so GitHub holds its workflow runs until someone with write access approves them: in "Files changed", click "Awaiting approval" at the top right, then "Approve workflows to run" (or use the button in the merge box). Each push of the branch needs it again; runs left waiting for 30 days fail.

Read the diff of `app_de.arb` before merging: its texts must stay the German that Crowdin's proofreaders approved. German comes from a download of its own, so no other language is written into `app_de.arb`.
BODY
  if ((${#dropped[@]})); then
    printf '\n%s\n' "Not taken from the export (the run's warnings say why):"
    for name in "${dropped[@]}"; do
      printf '%s\n' "- \`${name}\`"
    done
  fi
  if [[ -n "$ship_notes" ]]; then
    printf '\n%s\n\n' "Languages at 50 % or more of the English texts, by \`tool/l10n_ship.py\` (decision log: Languages); review the lists it changed and the new language's texts before merging:"
    printf '%s\n' "$ship_notes" | sed 's/^/    /'
  fi
}

if ((dry_run)); then
  echo "Would commit ${changed[*]} as \"${COMMIT_MESSAGE}\" by ${BOT_NAME} <${BOT_EMAIL}> on the branch ${PR_BRANCH}," \
    "reset from the checked-out commit, push it unless it holds exactly that on this main already, and open a pull" \
    "request into main, or update the open one's text, with the body:"
  pr_body | sed 's/^/  /'
  exit 0
fi
require_official_run
if [[ -z "$github_token" ]]; then
  fail "GH_TOKEN is not set"
fi
command -v gh >/dev/null 2>&1 || fail "gh is not on PATH"
if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
  fail "the checkout has local changes"
fi

# Git asks gh for the token only when a command needs it; it is never written
# into .git/config.
remote_git() {
  GH_TOKEN="$github_token" git -c credential.helper= -c 'credential.helper=!gh auth git-credential' "$@"
}

for name in "${changed[@]}"; do
  cp "${WORK_DIR}/arb/${name}" "${ARB_DIR}/${name}"
done
# First-party code of this checkout, not the CLI's: it adds the languages that
# reached the share to the lists the tests keep equal.
shipped_files="${WORK_DIR}/shipped.txt"
: >"$shipped_files"
ship_notes="$(python3 -I tool/l10n_ship.py --changed-files "$shipped_files")" || fail "tool/l10n_ship.py failed"
if [[ -n "$ship_notes" ]]; then
  echo "$ship_notes"
fi
shipped=()
while IFS= read -r path; do
  if [[ "$path" == /* || "$path" == *..* ]] || ! git ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
    fail "tool/l10n_ship.py named ${path}, which is not a file of the checkout"
  fi
  shipped+=("$path")
done <"$shipped_files"
# The reflogs need an identity too; git would guess one from the host.
export GIT_AUTHOR_NAME="$BOT_NAME" GIT_AUTHOR_EMAIL="$BOT_EMAIL"
export GIT_COMMITTER_NAME="$BOT_NAME" GIT_COMMITTER_EMAIL="$BOT_EMAIL"
git switch -q -C "$PR_BRANCH"
git add -- "${ARB_DIR}" ${shipped[@]+"${shipped[@]}"}
staged="$(git diff --cached --name-only)"
expected="$(
  for name in "${changed[@]}"; do echo "${ARB_DIR}/${name}"; done
  for path in ${shipped[@]+"${shipped[@]}"}; do echo "$path"; done
)"
expected="$(LC_ALL=C sort <<<"$expected")"
if [[ "$(LC_ALL=C sort <<<"$staged")" != "$expected" ]]; then
  fail "the commit would hold other files than ${changed[*]} ${shipped[*]-}"
fi
git -c commit.gpgsign=false commit -q -m "$COMMIT_MESSAGE"

# Pushed unless the branch holds exactly this commit's files on the same main,
# so whatever else anyone pushed there is replaced.
remote_head="$(remote_git ls-remote origin "refs/heads/${PR_BRANCH}" | cut -f1)"
push=1
if [[ -n "$remote_head" ]]; then
  remote_git fetch -q --no-tags --depth=2 origin "+refs/heads/${PR_BRANCH}:refs/remotes/origin/${PR_BRANCH}"
  remote_base="$(git rev-parse -q --verify "refs/remotes/origin/${PR_BRANCH}^" || true)"
  if [[ "$remote_base" == "$(git rev-parse HEAD^)" ]] && git diff --quiet "refs/remotes/origin/${PR_BRANCH}" HEAD; then
    push=0
    echo "The branch ${PR_BRANCH} holds these translations on this main already: not pushed."
  fi
fi
if ((push)); then
  remote_git push -q --force-with-lease="refs/heads/${PR_BRANCH}:${remote_head}" origin "HEAD:refs/heads/${PR_BRANCH}"
  echo "Pushed ${changed[*]} to the branch ${PR_BRANCH}."
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
pr_body >"${work}/body.md"
open_pr="$(GH_TOKEN="$github_token" gh pr list --repo "$GITHUB_REPOSITORY" --head "$PR_BRANCH" --base main \
  --state open --json number,isCrossRepository --jq 'map(select(.isCrossRepository | not)) | .[0].number // ""')"
if [[ -n "$open_pr" ]]; then
  [[ "$open_pr" =~ ^[1-9][0-9]*$ ]] || fail "gh pr list gave no pull request number"
  url="${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY}/pull/${open_pr}"
  # Its text names the files this export left out, which may differ from the
  # last run's.
  GH_TOKEN="$github_token" gh api --silent --method PATCH "repos/${GITHUB_REPOSITORY}/pulls/${open_pr}" \
    -F "body=@${work}/body.md"
  echo "The pull request ${url} is open: it shows the branch, and its text is updated."
  summary "Pull request: ${url}"
  exit 0
fi
if ! url="$(GH_TOKEN="$github_token" gh pr create --repo "$GITHUB_REPOSITORY" --base main --head "$PR_BRANCH" \
  --title "$COMMIT_MESSAGE" --body-file "${work}/body.md" 2>"${work}/gh.err")"; then
  echo "error: gh pr create failed:" >&2
  sed 's/^/  /' "${work}/gh.err" >&2
  fail "the workflow's token may open pull requests only with \"Allow GitHub Actions to create and approve" \
    "pull requests\" on in the repository (Settings > Actions > General); if it is greyed out there, an" \
    "organisation owner allows it first in the organisation's Settings > Actions > General (docs/releasing.md)"
fi
echo "Opened the pull request ${url}"
summary "Opened the pull request ${url}"

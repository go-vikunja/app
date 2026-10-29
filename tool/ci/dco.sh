#!/usr/bin/env bash
# The GitLab job `dco` on merge requests (D73): every commit in BASE..HEAD
# signed off by its author. The check that judges them is the target branch's
# current copy (BASE's when run locally), so a merge request can neither
# change it nor pick an older one by branching from an older commit.
#
# Usage: tool/ci/dco.sh BASE HEAD
set -euo pipefail
# shellcheck source=tool/ci/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

if (($# != 2)) || [[ -z "$1" || -z "$2" ]]; then
  echo "usage: tool/ci/dco.sh BASE HEAD" >&2
  exit 2
fi
base="$1"
head="$2"

python3 -I "${repo_root}/tool/check_dco.py" --self-test

# GitLab names the target branch's tip only in merged results pipelines.
if [[ -n "${CI_MERGE_REQUEST_TARGET_BRANCH_SHA:-}" ]]; then
  judge="$CI_MERGE_REQUEST_TARGET_BRANCH_SHA"
elif [[ -n "${CI_MERGE_REQUEST_TARGET_BRANCH_NAME:-}" ]]; then
  # Without --depth: a shallow tip would cut the history that BASE..HEAD walks.
  git -C "$repo_root" fetch --quiet --no-tags origin "refs/heads/${CI_MERGE_REQUEST_TARGET_BRANCH_NAME}"
  judge="$(git -C "$repo_root" rev-parse FETCH_HEAD)"
else
  judge="$base"
fi
echo "Judged by tool/check_dco.py at ${judge}."

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
git -C "$repo_root" show "${judge}:tool/check_dco.py" >"${tmp}/check_dco.py"
python3 -I "${tmp}/check_dco.py" --repository "$repo_root" "$base" "$head"

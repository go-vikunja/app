#!/usr/bin/env bash
# The static checks of the CI job `checks` (D73 on GitLab, D86 on GitHub
# Actions); runs the same locally.
set -euo pipefail
# shellcheck source=tool/ci/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$repo_root"

# Compared with the state before the generators run, so that uncommitted
# local edits do not fail it; in CI the tree starts clean.
app_lib_state() {
  git status --porcelain --untracked-files=all -- app/lib
  git diff --no-ext-diff -- app/lib | cksum
}
before="$(app_lib_state)"
setup_flutter --codegen
if [[ "$(app_lib_state)" != "$before" ]]; then
  git status --short -- app/lib
  echo "error: generated code is stale. Run: cd app && flutter gen-l10n && dart run build_runner build" >&2
  exit 1
fi

tool/check_format.sh
tool/check_pure_dart_packages.sh
python3 -I tool/build_android_notices.py --self-test
python3 -I tool/build_android_notices.py --check
python3 -I tool/ci/desugar_source.py --check-manifest
flutter analyze
python3 -I -m unittest discover -s tool/ci -p 'test_*.py'
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -x tool/ci/*.sh
else
  echo "shellcheck is not installed; skipped."
fi

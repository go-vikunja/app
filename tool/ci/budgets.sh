#!/usr/bin/env bash
# The time budgets of the tests (the 5,000-task lists, filters, timeline and
# Gantt), which a plain run only prints: before each release, on an idle
# machine, never on a shared runner (docs/releasing.md, Cutting a release).
set -euo pipefail
# shellcheck source=tool/ci/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

setup_flutter
failed=()
for package in app packages/vikunja_logic; do
  files=()
  while IFS= read -r file; do
    files+=("$file")
  done < <(cd "${repo_root}/${package}" && grep -rlF --include='*_test.dart' expectWithinBudget test | sort)
  if [[ ${#files[@]} -eq 0 ]]; then
    echo "error: no test of ${package} calls expectWithinBudget" >&2
    exit 1
  fi
  # One file at a time, so that no budget competes with another test.
  if ! (cd "${repo_root}/${package}" && VIKUNJA_BENCHMARK=1 flutter test --concurrency=1 "${files[@]}"); then
    failed+=("$package")
  fi
done
if [[ ${#failed[@]} -gt 0 ]]; then
  echo "error: a time budget was missed in ${failed[*]}; on an idle machine that is a regression to fix before the release" >&2
  exit 1
fi
echo "OK: every time budget held."

#!/usr/bin/env bash
# Lists outdated dependencies for information only: upgrades are a decision
# of their own, and advisories fail the job `osv`. Always exits 0.
set -euo pipefail
# shellcheck source=tool/ci/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$repo_root"

if ! use_installed_flutter; then
  echo "No Flutter SDK; outdated dependencies not listed."
  exit 0
fi
flutter pub outdated --no-dev-dependencies || true

#!/usr/bin/env bash
# The GitLab job `editor` (D73): audits the editor's npm packages, runs its
# tests and checks that the committed page is what its sources build.
set -euo pipefail
# shellcheck source=tool/ci/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

(cd "${repo_root}/app/editor" && npm audit --package-lock-only --audit-level=high)
"${repo_root}/tool/build_editor.sh" --check

#!/usr/bin/env bash
# The CI job `editor` (D86): audits the npm packages the page ships, runs the
# editor's tests and checks that the committed page is what its sources build.
# The dev dependencies are left to the job `osv`, which blocks on esbuild,
# which builds the page, but not on packages only the tests use.
set -euo pipefail
# shellcheck source=tool/ci/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

(cd "${repo_root}/app/editor" && npm audit --package-lock-only --omit=dev --audit-level=high)
"${repo_root}/tool/build_editor.sh" --check

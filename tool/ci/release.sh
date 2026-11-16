#!/usr/bin/env bash
# A release dry run on a developer's machine (D86); releases are published
# only by .github/workflows/release.yaml in go-vikunja/app.
#
# Usage: tool/ci/release.sh [--tag TAG] --dry-run
#
# Builds the unsigned release, signs it with throwaway keys and prints what
# would be published. The tag defaults to v<the pubspec's version name>.
set -euo pipefail
# shellcheck source=tool/ci/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=tool/ci/release_lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/release_lib.sh"
cd "$repo_root"

usage() {
  echo "usage: tool/ci/release.sh [--tag TAG] --dry-run" >&2
  exit 2
}

build_arguments=(--dry-run)
dry_run=0
while (($# > 0)); do
  case "$1" in
    --tag)
      (($# >= 2)) || usage
      build_arguments+=(--tag "$2")
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    *) usage ;;
  esac
done
if ((!dry_run)); then
  echo "error: releases are published only by .github/workflows/release.yaml in go-vikunja/app; pass --dry-run" >&2
  exit 2
fi

tool/ci/release_build.sh "${build_arguments[@]}"
tool/ci/release_sign.sh --dry-run
for step in check play dl github; do
  tool/ci/release_publish.sh --dry-run "$step"
done
echo "DRY RUN: NOT RELEASABLE ($(release_env_value "${release_signed_dir}/release.env" NOT_RELEASABLE))"

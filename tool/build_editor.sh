#!/usr/bin/env bash
# Builds the description editor page from app/editor into app/assets/editor
# (editor.html and NOTICES.md, both committed, so Flutter builds need no
# Node): installs the locked npm packages, runs the editor's tests, builds.
#
#   tool/build_editor.sh          rebuild the committed files
#   tool/build_editor.sh --check  fail when they differ from a fresh build
#
# Needs Node (app/editor/.nvmrc) and npm. Must run on macOS's bash 3.2.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../app/editor"

mode=build
case "${1:-}" in
  "") ;;
  --check) mode=check ;;
  *)
    echo "usage: tool/build_editor.sh [--check]" >&2
    exit 2
    ;;
esac

# Install scripts are not needed: esbuild ships its binary as a platform
# package.
npm ci --ignore-scripts --no-audit --no-fund
npm test

if [[ "$mode" == check ]]; then
  node build.mjs --check
else
  node build.mjs
fi

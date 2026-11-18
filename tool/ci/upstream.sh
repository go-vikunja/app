#!/usr/bin/env bash
# The weekly workflow "Upstream versions": fails when Flutter's stable release
# or Google Maven's cronet-bundled is newer than the pins (threat model R26,
# R34), so that neither ages unnoticed between releases.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
python3 -I tool/ci/upstream_versions.py

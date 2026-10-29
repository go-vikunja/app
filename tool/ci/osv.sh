#!/usr/bin/env bash
# The GitLab job `osv` (D73): OSV advisories for the three lockfiles, with
# the accepted ones in osv-scanner.toml. Uses osv-scanner from PATH, else
# downloads the pinned release and checks its sha256.
set -euo pipefail
# shellcheck source=tool/ci/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$repo_root"

if command -v osv-scanner >/dev/null 2>&1; then
  scanner=osv-scanner
  version="$(osv-scanner --version 2>/dev/null | sed -n 's/^osv-scanner version: *//p' || true)"
  if [[ "$version" != "$OSV_SCANNER_VERSION" ]]; then
    echo "warning: osv-scanner ${version:-of unknown version} on PATH, tool/ci/pins.sh pins ${OSV_SCANNER_VERSION}" >&2
  fi
else
  case "$(uname -s)/$(uname -m)" in
    Linux/x86_64) platform=linux_amd64 expected="$OSV_SCANNER_LINUX_AMD64_SHA256" ;;
    Darwin/arm64) platform=darwin_arm64 expected="$OSV_SCANNER_DARWIN_ARM64_SHA256" ;;
    *)
      echo "error: no pinned osv-scanner for $(uname -s)/$(uname -m); install osv-scanner ${OSV_SCANNER_VERSION}" >&2
      exit 2
      ;;
  esac
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  scanner="${tmp}/osv-scanner"
  curl --fail --silent --show-error --location --retry 3 --output "$scanner" \
    "https://github.com/google/osv-scanner/releases/download/v${OSV_SCANNER_VERSION}/osv-scanner_${platform}"
  verify_sha256 "$scanner" "$expected"
  chmod +x "$scanner"
fi

"$scanner" scan source --config=osv-scanner.toml \
  --lockfile=pubspec.lock \
  --lockfile=app/editor/package-lock.json \
  --lockfile=app/android/app/gradle.lockfile

#!/usr/bin/env bash
# The CI job `osv`: OSV advisories for the three lockfiles, with the accepted
# ones in osv-scanner.toml (decision log: Releases). Uses osv-scanner from PATH,
# else downloads the pinned release and checks its sha256. Packages that only
# the editor's tests use (tool/ci/editor_test_packages.py) are scanned too, but
# their advisories do not fail the job, so they never block a release.
set -euo pipefail
# shellcheck source=tool/ci/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$repo_root"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
python3 -I tool/ci/editor_test_packages.py app/editor/package-lock.json "${tmp}/editor"

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
  scanner="${tmp}/osv-scanner"
  curl --fail --silent --show-error --location --retry 3 --output "$scanner" \
    "https://github.com/google/osv-scanner/releases/download/v${OSV_SCANNER_VERSION}/osv-scanner_${platform}"
  verify_sha256 "$scanner" "$expected"
  chmod +x "$scanner"
fi

"$scanner" scan source --config=osv-scanner.toml \
  --lockfile=pubspec.lock \
  --lockfile="${tmp}/editor/build/package-lock.json" \
  --lockfile=app/android/app/gradle.lockfile

status=0
"$scanner" scan source --config=osv-scanner.toml --lockfile="${tmp}/editor/tests/package-lock.json" || status=$?
if ((status == 1)); then
  echo "warning: the advisories above concern packages that only the editor's tests use: update them, but they do not block a release" >&2
elif ((status != 0)); then
  exit "$status"
fi

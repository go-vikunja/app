# shellcheck shell=bash
# The versions and checksums the CI scripts download (D73). Sourced by
# lib.sh; values only. GitHub's hosted runner images cannot be pinned (D86).
# shellcheck disable=SC2034

# Raising FLUTTER_VERSION means updating both Flutter checksums.
# https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz
# (about 1.58 GB), sha256 from releases_linux.json.
# 3.47.7 (D73's earlier pin): af7455f540df951184c7953fbe3cf884766e7541dacf8571f9f582db03dd6230
FLUTTER_VERSION=3.47.9
FLUTTER_LINUX_SHA256=25ed8c3c29d51a7353f2a944310b478af8214920639524b19c50a19e6c044c5a

# https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_${FLUTTER_VERSION}-stable.zip
# (GitHub's macOS runners), sha256 from Homebrew's cask flutter.rb at commit
# b9492a17fde07906b5df85b59274731cafef6fd1, computed by BrewTestBot from the
# download: releases_macos.json could not be read when it was pinned.
FLUTTER_MACOS_ARM64_SHA256=6545b85938745dc5070e9faf2adf70233c1811009d87fe6d27bfcda5a04b7698

# https://github.com/google/osv-scanner/releases/download/v${OSV_SCANNER_VERSION}/osv-scanner_<os>_<arch>
OSV_SCANNER_VERSION=2.7.0
OSV_SCANNER_LINUX_AMD64_SHA256=160c6253e2922e9e0a6a9771c5c4c40a4b3c6090b34a3cdd5e80c96cc2e4218b
OSV_SCANNER_DARWIN_ARM64_SHA256=d4926ef8da134332543be276dff157e4c170f99ad91fc48e89448a8816bdf70b

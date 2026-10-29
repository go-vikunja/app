# shellcheck shell=bash
# The versions and checksums the CI scripts download (D73). Sourced by
# lib.sh; values only. The images are pinned by digest in .gitlab-ci.yml.
# shellcheck disable=SC2034

# https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz
# (about 1.58 GB), sha256 from releases_linux.json.
# 3.47.5 (D1's earlier pin): 2132e990f236f8d22e7c6314b29a191a95b10d7cbcfec9b4e2e303d996652cbb
FLUTTER_VERSION=3.47.7
FLUTTER_LINUX_SHA256=af7455f540df951184c7953fbe3cf884766e7541dacf8571f9f582db03dd6230

# https://github.com/google/osv-scanner/releases/download/v${OSV_SCANNER_VERSION}/osv-scanner_<os>_<arch>
OSV_SCANNER_VERSION=2.7.0
OSV_SCANNER_LINUX_AMD64_SHA256=160c6253e2922e9e0a6a9771c5c4c40a4b3c6090b34a3cdd5e80c96cc2e4218b
OSV_SCANNER_DARWIN_ARM64_SHA256=d4926ef8da134332543be276dff157e4c170f99ad91fc48e89448a8816bdf70b

# https://download.docker.com/linux/static/stable/x86_64/docker-${DOCKER_CLI_VERSION}.tgz
# Docker publishes no checksum for the static archives; this one was computed
# from the download on 2026-10-29.
DOCKER_CLI_VERSION=29.9.2
DOCKER_CLI_LINUX_AMD64_SHA256=9ac225999fd5e863f7694c728ef23d480616b1e5639328fa309befd4243d69eb

# https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-x86_64
COMPOSE_VERSION=5.6.1
COMPOSE_LINUX_AMD64_SHA256=47737f4236e6d3ccea7291995203f8f018058783b4c3a9469119811a0b5db8c0

# shellcheck shell=bash
# Shared by the tool/ci scripts (D73), which source it after `set -euo pipefail`.
# Runs on GitLab's Linux runners and on macOS's bash 3.2 alike.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tool/ci/pins.sh
source "${repo_root}/tool/ci/pins.sh"

on_gitlab_linux() {
  [[ "${GITLAB_CI:-}" == true && "$(uname -s)" == Linux ]]
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# file, expected sha256
verify_sha256() {
  local actual
  actual="$(sha256_of "$1")"
  if [[ "$actual" != "$2" ]]; then
    echo "error: $(basename "$1") has sha256 ${actual}, expected $2" >&2
    return 1
  fi
}

flutter_sdk_dir() {
  echo "${repo_root}/.cache/flutter/${FLUTTER_VERSION}/flutter"
}

install_flutter() {
  local sdk tmp
  sdk="$(flutter_sdk_dir)"
  if [[ -x "${sdk}/bin/flutter" ]]; then
    return
  fi
  tmp="$(mktemp -d)"
  echo "Downloading Flutter ${FLUTTER_VERSION}"
  curl --fail --silent --show-error --location --retry 3 --output "${tmp}/flutter.tar.xz" \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  verify_sha256 "${tmp}/flutter.tar.xz" "$FLUTTER_LINUX_SHA256"
  rm -rf "$(dirname "$sdk")"
  mkdir -p "$(dirname "$sdk")"
  tar -xJf "${tmp}/flutter.tar.xz" --no-same-owner -C "$(dirname "$sdk")"
  rm -rf "$tmp"
}

# Puts Flutter on PATH: the pinned SDK on GitLab's Linux runners, else the
# one already on PATH. Never downloads when --no-install is given.
use_flutter() {
  local sdk version
  if on_gitlab_linux; then
    sdk="$(flutter_sdk_dir)"
    if [[ "${1:-}" != --no-install ]]; then
      install_flutter
    elif [[ ! -x "${sdk}/bin/flutter" ]]; then
      return 1
    fi
    git config --global --add safe.directory "$sdk"
    export PATH="${sdk}/bin:${sdk}/bin/cache/dart-sdk/bin:${PATH}"
    flutter config --no-analytics >/dev/null
    dart --disable-analytics >/dev/null
  elif ! command -v flutter >/dev/null 2>&1; then
    echo "error: flutter is not on PATH" >&2
    return 1
  fi
  version="$(flutter --version --machine 2>/dev/null | sed -n 's/.*"frameworkVersion": *"\([^"]*\)".*/\1/p' || true)"
  if [[ "$version" != "$FLUTTER_VERSION" ]]; then
    if [[ "${CI:-}" == true ]]; then
      echo "error: Flutter ${version:-of unknown version} found, tool/ci/pins.sh pins ${FLUTTER_VERSION}" >&2
      return 1
    fi
    echo "warning: Flutter ${version:-of unknown version} found, tool/ci/pins.sh pins ${FLUTTER_VERSION}" >&2
  fi
}

# setup_flutter [--codegen]: Flutter on PATH, the pub workspace resolved from
# the lockfile and, with --codegen, the app's generated code written again.
setup_flutter() {
  use_flutter
  (cd "$repo_root" && flutter pub get --enforce-lockfile)
  if [[ "${1:-}" == --codegen ]]; then
    (
      cd "${repo_root}/app"
      if [[ -f l10n.yaml ]]; then
        flutter gen-l10n
      fi
      if grep -rqE "^part '[^']+\.g\.dart';" lib; then
        dart run build_runner build
      fi
    )
  fi
}

# flutter test runs half the CPUs by default, which is a single test process
# on a 2-vCPU runner; the runner does nothing else, a developer's machine does.
flutter_test_concurrency() {
  local cpus
  cpus="$(getconf _NPROCESSORS_ONLN)"
  if on_gitlab_linux; then
    echo "$cpus"
  else
    echo $((cpus > 1 ? cpus / 2 : 1))
  fi
}

# The project's gradle.properties asks for 8 GB, more than a small runner has.
# Only on GitLab: never touches ~/.gradle on a developer's machine.
ci_gradle_memory() {
  if ! on_gitlab_linux; then
    return
  fi
  local home="${GRADLE_USER_HOME:-${HOME}/.gradle}"
  mkdir -p "$home"
  cat >"${home}/gradle.properties" <<'PROPERTIES'
org.gradle.jvmargs=-Xmx3g -XX:MaxMetaspaceSize=1g -XX:+HeapDumpOnOutOfMemoryError
kotlin.daemon.jvmargs=-Xmx1g
org.gradle.workers.max=2
PROPERTIES
}

# Fails unless xcode-select points into an Xcode app, then prints its version.
# The native-asset build hooks ignore DEVELOPER_DIR (README), so the selection
# itself has to be Xcode; DEVELOPER_DIR is unset so nothing else uses another.
use_selected_xcode() {
  local selected
  selected="$(env -u DEVELOPER_DIR xcode-select -p 2>/dev/null || true)"
  if [[ "$selected" != *.app/Contents/Developer ]]; then
    echo "error: xcode-select points to ${selected:-nothing}, not to Xcode:" \
      "sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer" >&2
    return 1
  fi
  unset DEVELOPER_DIR
  printf '%s at %s\n' "$(xcodebuild -version | tr '\n' ' ' | sed 's/ *$//')" "$selected"
}

android_sdk_dir() {
  if [[ -n "${ANDROID_HOME:-}" ]]; then
    echo "$ANDROID_HOME"
  elif [[ -n "${ANDROID_SDK_ROOT:-}" ]]; then
    echo "$ANDROID_SDK_ROOT"
  elif [[ -f "${repo_root}/app/android/local.properties" ]]; then
    sed -n 's/^sdk\.dir=//p' "${repo_root}/app/android/local.properties"
  fi
}

# build_tool apksigner|aapt2: the newest build-tools' copy.
build_tool() {
  local sdk found
  sdk="$(android_sdk_dir)"
  found="$(find "${sdk}/build-tools" -mindepth 2 -maxdepth 2 -name "$1" -type f 2>/dev/null | sort -V | tail -n 1 || true)"
  if [[ -z "$found" ]]; then
    echo "error: no $1 in ${sdk:-<no Android SDK>}/build-tools" >&2
    return 1
  fi
  echo "$found"
}

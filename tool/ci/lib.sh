# shellcheck shell=bash
# Shared by the tool/ci scripts (D73, D86), which source it after `set -euo pipefail`.
# Runs on GitLab's Linux runners, GitHub-hosted runners and macOS's bash 3.2 alike.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=tool/ci/pins.sh
source "${repo_root}/tool/ci/pins.sh"

# A disposable CI machine: GitLab's Linux runners or a GitHub-hosted runner,
# never a developer's machine or a self-hosted runner, whose SDKs and
# ~/.gradle stay untouched.
on_ci_runner() {
  [[ ("${GITLAB_CI:-}" == true && "$(uname -s)" == Linux) ||
    ("${GITHUB_ACTIONS:-}" == true && "${RUNNER_ENVIRONMENT:-}" == github-hosted) ]]
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
  local sdk url expected archive tmp
  sdk="$(flutter_sdk_dir)"
  if [[ -x "${sdk}/bin/flutter" ]]; then
    return
  fi
  case "$(uname -s)/$(uname -m)" in
    Linux/x86_64)
      url="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
      expected="$FLUTTER_LINUX_SHA256"
      archive=flutter.tar.xz
      ;;
    Darwin/arm64)
      url="https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/flutter_macos_arm64_${FLUTTER_VERSION}-stable.zip"
      expected="$FLUTTER_MACOS_ARM64_SHA256"
      archive=flutter.zip
      ;;
    *)
      echo "error: no pinned Flutter archive for $(uname -s)/$(uname -m)" >&2
      return 1
      ;;
  esac
  tmp="$(mktemp -d)"
  echo "Downloading Flutter ${FLUTTER_VERSION}"
  curl --fail --silent --show-error --location --retry 3 --output "${tmp}/${archive}" "$url"
  verify_sha256 "${tmp}/${archive}" "$expected"
  rm -rf "$(dirname "$sdk")"
  mkdir -p "$(dirname "$sdk")"
  if [[ "$archive" == flutter.zip ]]; then
    unzip -q -d "$(dirname "$sdk")" "${tmp}/${archive}"
  else
    tar -xJf "${tmp}/${archive}" --no-same-owner -C "$(dirname "$sdk")"
  fi
  rm -rf "$tmp"
}

# Puts Flutter on PATH: the pinned SDK on a CI runner, else the one already
# on PATH. use_installed_flutter never downloads.
use_flutter() {
  put_flutter_on_path install
}

use_installed_flutter() {
  put_flutter_on_path no-install
}

put_flutter_on_path() {
  local sdk version
  if on_ci_runner; then
    sdk="$(flutter_sdk_dir)"
    if [[ "$1" == install ]]; then
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

# Flutter on PATH and the pub workspace resolved from the lockfile.
setup_flutter() {
  use_flutter
  (cd "$repo_root" && flutter pub get --enforce-lockfile)
}

# setup_flutter, then the app's generated code written again.
setup_flutter_with_codegen() {
  setup_flutter
  (
    cd "${repo_root}/app" || exit
    if [[ -f l10n.yaml ]]; then
      flutter gen-l10n
    fi
    if grep -rqE "^part '[^']+\.g\.dart';" lib; then
      dart run build_runner build
    fi
  )
}

# flutter test runs half the CPUs by default, which is a single test process
# on a 2-vCPU runner; the runner does nothing else, a developer's machine does.
flutter_test_concurrency() {
  local cpus
  cpus="$(getconf _NPROCESSORS_ONLN)"
  if on_ci_runner; then
    echo "$cpus"
  else
    echo $((cpus > 1 ? cpus / 2 : 1))
  fi
}

# The project's gradle.properties asks for 8 GB, more than a small runner has,
# and GitHub's Ubuntu image defaults to JDK 17 where GitLab's image and the
# owner's machine use 21. Only on a CI runner: never touches a developer's
# ~/.gradle or JDK.
ci_gradle_setup() {
  if ! on_ci_runner; then
    return
  fi
  if [[ -n "${JAVA_HOME_21_X64:-}" ]]; then
    export JAVA_HOME="$JAVA_HOME_21_X64"
    export PATH="${JAVA_HOME}/bin:${PATH}"
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

# build_tool apksigner|aapt2|zipalign: the newest build-tools' copy.
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

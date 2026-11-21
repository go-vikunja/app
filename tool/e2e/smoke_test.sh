#!/usr/bin/env bash
# A smoke test of a fresh install on a running emulator: installs the APK
# with its data wiped, checks that it opens on Connect without the previous
# app's note or server and with the previous app's widget provider disabled,
# waits while you sign in through the browser, then checks the first sync and
# that the app is still signed in after a new start. A build with a crash
# reports DSN asks about them after the first sync; the test declines. Prints PASS, FAIL or
# SKIP per check and exits 1 when one failed, 2 when the test could not run;
# the output folder gets the log, the screen dumps and the screenshots.
#
# Usage: tool/e2e/smoke_test.sh [--server URL] [--task TITLE]... <emulator serial> <new.apk> <output folder>
#
# --server  where you sign in (default http://localhost:34527, the Docker
#           test server; a localhost port gets `adb reverse`)
# --task    a task title the first sync must show (repeatable). Default on
#           the local test server: an open task of tool/seed_demo_data.py.
#
# Only on the AVDs Vikunja_Screens and Vikunja_Tablet; never starts or stops
# an emulator. You do the sign-in; nothing prints a password or token. Must
# run on macOS's bash 3.2.
set -euo pipefail
# shellcheck source=tool/e2e/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

usage() {
  sed -n 's/^# Usage: /usage: /p' "${BASH_SOURCE[0]}" >&2
  exit 2
}

server="$default_server"
titles=()
while (($# > 0)); do
  case "$1" in
    --server)
      (($# >= 2)) || usage
      server="$2"
      shift 2
      ;;
    --task)
      (($# >= 2)) || usage
      titles+=("$2")
      shift 2
      ;;
    -*) usage ;;
    *) break ;;
  esac
done
(($# == 3)) || usage
serial="$1" apk="$2" out="$3"
open_output

address_empty() {
  local values
  values="$(ui fields "${out}/$1.xml")" && ! grep -F -e '://' -e "$host_port" <<<"$values" >/dev/null
}

section "Preflight"
check_emulator
check_apk new "$apk"
prepare_server
load_synced

section "A fresh install"
confirm_wipe
reinstall "$apk"
clear_logcat
start_app
expect_screen "the app opens on Connect" 60 fresh connectTagline
expect_absent "no note of the previous app" fresh previousAppNoteTitle
check "the server address is empty" address_empty fresh
check "the previous app's widget provider is disabled" component_disabled "$old_widget_provider"

section "Signing in"
cleartext=""
if [[ "$server" == http://* ]]; then cleartext=", allow the unencrypted connection"; fi
owner \
  "Enter ${server}, tap Continue${cleartext} and $(sign_in_hint)." \
  "Come back here once the app is back from the browser."
expect_shell "the first sync shows the tasks" 180 synced "${synced[@]}"

section "A new start"
expect_signed_in_after_restart restarted
expect_no_crash "$apk_debug"
summary

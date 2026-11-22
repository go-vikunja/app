# shellcheck shell=bash
# Shared by tool/e2e/update_test.sh and smoke_test.sh, which source it after
# `set -euo pipefail` and set serial, out, server and titles before calling
# into it. Must run on macOS's bash 3.2.

e2e_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tool/ci/lib.sh
source "${e2e_dir}/../ci/lib.sh"

package=io.vikunja.app
activity="${package}/.MainActivity"
old_widget_provider="${package}.widget.AppWidgetReciever"
default_server=http://localhost:34527
remote_dump=/data/local/tmp/vikunja-e2e-ui.xml
remote_recording=/data/local/tmp/vikunja-e2e.mp4
# The message keys the scripts look for on the screen.
screen_keys="previousAppNoteTitle previousAppNoteSignInAgain previousAppNoteSignIn previousAppNoteSignedIn
previousAppNoteWidgets previousAppNoteWidgetsAfterSignIn previousAppSigningIn connectTagline tabOverview
crashReportsQuestionTitle crashReportsQuestionDecline"
passed=0
failed=0
skipped=0
recording_pid=""
recording_file=""
browser_seen=""
avd=""
adb_transport=""

die() {
  echo "error: $*" >&2
  exit 2
}

ui() {
  python3 -I "${e2e_dir}/ui.py" "$@"
}

pass() {
  echo "PASS  $*"
  passed=$((passed + 1))
}

fail() {
  echo "FAIL  $*"
  failed=$((failed + 1))
}

skip() {
  echo "SKIP  $*"
  skipped=$((skipped + 1))
}

note() {
  echo "      $*"
}

section() {
  echo
  echo "== $*"
}

# check <description> <command...>
check() {
  local description="$1"
  shift
  if "$@"; then pass "$description"; else fail "$description"; fi
}

summary() {
  stop_recording
  echo
  echo "${passed} passed, ${failed} failed, ${skipped} skipped. Screens and logs: ${out}"
  ((failed == 0))
}

# Every call goes to the adb connection check_emulator checked: an emulator
# started later on the same port gets the same serial, but another transport.
adb_() {
  adb -t "$adb_transport" "$@"
}

shell_() {
  adb_ shell "$@" | tr -d '\r'
}

transport_of() {
  adb devices -l 2>/dev/null | tr -d '\r' |
    awk -v serial="$1" '$1 == serial && $2 == "device" { for (i = 3; i <= NF; i++) if (sub(/^transport_id:/, "", $i)) print $i }' || true
}

# `emu` needs the serial, as it talks to the emulator's console port.
avd_of() {
  adb -s "$1" emu avd name 2>/dev/null | tr -d '\r' | sed -n 1p || true
}

# Refuses anything but a connected emulator running one of the project's own
# AVDs, whose app data the tests may wipe.
# shellcheck disable=SC2154 # serial comes from the sourcing script.
check_emulator() {
  unset ANDROID_SERIAL
  if ! command -v adb >/dev/null 2>&1; then
    local sdk
    sdk="$(android_sdk_dir)"
    [[ -n "$sdk" && -x "${sdk}/platform-tools/adb" ]] || die "adb is not on the PATH"
    PATH="${sdk}/platform-tools:${PATH}"
  fi
  [[ "$serial" =~ ^emulator-[0-9]+$ ]] || die "refusing $serial: only an emulator (emulator-<port>), never a physical device"
  adb_transport="$(transport_of "$serial")"
  [[ "$adb_transport" =~ ^[0-9]+$ ]] || die "$serial is not connected (adb devices -l lists no transport_id for it)"
  avd="$(avd_of "$serial")"
  case "$avd" in
    Vikunja_Screens | Vikunja_Tablet) ;;
    *) die "refusing $serial: it runs the AVD '${avd:-unknown}', not Vikunja_Screens or Vikunja_Tablet" ;;
  esac
  guard_device
  api_level="$(shell_ getprop ro.build.version.sdk)" || die "cannot read the Android version of $serial"
  [[ "$api_level" =~ ^[0-9]+$ ]] || die "$serial reports the Android API level '${api_level}'"
  echo "$serial: AVD ${avd}, Android API ${api_level}, adb transport ${adb_transport}"
}

# Before each step that changes or reads the device after a wait: the serial
# still runs the checked AVD on the checked connection. Else it stops without
# another adb call, the recording's included.
guard_device() {
  local before name after
  before="$(transport_of "$serial")"
  name="$(avd_of "$serial")"
  after="$(transport_of "$serial")"
  if [[ -n "$adb_transport" && "$before" == "$adb_transport" && "$after" == "$adb_transport" && "$name" == "$avd" ]]; then
    return 0
  fi
  if [[ -n "$recording_pid" ]]; then
    kill "$recording_pid" 2>/dev/null || true
    recording_pid=""
  fi
  die "$serial is no longer the checked ${avd} on adb transport ${adb_transport} (now: transport ${before:-none}, AVD '${name:-unknown}'); nothing more was sent to it. If adb restarted, run the test again"
}

# check_apk <label> <apk>: sets apk_code, apk_cert and apk_debug, 1 for a
# debug build, whose Dart errors reach logcat.
# shellcheck disable=SC2034 # the sourcing script reads apk_debug.
check_apk() {
  [[ -f "$2" ]] || die "no file $2"
  local aapt2 apksigner badging certs name version kind=release
  aapt2="$(build_tool aapt2)" || exit 2
  apksigner="$(build_tool apksigner)" || exit 2
  badging="$("$aapt2" dump badging "$2" 2>&1)" || die "aapt2 cannot read $2: $(tail -n 3 <<<"$badging")"
  name="$(apk_field "$badging" name)"
  [[ "$name" == "$package" ]] || die "$2 is ${name:-not an APK}, not ${package}"
  apk_code="$(apk_field "$badging" versionCode)"
  [[ "$apk_code" =~ ^[0-9]+$ ]] || die "$2 has no numeric version code"
  version="$(apk_field "$badging" versionName)"
  certs="$("$apksigner" verify --print-certs "$2" 2>&1)" || die "apksigner does not verify $2: $(tail -n 3 <<<"$certs")"
  apk_cert="$(sed -E -n 's/^(Signer #1|V[0-9.]+ Signer:) certificate SHA-256 digest: //p' <<<"$certs" | sort -u)"
  [[ -n "$apk_cert" && "$apk_cert" != *$'\n'* ]] || die "$2 is not signed by exactly one certificate"
  apk_debug=0
  if python3 -I -c 'import sys, zipfile; sys.exit("assets/flutter_assets/kernel_blob.bin" not in zipfile.ZipFile(sys.argv[1]).namelist())' "$2" 2>/dev/null; then
    apk_debug=1 kind=debug
  fi
  echo "$1 APK: ${version} (${apk_code}), ${kind} build, certificate SHA-256 ${apk_cert}"
}

# apk_field <badging> name|versionCode|versionName
apk_field() {
  sed -n "s/^package:.* $2='\([^']*\)'.*/\1/p" <<<"$1"
}

# Checks the server, sets host_port and points the emulator's localhost port
# to the Mac.
prepare_server() {
  server="${server%/}"
  case "$server" in
    http://?* | https://?*) ;;
    *) die "--server takes an http:// or https:// URL, not $server" ;;
  esac
  host_port="${server#*://}"
  host_port="${host_port%%/*}"
  local host="${host_port%%:*}" port info
  if [[ "$host_port" == *:* ]]; then
    port="${host_port##*:}"
  elif [[ "$server" == https://* ]]; then
    port=443
  else
    port=80
  fi
  if info="$(curl --silent --show-error --fail --max-time 10 "${server}/api/v1/info")"; then
    echo "$server: Vikunja $(python3 -I -c 'import json, sys; print(json.load(sys.stdin).get("version", "?"))' <<<"$info")"
  elif [[ "$server" == http://* ]]; then
    die "$server does not answer: docker compose -f test_servers/docker-compose.yaml up -d, then tool/seed_e2e_user.sh"
  else
    echo "warning: $server does not answer from this Mac (its CA?); going on" >&2
  fi
  if [[ "$host" == localhost || "$host" == 127.0.0.1 ]]; then
    adb_ reverse "tcp:${port}" "tcp:${port}" >/dev/null || die "adb reverse tcp:${port} failed"
    echo "$serial: adb reverse tcp:${port} tcp:${port}"
  fi
}

e2e_username() {
  sed -n 's/^E2E_USERNAME=//p' "${repo_root}/test_servers/seed/e2e-user.env" | sed -n 1p
}

# Sets synced, what the first sync must show: one of the --task titles, else
# on the local test server one of the demo data's open tasks, else the shell.
load_synced() {
  local title
  # shellcheck disable=SC2086
  ui keys $screen_keys || die "the app's texts changed: update screen_keys in tool/e2e/lib.sh"
  if ((${#titles[@]} == 0)) && [[ "$server" == "$default_server" ]]; then
    while IFS= read -r title; do
      titles+=("$title")
    done < <(ui demo-titles)
    note "the first sync must show a task of tool/seed_demo_data.py: run tool/seed_e2e_user.sh with both env files and python3 -I tool/seed_demo_data.py first"
  fi
  synced=()
  if ((${#titles[@]} == 0)); then
    synced=(tabOverview)
    note "the first sync must show the app's tabs"
    return 0
  fi
  for title in "${titles[@]}"; do
    synced+=("=${title}")
  done
}

# Names the clipboard only: `adb shell input text` would put the password on
# a command line, and without -s on whichever device adb picks.
sign_in_hint() {
  if [[ "$server" == "$default_server" ]]; then
    printf '%s\n' "sign in as $(e2e_username), pasting the password from the Mac's clipboard: copy it with  sed -n 's/^E2E_PASSWORD=//p' $(printf '%q' "${repo_root}/test_servers/seed/e2e-user.env") | tr -d '\\n' | pbcopy  and empty the clipboard afterwards with  pbcopy </dev/null"
  else
    echo "sign in with a throwaway account of ${server}"
  fi
}

# owner <step>...: shows the owner's steps and waits for Enter.
owner() {
  local step reply
  echo
  echo ">>> Your turn on ${avd} (${serial}):"
  for step in "$@"; do
    echo "    - ${step}"
  done
  read -r -p "    Press Enter when done (Ctrl-C stops the test). " reply </dev/tty
  echo
  guard_device
}

# owner_confirms <description> <question>: a check the owner judges.
owner_confirms() {
  local reply
  read -r -p "??? $2 [y/n] " reply </dev/tty
  echo "${reply}"
  guard_device
  case "$reply" in
    y | Y | j | J) pass "$1 (seen by the owner)" ;;
    *) fail "$1 (not seen by the owner)" ;;
  esac
}

start_app() {
  adb_ shell am start -W -n "$activity" >/dev/null || die "cannot start ${activity} on ${serial}"
}

restart_app() {
  adb_ shell am force-stop "$package" || die "cannot stop ${package} on ${serial}"
  start_app
}

installed_version_code() {
  shell_ dumpsys package "$package" | sed -n 's/.*versionCode=\([0-9]*\).*/\1/p' | sed -n 1p
}

# reinstall <apk>: removes the app with its data, then installs the APK.
reinstall() {
  guard_device
  adb_ uninstall "$package" >/dev/null 2>&1 || true
  local output
  output="$(adb_ install "$1" 2>&1)" || die "adb install $1 failed: ${output}"
}

# dump_screen <name>: while recording, it stops the recording once a browser
# or a Connect screen that takes input shows, so that no sign-in is recorded.
dump_screen() {
  local file="${out}/$1.xml"
  if [[ -n "$recording_pid" ]] && browser_in_front; then
    stop_recording "a browser shows (${browser_seen})"
  fi
  for _ in 1 2 3; do
    adb_ shell rm -f "$remote_dump" >/dev/null 2>&1 || true
    if adb_ shell uiautomator dump "$remote_dump" >/dev/null 2>&1 &&
      adb_ exec-out cat "$remote_dump" >"$file" 2>/dev/null && grep -q '<hierarchy' "$file"; then
      if [[ -n "$recording_pid" ]] && connect_unlocked "$1"; then
        stop_recording "Connect takes input"
      fi
      return 0
    fi
    sleep 1
  done
  return 1
}

screenshot() {
  adb_ exec-out screencap -p >"${out}/$1.png" || note "no screenshot $1"
}

# shows <name> <find arguments...>: in the last dump of <name>.
shows() {
  local name="$1"
  shift
  ui find "${out}/${name}.xml" "$@"
}

# wait_until <seconds> <name> <command...>: dumps the screen as <name> until
# the command holds, then takes the screenshot <name>.png.
wait_until() {
  local seconds="$1" name="$2" held=1
  shift 2
  local deadline=$((SECONDS + seconds))
  while :; do
    if dump_screen "$name" && "$@"; then
      held=0
      break
    fi
    ((SECONDS < deadline)) || break
    sleep 2
  done
  screenshot "$name"
  return "$held"
}

# wait_for <seconds> <name> <find arguments...>: until the dump shows one of
# the texts.
wait_for() {
  local seconds="$1" name="$2"
  shift 2
  wait_until "$seconds" "$name" shows "$name" "$@"
}

# expect_screen <description> <seconds> <name> <find arguments...>: when the
# dump holds no text of the app at all, the owner judges the screenshot.
expect_screen() {
  local description="$1" seconds="$2" name="$3"
  shift 3
  if wait_for "$seconds" "$name" "$@"; then
    pass "$description"
  elif ui has-app-text "${out}/${name}.xml"; then
    fail "${description} (see ${name}.png)"
  else
    owner_confirms "$description" "The dump of ${name} has no text of the app. Does ${out}/${name}.png show it? (${description})"
  fi
}

# expect_absent <description> <name> <find arguments...>: in the last dump.
expect_absent() {
  local description="$1" name="$2"
  shift 2
  if shows "$name" "$@"; then
    fail "${description} (see ${name}.png)"
  elif ui has-app-text "${out}/${name}.xml"; then
    pass "$description"
  else
    owner_confirms "$description" "The dump of ${name} has no text of the app. Is that so in ${out}/${name}.png? (${description})"
  fi
}

# field_holds <name> <text>: a text field of the last dump contains the text.
field_holds() {
  ui fields "${out}/$1.xml" | grep -F -- "$2" >/dev/null
}

# field_enabled <name> <text>: such a field takes input.
field_enabled() {
  ui fields --enabled "${out}/$1.xml" | grep -F -- "$2" >/dev/null
}

# connect_unlocked <name>: the last dump shows Connect taking input, without
# the progress line of a session being kept.
connect_unlocked() {
  shows "$1" connectTagline && ! shows "$1" previousAppSigningIn &&
    ui fields --enabled "${out}/$1.xml" >/dev/null
}

# brightness <name>: the screenshot's mean brightness from 0 to 1.
brightness() {
  command -v magick >/dev/null 2>&1 &&
    magick "${out}/$1.png" -alpha off -colorspace Gray -format '%[fx:mean]' info: 2>/dev/null
}

# looks <dark|light> <mean brightness>
looks() {
  awk -v mean="$2" -v want="$1" 'BEGIN { exit !((want == "dark") ? (mean < 0.5) : (mean >= 0.5)) }'
}

# expect_theme <dark|light> <name>: by the screenshot's mean brightness.
expect_theme() {
  local mean
  if mean="$(brightness "$2")"; then
    if looks "$1" "$mean"; then
      pass "the theme is $1 on $2 (mean brightness ${mean})"
    else
      fail "the theme is $1 on $2 (mean brightness ${mean}, see $2.png)"
    fi
  else
    owner_confirms "the theme is $1 on $2" "Is the app $1 in ${out}/$2.png?"
  fi
}

focused_window() {
  shell_ dumpsys window | sed -n 's/^ *mCurrentFocus=//p' | sed -n 1p
}

# browser_in_front: sets browser_seen to the browser's window.
browser_in_front() {
  local focus
  focus="$(focused_window)"
  case "$focus" in
    *[Cc]hrome* | *[Bb]rowser* | *customtabs*)
      browser_seen="$focus"
      return 0
      ;;
  esac
  return 1
}

app_locales() {
  shell_ cmd locale get-app-locales "$package" 2>/dev/null || true
}

# The app's pending alarms for flutter_local_notifications' receiver.
reminder_alarm_count() {
  shell_ dumpsys alarm | awk -v pkg="$package" '
    /Alarm\{/ { mine = index($0, " " pkg "}") > 0; next }
    mine && /tag=/ { if (index($0, "ScheduledNotificationReceiver")) n++; mine = 0 }
    END { print n + 0 }'
}

# channel_line <id>: the app's channel unless deleted. Without --noredact
# dumpsys shortens the names; awk reads to the end, as an early exit would
# end the pipeline with SIGPIPE.
channel_line() {
  shell_ dumpsys notification --noredact | awk -v pkg="$package" -v id="NotificationChannel{mId='$1'," '
    /AppSettings: / { for (i = 1; i < NF; i++) if ($i == "AppSettings:") current = $(i + 1); next }
    !found && current == pkg && index($0, id) && $0 !~ /mDeleted=true/ { print; found = 1 }'
}

old_widget_count() {
  shell_ dumpsys appwidget | grep -E '^ *provider=ProviderId' |
    grep -cF "cmp:ComponentInfo{${package}/${old_widget_provider}}" || true
}

component_disabled() {
  shell_ dumpsys package "$package" | awk -v cls="$1" '
    /^ *disabledComponents:/ { inside = 1; next }
    inside && /:$/ { inside = 0 }
    inside && $1 == cls { found = 1 }
    END { exit !found }'
}

# WorkManager's diagnostics of the app, one row per work (state and unique
# name among the columns); empty when the app logged none.
work_rows() {
  local since
  since="$(shell_ date +%s).000"
  adb_ shell am broadcast -a androidx.work.diagnostics.REQUEST_DIAGNOSTICS -p "$package" >/dev/null 2>&1 || true
  sleep 5
  adb_ logcat -d -T "$since" -s 'WM-DiagnosticsWrkr:I' 2>/dev/null | tr -d '\r' | grep -v '^-' || true
}

# before <word> <list>: how a leftover looked before the update.
before() {
  case " $2 " in
    *" $1 "*) echo "there before the update" ;;
    *) echo "not there before the update" ;;
  esac
}

# expect_old_leftovers_gone <leftovers seen before the update>: the previous
# app's channels and its work update-tasks.
expect_old_leftovers_gone() {
  local id rows
  for id in Vikunja1 Vikunja2; do
    check "the previous app's channel ${id} is gone ($(before "$id" "$1"))" test -z "$(channel_line "$id")"
  done
  rows="$(work_rows)"
  printf '%s\n' "$rows" >"${out}/work.txt"
  if [[ -z "$rows" ]]; then
    skip "the work update-tasks is gone (WorkManager logged no diagnostics)"
  elif grep -F 'update-tasks' <<<"$rows" | grep -E 'ENQUEUED|RUNNING|BLOCKED' >/dev/null; then
    fail "the work update-tasks is gone (still scheduled: see work.txt)"
  else
    pass "the work update-tasks is gone ($(before update-tasks "$1"))"
  fi
}

# start_recording <file name>
start_recording() {
  guard_device
  recording_file="$1"
  adb_ shell rm -f "$remote_recording" >/dev/null 2>&1 || true
  adb_ shell screenrecord --time-limit 180 "$remote_recording" >/dev/null 2>&1 &
  recording_pid=$!
  echo ">>> Recording ${recording_file}. Do not touch the emulator until asked."
}

# stop_recording [why]
stop_recording() {
  [[ -n "$recording_pid" ]] || return 0
  adb_ shell pkill -INT screenrecord >/dev/null 2>&1 || true
  wait "$recording_pid" 2>/dev/null || true
  recording_pid=""
  if [[ -n "${1:-}" ]]; then note "the recording stops: $1"; fi
  sleep 2
  if adb_ pull "$remote_recording" "${out}/${recording_file}" >/dev/null 2>&1; then
    note "recording: ${out}/${recording_file}"
  fi
  adb_ shell rm -f "$remote_recording" >/dev/null 2>&1 || true
}

clear_logcat() {
  guard_device
  adb_ logcat -b all -c || die "cannot clear the log of ${serial}"
}

# expect_no_crash <apk_debug>: Java and native crashes and ANRs since
# clear_logcat, and the Dart errors, which the app's own handlers print to
# logcat only in a debug build ("SEVERE Uncaught:", "SEVERE Flutter:").
expect_no_crash() {
  adb_ logcat -d -b crash 2>/dev/null | tr -d '\r' >"${out}/crash.txt" || true
  if grep -qF -e "Process: ${package}," -e ">>> ${package} <<<" -e ">>> ${package}:" "${out}/crash.txt"; then
    fail "no crash of the app (see crash.txt)"
  else
    pass "no crash of the app"
  fi
  adb_ logcat -d -b main -b system -b crash 2>/dev/null | tr -d '\r' | grep -F "ANR in ${package}" >"${out}/anr.txt" || true
  if [[ -s "${out}/anr.txt" ]]; then
    fail "no ANR of the app (see anr.txt)"
  else
    pass "no ANR of the app"
  fi
  adb_ logcat -d -b main 2>/dev/null | tr -d '\r' |
    grep -E 'SEVERE (Uncaught|Flutter):|Unhandled Exception' >"${out}/dart-errors.txt" || true
  if [[ -s "${out}/dart-errors.txt" ]]; then
    fail "no uncaught Dart error (see dart-errors.txt)"
  elif (($1)); then
    pass "no uncaught Dart error"
  else
    owner_confirms "no uncaught Dart error" \
      "A release build logs its Dart errors only in its own log. On the Account tab tap the version line at the bottom, then $(ui string en supportDetailsTitle) ($(ui string de supportDetailsTitle)): does its log have no line with 'SEVERE Uncaught' or 'SEVERE Flutter'?"
  fi
}

# Starts the log in the output folder; the scripts print no secret.
open_output() {
  mkdir -p "$out"
  out="$(cd "$out" && pwd)"
  exec > >(tee -a "${out}/log.txt") 2>&1
  echo "$(basename "$0") $(date '+%Y-%m-%d %H:%M:%S'), repository at $(git -C "$repo_root" rev-parse --short HEAD 2>/dev/null || echo '?')"
}

confirm_wipe() {
  local reply
  echo
  read -r -p ">>> This uninstalls ${package} from ${avd} with all its data. Press Enter to go on (Ctrl-C stops). " reply </dev/tty
  echo
  guard_device
}

# A build with a crash reports DSN asks about them once, over the shell
# after the first sign-in, and its barrier hides the screen below from the
# dump. The scripts answer No thanks.

# asks_about_crash_reports <name>: in the last dump of <name>.
asks_about_crash_reports() {
  shows "$1" crashReportsQuestionTitle
}

crash_question_gone() {
  ! asks_about_crash_reports "$1"
}

# shows_or_asks <name> <find arguments...>
shows_or_asks() {
  local name="$1"
  shift
  shows "$name" "$@" || asks_about_crash_reports "$name"
}

# decline_crash_reports [seconds]: when the question shows within the
# seconds (default 4, as it comes a moment after the shell), taps No thanks.
# Returns 1 when it did not show: a build without a DSN, or answered before.
decline_crash_reports() {
  local name=crash-question point
  wait_until "${1:-4}" "$name" asks_about_crash_reports "$name" || return 1
  if ! point="$(ui point "${out}/${name}.xml" crashReportsQuestionDecline)"; then
    fail "the crash reports question has $(ui string en crashReportsQuestionDecline) (see ${name}.png)"
    return 0
  fi
  guard_device
  # shellcheck disable=SC2086 # the point is two words, x and y.
  adb_ shell input tap $point || die "cannot tap on ${serial}"
  if wait_until 10 "$name" crash_question_gone "$name"; then
    pass "a build with crash reports asked once; $(ui string en crashReportsQuestionDecline) declined them"
  else
    fail "the crash reports question went away after $(ui string en crashReportsQuestionDecline) (see ${name}.png)"
  fi
}

# expect_shell <description> <seconds> <name> <find arguments...>:
# expect_screen for the shell, past the crash reports question.
expect_shell() {
  local description="$1" seconds="$2" name="$3" wait=0
  shift 3
  wait_until "$seconds" "$name" shows_or_asks "$name" "$@" || true
  if decline_crash_reports 4; then wait=30; fi
  expect_screen "$description" "$wait" "$name" "$@"
}

# expect_signed_in_after_restart <name>
expect_signed_in_after_restart() {
  restart_app
  expect_shell "still signed in after a force-stop and a new start" 60 "$1" "${synced[@]}"
  expect_absent "no Connect screen after the new start" "$1" connectTagline
}

trap 'stop_recording' EXIT

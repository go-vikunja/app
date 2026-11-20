#!/usr/bin/env bash
# The update over the previous app (D85; threat model 8.2, item 13) on a
# running emulator: installs the old APK fresh, waits while you sign it in
# and set it up, installs the new APK over it with `adb install -r`, then
# checks the first start (the note, the server filled in, the session tried
# once, the theme from the first frame and the language), the first sync, a
# new start and that the previous app's channels, work and reminder alarms
# are gone while its widgets stay. Prints PASS, FAIL or SKIP per check and
# exits 1 when one failed, 2 when the test could not run; the output folder
# gets the log, the screen dumps, the screenshots and a recording of the
# first start.
#
# Usage: tool/e2e/update_test.sh [--server URL] [--task TITLE]... <emulator serial> <old.apk> <new.apk> <output folder>
#
# --server  where the previous app signs in (default http://localhost:34527,
#           the Docker test server; a localhost port gets `adb reverse`). On
#           http the app must ask to sign in again with the server filled in;
#           on https, such as the public demo, it must keep the session
#           without a browser.
# --task    a task title the first sync must show (repeatable). Default on
#           the local test server: an open task of tool/seed_demo_data.py.
#
# Both APKs need the application id io.vikunja.app and one signing
# certificate, the new one a higher version code. Only on the AVDs
# Vikunja_Screens and Vikunja_Tablet; never starts or stops an emulator. You
# do every sign-in; nothing prints a password or token, and the recording
# stops once a browser or a Connect screen that takes input shows, so it
# never holds a sign-in. Must run on macOS's bash 3.2.
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
(($# == 4)) || usage
serial="$1" old_apk="$2" new_apk="$3" out="$4"
open_output

# On http the session try refuses before it sends the token (D8), so this
# part takes 8.2's "sign in again" settings; on https its "stay signed in".
if [[ "$server" == https://* ]]; then
  kept=1
  old_settings="Settings tab: Theme Light and Dynamic Colors on; leave the language."
else
  kept=0
  old_settings="Settings tab: Theme Dark, Dynamic Colors off, Language Deutsch, and 15 as the Background Refresh Interval with Save."
fi

# label <message key>: as the app shows it, German after the update from a
# German previous app, else in the device's language.
label() {
  if ((kept)); then
    echo "'$(ui string en "$1")' ('$(ui string de "$1")')"
  else
    echo "'$(ui string de "$1")'"
  fi
}

locale_is() {
  [[ "$(app_locales)" == *"[$1"* ]]
}

expect_reminders_channel() {
  local want line name
  want="$(ui string de notificationChannelReminders)"
  line="$(channel_line reminders)"
  if [[ -z "$line" ]]; then
    skip "the channel reminders is named ${want} (the app has not created it yet)"
    return 0
  fi
  name="$(sed -n 's/.*mName=\([^,]*\),.*/\1/p' <<<"$line")"
  if [[ "$name" == "$want" ]]; then
    pass "the channel reminders is named ${want}"
  else
    owner_confirms "the channel reminders is named ${want}" \
      "dumpsys shows its name as '${name}'. Does Settings > Apps > Vikunja > Notifications list '${want}'?"
  fi
}

address_unlocked() {
  connect_unlocked "$1" && field_enabled "$1" "$host_port"
}

# first-frame.png is taken as `am start -W` returns, which waits for the
# first frame. The launch screen before it follows the system's mode, so
# unless a light system shows a dark screenshot, the owner judges the
# recording.
expect_dark_first_frame() {
  local mean frames="${out}/first-start.mp4"
  # The native launch screen follows the system's mode, not the app's theme
  # (D45), so only the frames after it count.
  if command -v ffmpeg >/dev/null 2>&1 && command -v magick >/dev/null 2>&1 &&
    ffmpeg -loglevel error -y -i "${out}/first-start.mp4" -t 4 \
      -vf "fps=8,scale=120:-1,tile=8x4" -frames:v 1 "${out}/first-frames.png" 2>/dev/null; then
    frames="${out}/first-frames.png (the first 4 s, 8 frames a second, row by row)"
  fi
  if [[ "$(shell_ cmd uimode night 2>/dev/null)" != *"mode: no"* ]]; then
    owner_confirms "dark from the first frame" \
      "The system is not in light mode, so first-frame.png cannot tell the launch screen from the app. Look at ${frames}: is the app dark from its first own frame, right after the launch screen with the logo, without a light frame of the app?"
  elif mean="$(brightness first-frame)" && looks dark "$mean"; then
    pass "dark from the first frame (first-frame.png, mean brightness ${mean})"
  else
    owner_confirms "dark from the first frame" \
      "first-frame.png, taken as the start returned, is not dark (mean brightness ${mean:-unknown}); it may still show the launch screen, which follows the light system (D45). Look at ${frames}: is the app dark from its first own frame, right after the launch screen with the logo, without a light frame of the app?"
  fi
}

section "Preflight"
check_emulator
check_apk old "$old_apk"
old_code="$apk_code" old_cert="$apk_cert"
check_apk new "$new_apk"
new_code="$apk_code" new_cert="$apk_cert" new_debug="$apk_debug"
((new_code > old_code)) || die "the new APK's version code ${new_code} is not above the old one's ${old_code}"
[[ "$new_cert" == "$old_cert" ]] || die "the APKs have different signing certificates, so Android would refuse the update"
prepare_server
load_synced

section "The previous app"
confirm_wipe
reinstall "$old_apk"
[[ "$(installed_version_code)" == "$old_code" ]] || die "the previous app did not install"
start_app
owner \
  "The previous app is open: enter ${server} and $(sign_in_hint)." \
  "$old_settings" \
  "Optional: place its widget on the home screen and add its Quick Settings tile." \
  "Optional: a task with a reminder a few minutes ahead (on Android 16 the install removed such alarms on 2026-11-14, while on 2026-11-20 six survived it until the first start)." \
  "Last, go to the home screen and leave the app closed."
old_widgets="$(old_widget_count)"
old_alarms="$(reminder_alarm_count)"
leftovers=""
for id in Vikunja1 Vikunja2; do
  if [[ -n "$(channel_line "$id")" ]]; then leftovers+=" ${id}"; fi
done
if grep -F 'update-tasks' <<<"$(work_rows)" >/dev/null; then leftovers+=" update-tasks"; fi
note "before the update: ${old_widgets} placed widgets, ${old_alarms} reminder alarms; channels and work:${leftovers:- none}"

section "The update"
adb_ shell input keyevent KEYCODE_HOME || die "cannot go to the home screen of ${serial}"
clear_logcat
guard_device
install_output="$(adb_ install -r "$new_apk" 2>&1)" || die "adb install -r failed: ${install_output}"
check "the update installed over the previous app (version code ${new_code})" test "$(installed_version_code)" = "$new_code"
note "$(reminder_alarm_count) reminder alarms right after the install, before the first start"

section "The first start"
start_recording first-start.mp4
sleep 1
start_app
screenshot first-frame
if ((kept)); then
  seen_progress=0 seen_note=0 shell_shown=0
  deadline=$((SECONDS + 120))
  while [[ -n "$recording_pid" ]] && ((SECONDS < deadline)); do
    if dump_screen first-start; then
      if ((!seen_progress)) && shows first-start previousAppSigningIn; then
        seen_progress=1
        cp "${out}/first-start.xml" "${out}/progress.xml"
        screenshot progress
      fi
      if ((!seen_note)) && shows first-start previousAppNoteSignedIn; then
        seen_note=1
        cp "${out}/first-start.xml" "${out}/note.xml"
        screenshot note
      fi
      if shows first-start "${synced[@]}"; then
        shell_shown=1
        break
      fi
    fi
    sleep 1
  done
  screenshot first-start
  stop_recording
  check "no browser opened${browser_seen:+ (${browser_seen})}" test -z "$browser_seen"
  if ((seen_progress)); then
    pass "Connect showed the progress line while it kept the session"
  else
    owner_confirms "Connect showed the progress line while it kept the session" \
      "Does ${out}/first-start.mp4 show $(label previousAppSigningIn) (host ${host_port}) with Cancel?"
  fi
  if ((seen_note)); then
    pass "the first-sync screen showed the note that you're still signed in"
    if ((old_widgets > 0)); then
      check "the note asks to set up the previous app's widgets" shows note previousAppNoteWidgets
    fi
  else
    owner_confirms "the first-sync screen showed the note that you're still signed in" \
      "Does ${out}/first-start.mp4 show $(label previousAppNoteSignedIn)?"
  fi
  check "the previous app's session was kept and the first sync shows the tasks" test "$shell_shown" = 1
  expect_theme light first-start
  note "per-app language: $(app_locales)"
  note "$(reminder_alarm_count) reminder alarms after the first sync (the app's own count too)"
else
  expect_screen "Connect shows the note with the server filled in, asking to sign in again" 60 first-start \
    previousAppNoteSignInAgain
  check "Connect is unlocked within 40 s (the try's limit is 30 s): no progress line, the address field takes input" \
    wait_until 40 first-start address_unlocked first-start
  stop_recording
  check "no browser opened${browser_seen:+ (${browser_seen})}" test -z "$browser_seen"
  expect_dark_first_frame
  check "the note's title shows" shows first-start previousAppNoteTitle
  check "Connect holds the previous app's server ${host_port}" field_holds first-start "$host_port"
  if ((old_widgets > 0)); then
    check "the note asks to set up the previous app's widgets after the sign-in" \
      shows first-start previousAppNoteWidgetsAfterSignIn
  else
    expect_absent "the note has no widget line (no widget placed)" first-start previousAppNoteWidgetsAfterSignIn
  fi
  check "the note is in German" shows first-start --lang de previousAppNoteTitle
  if ((api_level >= 33)); then
    check "the per-app language is German (cmd locale get-app-locales)" locale_is de
  else
    skip "the per-app language is German (needs Android 13)"
  fi
  expect_theme dark first-start
  check "no reminder alarm of the previous app is left (${old_alarms} before the update)" test "$(reminder_alarm_count)" = 0
  expect_reminders_channel
fi
if ((old_widgets > 0)); then
  check "the previous app's widgets stay placed (${old_widgets})" test "$(old_widget_count)" -eq "$old_widgets"
fi
expect_old_leftovers_gone "$leftovers"

if ((!kept)); then
  restart_app
  expect_screen "after a force-stop Connect shows again" 60 restart connectTagline
  check "after a force-stop Connect still holds ${host_port}" field_holds restart "$host_port"
  expect_absent "after a force-stop the note is gone" restart previousAppNoteTitle
  expect_absent "after a force-stop no progress line shows" restart previousAppSigningIn

  section "Signing in again"
  owner \
    "Tap $(ui string de connectContinue), allow the unencrypted connection and $(sign_in_hint)." \
    "Come back here once the app is back from the browser."
  expect_screen "the first sync shows the tasks" 180 synced "${synced[@]}"
  expect_theme dark synced
  check "the app is in German after the sign-in" shows synced --lang de tabOverview
fi

section "Settings and widgets"
if ((kept)); then choice=appearanceThemeLight colors=on; else choice=appearanceThemeDark colors=off; fi
owner_confirms "the previous app's theme and colors carried over" \
  "Account tab > $(label appearanceHeading): is $(label "$choice") chosen with $(label appearanceOnThisDevice) under it, and $(label appearanceSystemColors) ${colors}?"
if ((old_widgets > 0)); then
  owner_confirms "the previous app's widget waits for its setup" \
    "Does the Widgets page list $(label widgetsPlacedPreviousApp) as not set up, and does a tap on the placed widget open its setup?"
fi

section "A new start"
expect_signed_in_after_restart restarted
for id in Vikunja1 Vikunja2; do
  check "the channel ${id} did not come back" test -z "$(channel_line "$id")"
done
expect_no_crash "$new_debug"
summary

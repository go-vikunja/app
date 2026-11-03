#!/usr/bin/env bash
# Takes the store screenshots on an Android emulator or an iOS simulator, one
# motif at a time: open the motif on the device, press Enter, and the script
# saves the screen into the fastlane layout (docs/store-listing.md). It sets a
# clean status bar (full battery and Wi-Fi, no mobile signal, no
# notifications) and, on Android, a 16:9 window, because Play takes no side
# longer than twice the other; it restores the device when it ends, also after
# Ctrl-C. The clock shows the device's own time at each shot, so it agrees
# with the Overview's greeting and the due times.
#
# Usage: tool/store_screenshots.sh [--no-wait] android <emulator serial> <en-GB|de-DE> <phone|tablet> [motif...]
#        tool/store_screenshots.sh [--no-wait] ios <simulator UDID> <en-GB|de-DE> <phone|tablet> [motif...]
#        tool/store_screenshots.sh --list
# Without motifs it goes through all of the form factor's motifs in order.
# --no-wait takes the named motifs at once, for a device that already shows
# them. Only emulators and booted simulators, never a physical device.
# Needs adb or xcrun simctl, and ImageMagick 7 to drop the alpha channel.
# Must run on macOS's bash 3.2.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
phone_motifs="overview project-list kanban task-detail new-task upcoming"
tablet_motifs="list-detail"

die() {
  echo "error: $*" >&2
  exit 2
}

usage() {
  sed -n '/^# Usage:/,/--list$/s/^# //p' "${BASH_SOURCE[0]}" >&2
  exit 2
}

motif_hint() {
  case "$1" in
    overview) echo "the Overview tab, scrolled to the top" ;;
    project-list) echo "the project Work (Arbeit) in its List view" ;;
    kanban) echo "the project Work (Arbeit) in its Kanban view" ;;
    task-detail) echo "the task Fix the dishwasher (Spülmaschine reparieren), its sheet pulled up and at its top" ;;
    new-task) echo "the New task sheet from the Overview, with a title typed in" ;;
    upcoming) echo "the Upcoming tab, scrolled to the end of its list" ;;
    list-detail) echo "the Overview with Finish the quarterly report (Quartalsbericht fertigstellen) open beside it" ;;
  esac
}

list_motifs() {
  local n=0 motif
  echo "phone:"
  for motif in $phone_motifs; do
    n=$((n + 1))
    printf '  %02d-%s: %s\n' "$n" "$motif" "$(motif_hint "$motif")"
  done
  n=0
  echo "tablet:"
  for motif in $tablet_motifs; do
    n=$((n + 1))
    printf '  %02d-%s: %s\n' "$n" "$motif" "$(motif_hint "$motif")"
  done
}

wait_for_enter=1
if [[ "${1:-}" == "--list" ]]; then
  list_motifs
  exit 0
fi
if [[ "${1:-}" == "--no-wait" ]]; then
  wait_for_enter=0
  shift
fi
(($# >= 4)) || usage
platform="$1" device="$2" locale="$3" form="$4"
shift 4

case "$locale" in
  en-GB | de-DE) ;;
  *) die "the listing languages are en-GB and de-DE, not $locale" ;;
esac
case "$form" in
  phone) all_motifs="$phone_motifs" ;;
  tablet) all_motifs="$tablet_motifs" ;;
  *) die "the form factor is phone or tablet, not $form" ;;
esac
for motif in "$@"; do
  case " $all_motifs " in
    *" $motif "*) ;;
    *) die "$motif is not a $form motif ($all_motifs)" ;;
  esac
done
((wait_for_enter || $# > 0)) || die "--no-wait needs the motifs to take"
selected="${*:-$all_motifs}"
command -v magick >/dev/null 2>&1 || die "ImageMagick 7 (magick) is needed"

tmp="$(mktemp -d)"
prepared=0

adb_() {
  adb -s "$device" "$@"
}

android_value() {
  adb_ shell "$@" | tr -d '\r'
}

demo() {
  adb_ shell am broadcast -a com.android.systemui.demo -e command "$@" >/dev/null
}

check_android() {
  command -v adb >/dev/null 2>&1 || die "adb is not on the PATH"
  [[ "$device" =~ ^emulator-[0-9]+$ ]] || die "refusing $device: only emulators (emulator-<port>), never a physical device"
  [[ "$(adb_ get-state 2>/dev/null)" == "device" ]] || die "$device is not connected (adb devices)"
  local qemu boot_qemu
  qemu="$(android_value getprop ro.kernel.qemu)"
  boot_qemu="$(android_value getprop ro.boot.qemu)"
  [[ "$qemu" == 1 || "$boot_qemu" == 1 ]] || die "refusing $device: it does not report itself as an emulator"
}

prepare_android() {
  old_demo_allowed="$(android_value settings get global sysui_demo_allowed)"
  old_12_24="$(android_value settings get system time_12_24)"
  old_size="$(android_value wm size | sed -n 's/^Override size: //p')"
  old_density="$(android_value wm density | sed -n 's/^Override density: //p')"
  local physical width height short long
  physical="$(android_value wm size | sed -n 's/^Physical size: //p')"
  [[ "$physical" =~ ^[0-9]+x[0-9]+$ ]] || die "cannot read the display size of $device"
  width="${physical%x*}" height="${physical#*x}"
  if ((width < height)); then short=$width long=$height; else short=$height long=$width; fi
  if ((long * 9 > short * 16)); then long=$((short * 16 / 9)); else short=$((long * 9 / 16)); fi
  if ((width < height)); then window="${short}x${long}"; else window="${long}x${short}"; fi
  ((short >= 1080)) || echo "note: the short side is ${short} px; Play promotes only screenshots of at least 1080 px" >&2

  prepared=1
  adb_ shell settings put global sysui_demo_allowed 1
  # The app writes 24-hour times in both languages.
  adb_ shell settings put system time_12_24 24
  demo enter
  demo battery -e level 100 -e plugged false
  # Without fully, Wi-Fi carries the no-internet mark.
  demo network -e wifi show -e level 4 -e fully true
  demo network -e mobile hide
  demo notifications -e visible false
  adb_ shell wm size "$window"
  echo "$device: demo mode on, window ${window} (was ${old_size:-$physical})"
}

restore_android() {
  demo exit || true
  if [[ -z "$old_demo_allowed" || "$old_demo_allowed" == null ]]; then
    adb_ shell settings delete global sysui_demo_allowed >/dev/null || true
  else
    adb_ shell settings put global sysui_demo_allowed "$old_demo_allowed" || true
  fi
  if [[ -z "$old_12_24" || "$old_12_24" == null ]]; then
    adb_ shell settings delete system time_12_24 >/dev/null || true
  else
    adb_ shell settings put system time_12_24 "$old_12_24" || true
  fi
  adb_ shell wm size "${old_size:-reset}" || true
  adb_ shell wm density "${old_density:-reset}" || true
  echo "$device: demo mode off, window and density restored"
}

capture_android() {
  demo clock -e hhmm "$(android_value date +%H%M)"
  sleep 1
  adb_ exec-out screencap -p >"$1"
}

check_ios() {
  if ! xcrun simctl help >/dev/null 2>&1; then
    die "xcrun simctl does not run; point xcode-select or DEVELOPER_DIR at Xcode"
  fi
  [[ "$device" =~ ^[0-9A-Fa-f]{8}-([0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}$ ]] ||
    die "a simulator's UDID is needed (xcrun simctl list devices booted)"
  xcrun simctl list devices booted | grep -q "($device) (Booted)" || die "$device is not a booted simulator"
}

prepare_ios() {
  prepared=1
  xcrun simctl status_bar "$device" override --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --operatorName '' --batteryState charged --batteryLevel 100
  echo "$device: status bar overridden"
}

restore_ios() {
  xcrun simctl status_bar "$device" clear || true
  echo "$device: status bar cleared"
}

capture_ios() {
  xcrun simctl status_bar "$device" override --time "$(date +%-H:%M)"
  sleep 1
  xcrun simctl io "$device" screenshot --type=png --mask=ignored "$1" >/dev/null
}

finish() {
  local status=$?
  if ((prepared)); then
    "restore_$platform"
  fi
  rm -rf "$tmp"
  exit "$status"
}
trap finish EXIT
trap 'exit 130' INT TERM

destination() {
  local number="$1" motif="$2" size="$3"
  case "$platform:$form" in
    android:phone) echo "$repo_root/fastlane/metadata/android/$locale/images/phoneScreenshots/$number-$motif.png" ;;
    android:tablet) echo "$repo_root/fastlane/metadata/android/$locale/images/tenInchScreenshots/$number-$motif.png" ;;
    ios:*) echo "$repo_root/fastlane/screenshots/$locale/$number-$motif-$size.png" ;;
  esac
}

take() {
  local number="$1" motif="$2" size out
  "capture_$platform" "$tmp/raw.png"
  magick "$tmp/raw.png" -background black -alpha remove -alpha off -strip -define png:color-type=2 "$tmp/shot.png"
  size="$(magick identify -format '%wx%h' "$tmp/shot.png")"
  out="$(destination "$number" "$motif" "$size")"
  mkdir -p "$(dirname "$out")"
  mv "$tmp/shot.png" "$out"
  echo "saved ${out#"$repo_root"/} ($size)"
}

case "$platform" in
  android) check_android ;;
  ios) check_ios ;;
  *) die "the platform is android or ios, not $platform" ;;
esac
"prepare_$platform"
sleep 2

index=0
total="$(echo "$all_motifs" | wc -w | tr -d ' ')"
for motif in $all_motifs; do
  index=$((index + 1))
  case " $selected " in
    *" $motif "*) ;;
    *) continue ;;
  esac
  number="$(printf '%02d' "$index")"
  if ((wait_for_enter)); then
    printf '%s/%s %s: open %s, then press Enter (s skips, q quits) ' "$index" "$total" "$motif" "$(motif_hint "$motif")"
    read -r answer || break
    case "$answer" in
      s) continue ;;
      q) break ;;
    esac
  fi
  take "$number" "$motif"
done
echo "Check them: python3 -I tool/check_store_metadata.py"

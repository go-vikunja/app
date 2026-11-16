#!/usr/bin/env bash
# The iOS release for TestFlight (docs/releasing.md), run by hand on the
# owner's Mac (D74); no CI job calls it yet. Builds the IPA with the version
# from the tag, signed automatically for the team in DEVELOPMENT_TEAM, checks
# it and uploads it to App Store Connect with an API key.
#
# Usage: tool/ci/ios_release.sh [--tag TAG] [--dry-run]
#
# --dry-run builds the archive unsigned (--no-codesign), runs the same checks,
# and stops before the export and the upload; the tag defaults to v<the
# pubspec's version name>.
#
# Environment (docs/releasing.md): DEVELOPMENT_TEAM, the Apple team id;
# VIKUNJA_APP_ASC_KEY_ID, VIKUNJA_APP_ASC_ISSUER_ID and
# VIKUNJA_APP_ASC_KEY_FILE, the App Store Connect API key's id, its issuer id
# and the path of its .p8 file; VIKUNJA_APP_SOURCE_CODE_URL, the repository's
# URL (default https://github.com/go-vikunja/app), whose tree at the tag the
# build links as its source.
set -euo pipefail
# shellcheck source=tool/ci/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
cd "$repo_root"

usage() {
  echo "usage: tool/ci/ios_release.sh [--tag TAG] [--dry-run]" >&2
  exit 2
}

tag=""
dry_run=0
while (($# > 0)); do
  case "$1" in
    --tag)
      (($# >= 2)) || usage
      tag="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    *) usage ;;
  esac
done

# Out of the environment into unexported copies before Flutter or Xcode runs:
# only altool gets the key, never the build's hooks and script phases.
asc_key_id="${VIKUNJA_APP_ASC_KEY_ID:-}"
asc_issuer_id="${VIKUNJA_APP_ASC_ISSUER_ID:-}"
key_file="${VIKUNJA_APP_ASC_KEY_FILE:-}"
unset VIKUNJA_APP_ASC_KEY_ID VIKUNJA_APP_ASC_ISSUER_ID VIKUNJA_APP_ASC_KEY_FILE

if [[ "$(uname -s)" != Darwin ]]; then
  echo "error: the iOS release needs a Mac with Xcode" >&2
  exit 1
fi

if [[ -z "$tag" ]]; then
  if ((dry_run)); then
    tag="v$(sed -n 's/^version:[[:space:]]*\([^+[:space:]]*\).*/\1/p' app/pubspec.yaml)"
  else
    echo "error: no tag: pass --tag" >&2
    exit 2
  fi
fi

version="$(python3 -I tool/ci/release_version.py "$tag")"
build_name="$(sed -n 's/^IOS_BUILD_NAME=//p' <<<"$version")"
build_number="$(sed -n 's/^IOS_BUILD_NUMBER=//p' <<<"$version")"
channel="$(sed -n 's/^CHANNEL=//p' <<<"$version")"
echo "iOS release ${tag}: version ${build_name}, build ${build_number}, ${channel}"

not_releasable=()
# Fails the real run; a warning and a reason in the dry run.
refuse() {
  if ((dry_run)); then
    echo "warning (dry run): $1" >&2
    not_releasable+=("$2")
  else
    echo "error: $1" >&2
    exit 1
  fi
}

use_selected_xcode
setup_flutter
flutter_version="$(flutter --version --machine 2>/dev/null | sed -n 's/.*"frameworkVersion": *"\([^"]*\)".*/\1/p' || true)"
if [[ "$flutter_version" != "$FLUTTER_VERSION" ]]; then
  refuse "Flutter ${flutter_version:-of unknown version} found, tool/ci/pins.sh pins ${FLUTTER_VERSION}" \
    "Flutter ${flutter_version:-unknown}"
fi

# The build has to be the source the link names.
tag_commit="$(git rev-parse -q --verify "refs/tags/${tag}^{commit}" || true)"
if [[ -z "$tag_commit" ]]; then
  refuse "there is no tag ${tag} in this repository" "no tag ${tag}"
elif [[ "$tag_commit" != "$(git rev-parse HEAD)" ]]; then
  refuse "HEAD is not ${tag}: git checkout ${tag}" "HEAD is not ${tag}"
fi
if [[ -n "$(git status --porcelain)" ]]; then
  refuse "the working tree has changes or untracked files (git status)" "uncommitted changes"
fi

source_repository="${VIKUNJA_APP_SOURCE_CODE_URL:-https://github.com/go-vikunja/app}"
source_repository="${source_repository%/}"
if [[ "$source_repository" != https://?* ]]; then
  refuse "the source repository (${source_repository:-empty}) is not an https URL: set VIKUNJA_APP_SOURCE_CODE_URL" \
    "source URL"
fi
source_url="${source_repository}/tree/${tag}"
if ((dry_run)); then
  echo "Would check that ${source_url} opens signed out."
else
  status="$(curl --silent --output /dev/null --write-out '%{http_code}' --retry 3 "$source_url" || true)"
  if [[ "$status" != 200 ]]; then
    refuse "${source_url} answered ${status} signed out: the source link must open for everyone" \
      "source not public"
  fi
fi

team="${DEVELOPMENT_TEAM:-}"
if [[ ! "$team" =~ ^[A-Z0-9]{10}$ ]]; then
  refuse "DEVELOPMENT_TEAM is not a team id (ten capital letters and digits)" "no team id"
  team=TEAMID0000
fi
for pair in "VIKUNJA_APP_ASC_KEY_ID=${asc_key_id}" "VIKUNJA_APP_ASC_ISSUER_ID=${asc_issuer_id}" \
  "VIKUNJA_APP_ASC_KEY_FILE=${key_file}"; do
  if [[ -z "${pair#*=}" ]]; then
    refuse "${pair%%=*} is not set" "no ${pair%%=*}"
  fi
done
if [[ -n "$key_file" ]]; then
  if [[ ! -f "$key_file" || ! -r "$key_file" ]]; then
    refuse "VIKUNJA_APP_ASC_KEY_FILE does not name a readable file" "API key unreadable"
  elif ((0$(stat -L -f %Lp "$key_file") & 077)); then
    refuse "VIKUNJA_APP_ASC_KEY_FILE can be read by other users: chmod 600 it" "API key readable by others"
  fi
fi
if ! python3 -I tool/l10n_progress.py --min 100 de >/dev/null; then
  refuse "German is not complete: a release needs every English text in German (D88); finish it on Crowdin and merge Crowdin's pull request" \
    "German incomplete"
fi

icon=app/ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png
icon_info="$(sips -g pixelWidth -g pixelHeight -g hasAlpha -g space -g profile "$icon")"
icon_value() {
  sed -n "s/^ *$1: //p" <<<"$icon_info"
}
icon_profile="$(icon_value profile)"
if [[ "$(icon_value pixelWidth)x$(icon_value pixelHeight)" != 1024x1024 || "$(icon_value hasAlpha)" != no ||
  "$(icon_value space)" != RGB || ("$icon_profile" != '<nil>' && "$icon_profile" != *sRGB*) ]]; then
  echo "$icon_info" >&2
  echo "error: the App Store icon must be 1024 x 1024 sRGB without an alpha channel: run branding/build-icons.sh" \
    "and flutter_launcher_icons (README)" >&2
  exit 1
fi

work="$(mktemp -d "${TMPDIR:-/tmp}/vikunja-app-ios-release.XXXXXX")"
trap 'rm -rf "$work"' EXIT
trap 'exit 130' INT TERM

# manageAppVersionAndBuildNumber off: the version is the tag's, never Xcode's.
cat >"${work}/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>destination</key>
	<string>export</string>
	<key>manageAppVersionAndBuildNumber</key>
	<false/>
	<key>method</key>
	<string>app-store-connect</string>
	<key>signingStyle</key>
	<string>automatic</string>
	<key>teamID</key>
	<string>${team}</string>
	<key>uploadSymbols</key>
	<true/>
</dict>
</plist>
PLIST
plutil -lint "${work}/ExportOptions.plist" >/dev/null

(cd app && flutter test --run-skipped --tags release --dart-define=SOURCE_CODE_URL="$source_url")

archive=app/build/ios/archive/Runner.xcarchive
ipa_dir=app/build/ios/ipa
rm -rf "$archive" "$ipa_dir"
build=(flutter build ipa --release --build-name="$build_name" --build-number="$build_number"
  --dart-define=SOURCE_CODE_URL="$source_url")
if ((dry_run)); then
  (cd app && "${build[@]}" --no-codesign)
else
  (cd app && FLUTTER_XCODE_DEVELOPMENT_TEAM="$team" FLUTTER_XCODE_CODE_SIGN_STYLE=Automatic \
    "${build[@]}" --export-options-plist="${work}/ExportOptions.plist")
fi

app_bundle="${archive}/Products/Applications/Runner.app"
extension="${app_bundle}/PlugIns/VikunjaWidgets.appex"
plist_value() {
  plutil -extract "$2" raw -o - "$1/Info.plist" 2>/dev/null || echo "<missing>"
}
for bundle in "$app_bundle" "$extension"; do
  if [[ ! -d "$bundle" ]]; then
    echo "error: ${bundle} was not built" >&2
    exit 1
  fi
  short="$(plist_value "$bundle" CFBundleShortVersionString)"
  number="$(plist_value "$bundle" CFBundleVersion)"
  if [[ "$short" != "$build_name" || "$number" != "$build_number" ]]; then
    echo "error: $(basename "$bundle") has version ${short} (${number}), the tag ${build_name} (${build_number})" >&2
    exit 1
  fi
done
if [[ "$(plist_value "$app_bundle" ITSAppUsesNonExemptEncryption)" != false ]]; then
  echo "error: Runner.app does not declare ITSAppUsesNonExemptEncryption false" >&2
  exit 1
fi
for pair in "${app_bundle}:app/ios/Runner" "${extension}:app/ios/VikunjaWidgets"; do
  built="${pair%%:*}/PrivacyInfo.xcprivacy"
  source="${pair#*:}/PrivacyInfo.xcprivacy"
  if [[ ! -f "$built" ]] ||
    [[ "$(plutil -convert json -o - "$built")" != "$(plutil -convert json -o - "$source")" ]]; then
    echo "error: ${built} is missing or differs from ${source}: run ruby tool/add_widget_extension.rb" >&2
    exit 1
  fi
done
apis_declared=""
if python3 -I tool/ci/required_reason_apis.py "$app_bundle"; then
  apis_declared=" and every required-reason API their binaries use"
else
  refuse "a binary uses a required-reason API that no privacy manifest declares (above): App Store Connect refuses such a build" \
    "undeclared required-reason API"
fi
python3 -I tool/ci/ios_notices.py "$app_bundle"
echo "Verified: Runner.app and VikunjaWidgets.appex ${build_name} (${build_number}), their privacy manifests${apis_declared}," \
  "ITSAppUsesNonExemptEncryption false, the 1024 icon, the licence notices."

if ((dry_run)); then
  echo
  echo "Would export the archive with these options (teamID from DEVELOPMENT_TEAM):"
  cat "${work}/ExportOptions.plist"
  echo "and upload the IPA from ${ipa_dir} with xcrun altool --upload-package and the VIKUNJA_APP_ASC_* key."
  reasons="$(printf '%s, ' "unsigned build" ${not_releasable[@]+"${not_releasable[@]}"})"
  echo "DRY RUN: NOT RELEASABLE (${reasons%, })"
  exit 0
fi

# flutter build ipa reports success even when the export fails.
shopt -s nullglob
ipas=("${ipa_dir}"/*.ipa)
shopt -u nullglob
if ((${#ipas[@]} != 1)); then
  echo "error: no single IPA in ${ipa_dir}: the export failed (see above)" >&2
  exit 1
fi
ipa="${ipas[0]}"
echo "IPA: $(sha256_of "$ipa")  ${ipa}"

xcrun altool --upload-package "$ipa" --api-key "$asc_key_id" --api-issuer "$asc_issuer_id" --p8-file-path "$key_file"
echo "Uploaded ${build_name} (${build_number}) to App Store Connect; it appears in TestFlight once processed."

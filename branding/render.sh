#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# ImageMagick 7 ships only its internal MSVG renderer here (no librsvg delegate),
# and MSVG paints linearGradient fills black, so Inkscape does the rasterising.
INKSCAPE="${INKSCAPE:-$(command -v inkscape || echo /Applications/Inkscape.app/Contents/MacOS/inkscape)}"
FLATTEN_COLOR='#1252E6'

render() {
  "$INKSCAPE" "$1" --export-type=png --export-filename="$2" \
    --export-width="$3" --export-height="$3" --export-background-opacity=0 >/dev/null 2>&1
}

mkdir -p png
for name in icon-foreground icon-monochrome logo-mark; do
  render "$name.svg" "png/$name-1024.png" 1024
done

# App Store Connect rejects a marketing icon that has an alpha channel.
for name in icon-ios icon-background; do
  render "$name.svg" "png/$name-1024.tmp.png" 1024
  magick "png/$name-1024.tmp.png" -background "$FLATTEN_COLOR" -alpha remove -alpha off \
    -define png:color-type=2 "png/$name-1024.png"
  rm "png/$name-1024.tmp.png"
done

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# Android 7 (API 24-25) has no adaptive icons: use the visible 72 dp of the
# adaptive layers as a rounded square. -extent composites with the current
# -compose, so it has to be reset to Over first.
magick png/icon-background-1024.png png/icon-foreground-1024.png -composite \
  -gravity center -crop 683x683+0+0 +repage -resize 940x940 "$tmp/legacy-tile.png"
magick -size 940x940 xc:black -fill white -draw 'roundrectangle 0,0 939,939 206,206' "$tmp/legacy-mask.png"
magick "$tmp/legacy-tile.png" "$tmp/legacy-mask.png" -alpha off -compose CopyOpacity -composite \
  -compose Over -background none -gravity center -extent 1024x1024 png/icon-android-legacy-1024.png

magick png/icon-background-1024.png png/icon-foreground-1024.png -composite \
  -gravity center -crop 683x683+0+0 +repage -resize 256x256 "$tmp/adaptive.png"
magick -size 256x256 xc:black -fill white -draw 'circle 128,128 128,0' "$tmp/m-circle.png"
magick -size 256x256 xc:black -fill white -draw 'roundrectangle 0,0 255,255 48,48' "$tmp/m-rounded.png"
magick -size 256x256 xc:black -fill white -draw 'roundrectangle 0,0 255,255 100,100' "$tmp/m-squircle.png"
magick -size 256x256 xc:black -fill white -draw 'roundrectangle 0,0 255,255 57,57' "$tmp/m-ios.png"
for mask in circle rounded squircle; do
  magick "$tmp/adaptive.png" "$tmp/m-$mask.png" -alpha off -compose CopyOpacity -composite "$tmp/a-$mask.png"
done
magick png/icon-ios-1024.png -resize 256x256 "$tmp/m-ios.png" -alpha off -compose CopyOpacity -composite "$tmp/a-ios.png"
magick png/icon-monochrome-1024.png -gravity center -crop 683x683+0+0 +repage -resize 256x256 \
  -channel RGB -fill '#24304A' -colorize 100 +channel "$tmp/mono.png"
magick -size 256x256 xc:'#D6E2FF' "$tmp/mono.png" -composite "$tmp/m-circle.png" \
  -alpha off -compose CopyOpacity -composite "$tmp/a-themed.png"
for size in 256 96 48; do
  magick -background '#ECEEF2' "$tmp/a-ios.png" "$tmp/a-circle.png" "$tmp/a-rounded.png" \
    "$tmp/a-squircle.png" "$tmp/a-themed.png" -resize "${size}x${size}" \
    -bordercolor '#ECEEF2' -border 12 +append "$tmp/row-$size.png"
done
magick png/logo-mark-1024.png -resize 200x200 -background white -gravity center -extent 256x256 "$tmp/logo-light.png"
magick png/logo-mark-1024.png -resize 200x200 \
  -background '#15171C' -gravity center -extent 256x256 "$tmp/logo-dark.png"
magick -background '#ECEEF2' "$tmp/logo-light.png" "$tmp/logo-dark.png" -bordercolor '#ECEEF2' -border 12 +append "$tmp/row-logo.png"
magick -background '#ECEEF2' "$tmp/row-256.png" "$tmp/row-96.png" "$tmp/row-48.png" "$tmp/row-logo.png" \
  -gravity west -append png/preview-sheet.png

columns=()
for svg in explorations-v1/*.svg; do
  base="$tmp/$(basename "$svg" .svg)"
  render "$svg" "$base-1024.png" 1024
  magick "$base-1024.png" -resize 256x256 "$tmp/m-ios.png" -alpha off -compose CopyOpacity -composite "$base-256.png"
  magick "$base-256.png" -resize 96x96 "$base-96.png"
  magick "$base-256.png" -resize 48x48 "$base-48.png"
  magick -background '#ECEEF2' "$base-96.png" "$base-48.png" -gravity center -bordercolor '#ECEEF2' -border 8 +append "$base-small.png"
  magick -background '#ECEEF2' "$base-256.png" "$base-small.png" -gravity center -bordercolor '#ECEEF2' -border 12 -append "$base-column.png"
  columns+=("$base-column.png")
done
magick -background '#ECEEF2' "${columns[@]}" +append explorations-v1/comparison.png

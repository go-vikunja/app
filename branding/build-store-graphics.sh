#!/usr/bin/env bash
# Builds the Google Play icon and feature graphic from the icons in png/
# (run build-icons.sh first after a change to the source). Needs ImageMagick 7.
set -euo pipefail
cd "$(dirname "$0")"

t="$(mktemp -d)"
trap 'rm -rf "$t"' EXIT

# Play masks the icon and adds the shadow itself, so it gets the full-bleed
# square; Play asks for 32-bit, hence an opaque alpha channel.
magick png/icon-ios-1024.png -filter Lanczos -resize 512x512 -alpha set \
  -depth 8 -strip -define png:color-type=6 png/play-icon-512.png

# Feature graphic: the bust with the badge from the iOS dark icon (llama and
# badge on transparency, at their places in the source) on the gradient,
# centred and flush with the bottom. No text, so one graphic serves every
# language; Play wants no alpha.
GRADIENT='0,0 rgb(50,102,222) 1023,0 rgb(32,146,196) 0,499 rgb(30,144,194) 1023,499 rgb(10,175,171)'
magick -size 1024x500 xc: -sparse-color bilinear "$GRADIENT" "$t/background.png"
magick png/icon-ios-dark-1024.png -crop 733x772+145+167 +repage -filter Lanczos -resize x470 "$t/bust.png"
magick "$t/background.png" "$t/bust.png" -gravity south -composite -alpha off \
  -depth 8 -strip -define png:color-type=2 png/feature-graphic-1024x500.png

magick identify -format '%f: %wx%h %[channels], %b\n' png/play-icon-512.png png/feature-graphic-1024x500.png

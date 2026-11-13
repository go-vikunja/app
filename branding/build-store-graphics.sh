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

# Feature graphic: the llama from the iOS dark icon (on transparency, its
# neck running off the bottom edge) on the icon's blue, centred and flush with
# the bottom. No text, so one graphic serves every language; Play wants no
# alpha.
magick png/icon-ios-dark-1024.png -trim +repage -filter Lanczos -resize x470 "$t/llama.png"
magick -size 1024x500 xc:'#196AFF' "$t/llama.png" -gravity south -composite -alpha off \
  -depth 8 -strip -define png:color-type=2 png/feature-graphic-1024x500.png

magick identify -format '%f: %wx%h %[channels], %b\n' png/play-icon-512.png png/feature-graphic-1024x500.png

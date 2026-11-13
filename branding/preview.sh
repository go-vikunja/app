#!/usr/bin/env bash
# Renders png/preview-sheet.png from the icons in png/: the iOS variants,
# the Android masks, the themed icon in light and dark, small sizes, the
# status bar icon and the in-app logo on dark and light. Needs ImageMagick 7
# and a TrueType font (FONT=...).
set -euo pipefail
cd "$(dirname "$0")"
FONT="${FONT:-/System/Library/Fonts/Helvetica.ttc}"
t="$(mktemp -d)"
trap 'rm -rf "$t"' EXIT
S=256

magick -size 1024x1024 xc:black -fill white -draw 'roundrectangle 0,0 1023,1023 229,229' -resize ${S}x${S} "$t/m_ios.png"
magick -size ${S}x${S} xc:black -fill white -draw "circle $((S / 2)),$((S / 2)) $((S / 2)),0" "$t/m_circle.png"
magick -size 1024x1024 xc:black -fill white -draw 'roundrectangle 0,0 1023,1023 360,360' -resize ${S}x${S} "$t/m_squircle.png"
magick -size ${S}x${S} xc:black -fill white -draw 'roundrectangle 0,0 255,255 128,128' -draw 'rectangle 128,128 255,255' "$t/m_tear.png"
mask() { magick "$1" -resize ${S}x${S} "$t/m_$2.png" -alpha off -compose CopyOpacity -composite "$3"; }

mask png/icon-ios-1024.png ios "$t/ios_light.png"
magick -size 1024x1024 gradient:'#3a3d44'-'#16171a' png/icon-ios-dark-1024.png -compose over -composite "$t/dark.png"
mask "$t/dark.png" ios "$t/ios_dark.png"
# Tinted: the desaturated dark variant multiplied with a tint.
magick png/icon-ios-dark-1024.png -alpha extract "$t/alpha.png"
magick png/icon-ios-dark-1024.png -alpha off -colorspace gray -colorspace sRGB \
  \( -size 1024x1024 xc:'#7DB3FF' \) -compose multiply -composite \
  "$t/alpha.png" -compose CopyOpacity -composite "$t/tint_fg.png"
magick -size 1024x1024 gradient:'#22252b'-'#0d0e10' "$t/tint_fg.png" -compose over -composite "$t/tinted.png"
mask "$t/tinted.png" ios "$t/ios_tinted.png"

magick png/icon-background-1024.png png/icon-foreground-1024.png -compose over -composite \
  -gravity center -crop 683x683+0+0 +repage "$t/adaptive.png"
mask "$t/adaptive.png" circle "$t/a_circle.png"
mask "$t/adaptive.png" squircle "$t/a_squircle.png"
mask "$t/adaptive.png" tear "$t/a_tear.png"
themed() {
  magick -size 1024x1024 xc:"$1" \( -size 1024x1024 xc:"$2" png/icon-monochrome-1024.png -compose CopyOpacity -composite \) \
    -compose over -composite -gravity center -crop 683x683+0+0 +repage "$3"
}
themed '#C9ECE7' '#24505D' "$t/th_light.png"
themed '#2A4855' '#E3F3F1' "$t/th_dark.png"
mask "$t/th_light.png" circle "$t/t_light.png"
mask "$t/th_dark.png" circle "$t/t_dark.png"

cell() {
  magick -size 300x330 xc:'#2b2d31' "$1" -gravity north -geometry +0+20 -compose over -composite \
    -font "$FONT" -fill '#e6e6e6' -pointsize 20 -gravity south -annotate +0+18 "$2" "$3"
}
cell "$t/ios_light.png" 'iOS' "$t/c1.png"
cell "$t/ios_dark.png" 'iOS 18 dark' "$t/c2.png"
cell "$t/ios_tinted.png" 'iOS 18 tinted' "$t/c3.png"
cell "$t/a_circle.png" 'Android, circle' "$t/c4.png"
cell "$t/a_squircle.png" 'Android, squircle' "$t/c5.png"
cell "$t/a_tear.png" 'Android, teardrop' "$t/c6.png"
cell "$t/t_light.png" 'Themed icon, light' "$t/c7.png"
cell "$t/t_dark.png" 'Themed icon, dark' "$t/c8.png"
magick "$t/c1.png" "$t/c2.png" "$t/c3.png" "$t/c4.png" +append "$t/r1.png"
magick "$t/c5.png" "$t/c6.png" "$t/c7.png" "$t/c8.png" +append "$t/r2.png"

args=()
x=30
for n in ios_light a_circle t_light t_dark; do
  for z in 96 48; do
    magick "$t/$n.png" -resize ${z}x${z} "$t/s_${n}_$z.png"
    args+=("$t/s_${n}_$z.png" -geometry +$x+$((20 + (96 - z) / 2)) -composite)
    x=$((x + z + 30))
  done
done
magick png/notification-960.png -resize 48x48 "$t/n48.png"
magick png/notification-960.png -resize 24x24 "$t/n24.png"
magick png/logo-1024.png -resize 96x96 "$t/logo96.png"
magick -size 1200x136 xc:'#2b2d31' -compose over "${args[@]}" \
  "$t/n48.png" -geometry +$((x + 10))+44 -composite "$t/n24.png" -geometry +$((x + 78))+56 -composite \
  "$t/logo96.png" -geometry +$((x + 130))+20 -composite \
  -fill '#f2f3f5' -draw "rectangle $((x + 236)),14 $((x + 343)),121" \
  "$t/logo96.png" -geometry +$((x + 242))+20 -composite "$t/r3.png"
magick "$t/r1.png" "$t/r2.png" "$t/r3.png" -append -depth 8 -strip png/preview-sheet.png
echo "Wrote png/preview-sheet.png"

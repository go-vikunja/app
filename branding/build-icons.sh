#!/usr/bin/env bash
# Builds every icon PNG in png/ from the illustrated logo in source/.
# Needs ImageMagick 7 (`magick`) and python3; no other tools.
set -euo pipefail
cd "$(dirname "$0")"

SRC=source/logo-llama.jpg
mkdir -p png
t="$(mktemp -d)"
trap 'rm -rf "$t"' EXIT

px() { python3 -c "print(round($1))"; }

# The background is a smooth four-corner gradient; modelling it lets the
# llama come off it with soft edges and without a blue fringe.
GRADIENT='0,0 rgb(50,102,222) 1999,0 rgb(32,146,196) 0,1999 rgb(30,144,194) 1999,1999 rgb(10,175,171)'
magick -size 2000x2000 xc: -sparse-color bilinear "$GRADIENT" "$t/bg.png"

# Llama alpha: brighter than the background by a soft margin, with the
# enclosed darker parts (eyes, nose, inner ears) filled in.
magick "$SRC" "$t/bg.png" -fx '(u.r*0.299+u.g*0.587+u.b*0.114)-(v.r*0.299+v.g*0.587+v.b*0.114)' \
  -colorspace gray -level 8%,28% "$t/soft.png"
magick "$t/soft.png" -threshold 50% -bordercolor black -border 1 -fill gray50 \
  -draw 'color 0,0 floodfill' -shave 1x1 -fill white -opaque black -fill black -opaque gray50 \
  -morphology Erode Disk:2 "$t/interior.png"
# The badge is cut out separately.
BADGE_X=1584; BADGE_Y=1582
magick "$t/soft.png" "$t/interior.png" -compose lighten -composite \
  -fill black -draw "circle $BADGE_X,$BADGE_Y $BADGE_X,$((BADGE_Y - 135))" "$t/llama_alpha.png"
magick "$SRC" "$t/bg.png" "$t/llama_alpha.png" -fx 'al=u[2].r; al<0.02 ? 0 : (u - (1-al)*v)/al' "$t/fg.png"
magick "$t/fg.png" "$t/llama_alpha.png" -alpha off -compose CopyOpacity -composite "$t/llama.png"

# Monochrome llama: the silhouette with the eyes, the muzzle (keeping nose
# and mouth) and the inner ears cut out, the way themed icons draw faces.
magick "$SRC" "$t/llama_alpha.png" -fx 'lu=0.299*u.r+0.587*u.g+0.114*u.b; ear=(j<770&&(i<880||i>1120))?1:0; ins=clamp((v.r-0.9)/0.1); ear*clamp((0.79-lu)/0.04)*ins' \
  -colorspace gray -blur 0x4 -level 40%,60% "$t/ear_holes.png"
magick "$SRC" "$t/llama_alpha.png" -fx 'lu=0.299*u.r+0.587*u.g+0.114*u.b; ear=(j<770&&(i<880||i>1120))?1:0; dk=clamp((0.62-lu)/0.08); cl=clamp((u.b-u.r+0.02)/0.02)*clamp((0.94-lu)/0.03); lm=(i>=830&&i<=1110&&j>=990&&j<=1300)?clamp((0.58-lu)/0.08):0; ins=clamp((v.r-0.9)/0.1); ear?0:max(dk,cl)*(1-lm)*ins' \
  -colorspace gray -blur 0x1.2 -level 30%,70% "$t/face_holes.png"
magick "$t/ear_holes.png" "$t/face_holes.png" -compose lighten -composite "$t/holes.png"
magick "$t/llama_alpha.png" "$t/holes.png" -fx 'u*(1-v)' "$t/glyph_alpha.png"
magick -size 2000x2000 xc:white "$t/glyph_alpha.png" -alpha off -compose CopyOpacity -composite "$t/glyph.png"

# Badge: an anti-aliased disk; in the monochrome version the check is cut out.
magick "$SRC" -crop 260x260+$((BADGE_X - 130))+$((BADGE_Y - 130)) +repage "$t/badge_crop.png"
magick -size 1040x1040 xc:black -fill white -draw 'circle 520,520 520,32' -resize 260x260 "$t/badge_mask.png"
magick "$t/badge_crop.png" "$t/badge_mask.png" -alpha off -compose CopyOpacity -composite "$t/badge.png"
magick "$t/badge_crop.png" "$t/badge_mask.png" -fx 'lu=0.299*u.r+0.587*u.g+0.114*u.b; v.r*(1-clamp((lu-0.8)/0.1))' -colorspace gray "$t/badge_glyph_alpha.png"
magick -size 260x260 xc:white "$t/badge_glyph_alpha.png" -alpha off -compose CopyOpacity -composite "$t/badge_glyph.png"

# Adaptive layout on the 108 dp canvas (1024 px): the head inside the 66 dp
# safe zone (radius 313 px) so no launcher mask clips the ears, the neck
# stretched past the bottom edge, the badge on the lower right.
LLAMA_BOX=756x1507+622+326
SCALE=0.42; TOP=240; B_CX=690; B_CY=690; B_R=58
adaptive() { # <llama.png> <badge.png> <out.png> <shadow yes|no>
  local w=756
  magick "$1" -crop $LLAMA_BOX +repage "$t/crop.png"
  magick "$t/crop.png" -crop ${w}x20+0+1454 +repage -resize ${w}x700\! "$t/neck.png"
  magick "$t/crop.png" -crop ${w}x1474+0+0 +repage "$t/head.png"
  magick -size ${w}x2174 xc:none "$t/head.png" -geometry +0+0 -composite \
    "$t/neck.png" -geometry +0+1474 -composite -filter Lanczos -resize "$(px "$w*$SCALE")"x "$t/llama_s.png"
  local sw x d
  sw=$(magick identify -format %w "$t/llama_s.png")
  x=$(px "512-$sw/2")
  d=$((B_R * 2))
  magick "$2" -filter Lanczos -resize ${d}x${d} "$t/badge_s.png"
  if [ "$4" = yes ]; then
    magick -size 1024x1024 xc:none -fill 'rgba(0,0,0,0.28)' \
      -draw "circle $B_CX,$((B_CY + 6)) $B_CX,$((B_CY + 6 - B_R))" -blur 0x10 "$t/shadow.png"
  else
    magick -size 1024x1024 xc:none "$t/shadow.png"
  fi
  magick -size 1024x1024 xc:none "$t/llama_s.png" -geometry +"$x"+$TOP -composite \
    "$t/shadow.png" -composite "$t/badge_s.png" -geometry +$((B_CX - B_R))+$((B_CY - B_R)) -composite "$3"
}

adaptive "$t/llama.png" "$t/badge.png" png/icon-foreground-1024.png yes
adaptive "$t/glyph.png" "$t/badge_glyph.png" png/icon-monochrome-1024.png no
magick -size 1024x1024 xc: -sparse-color bilinear "$(echo "$GRADIENT" | sed 's/1999/1023/g')" \
  -define png:color-type=2 png/icon-background-1024.png

# iOS: the illustration itself, opaque (App Store Connect rejects alpha);
# iOS 18 dark: the llama and badge on transparency, the system adds the dark
# background; tinted is desaturated from it by flutter_launcher_icons.
magick "$SRC" -filter Lanczos -resize 1024x1024 -alpha off -define png:color-type=2 png/icon-ios-1024.png
magick -size 2000x2000 xc:none "$t/llama.png" -composite "$t/badge.png" \
  -geometry +$((BADGE_X - 130))+$((BADGE_Y - 130)) -composite \
  -filter Lanczos -resize 1024x1024 png/icon-ios-dark-1024.png

# Android 7 (API 24-25) has no adaptive icons: the visible 72 dp of the
# adaptive layers as a rounded square. -extent composites with the current
# -compose, so it has to be reset to Over first.
magick png/icon-background-1024.png png/icon-foreground-1024.png -composite \
  -gravity center -crop 683x683+0+0 +repage -resize 940x940 "$t/legacy-tile.png"
magick -size 940x940 xc:black -fill white -draw 'roundrectangle 0,0 939,939 206,206' "$t/legacy-mask.png"
magick "$t/legacy-tile.png" "$t/legacy-mask.png" -alpha off -compose CopyOpacity -composite \
  -compose Over -background none -gravity center -extent 1024x1024 png/icon-android-legacy-1024.png

# In-app logo: the illustration as a rounded square.
magick -size 1024x1024 xc:black -fill white -draw 'roundrectangle 0,0 1023,1023 229,229' "$t/logo-mask.png"
magick png/icon-ios-1024.png "$t/logo-mask.png" -alpha off -compose CopyOpacity -composite png/logo-1024.png

# Status bar icon: the monochrome head, white on transparent, inside the
# 22 dp live area of the 24 dp icon.
magick "$t/glyph.png" -crop 756x1180+622+326 +repage -background none -gravity center \
  -extent 1180x1180 -filter Lanczos -resize 880x880 -extent 960x960 png/notification-960.png

outputs=(png/icon-*.png png/logo-1024.png png/notification-960.png)
for f in "${outputs[@]}"; do
  magick "$f" -depth 8 -strip "$f"
done
echo "Wrote ${#outputs[@]} files to png/"

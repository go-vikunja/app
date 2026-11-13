#!/usr/bin/env bash
# Builds every icon PNG in png/ from Vikunja's logo in source/.
# Needs ImageMagick 7 (`magick`, with its internal SVG renderer) and python3.
set -euo pipefail
cd "$(dirname "$0")"

SRC=source/logo.svg
BLUE='#196AFF'
mkdir -p png
t="$(mktemp -d)"
trap 'rm -rf "$t"' EXIT

px() { python3 -I -c "print(round($1))"; }

# The llama is the logo without its blue disc. The glyph is its silhouette
# with the eyes, nose, mouth and inner ears cut out, the way themed icons
# draw faces: white where the glyph is, black where it is not.
python3 -I - "$SRC" "$t" <<'PY'
import sys
import xml.etree.ElementTree as ET

src, out = sys.argv[1], sys.argv[2]
for _, (prefix, uri) in ET.iterparse(src, events=["start-ns"]):
    ET.register_namespace(prefix, uri)
PATH = "{http://www.w3.org/2000/svg}path"
DISC = "#196aff"
HOLES = {"#2c3844", "#494949", "#f1d7d4"}


def fill(path):
    for declaration in path.get("style", "").split(";"):
        key, _, value = declaration.partition(":")
        if key.strip() == "fill":
            return value.strip().lower()
    return path.get("fill", "").lower()


def write(name, recolour):
    tree = ET.parse(src)
    parents = {child: parent for parent in tree.iter() for child in parent}
    discs = [p for p in tree.iter(PATH) if fill(p) == DISC]
    if len(discs) != 1:
        sys.exit("expected one path filled %s, found %d" % (DISC, len(discs)))
    parents[discs[0]].remove(discs[0])
    if recolour:
        for path in tree.iter(PATH):
            colour = "#000000" if fill(path) in HOLES else "#ffffff"
            rest = [d for d in path.get("style", "").split(";") if d.partition(":")[0].strip() != "fill"]
            path.set("style", ";".join(["fill:" + colour] + rest))
    tree.write("%s/%s" % (out, name), xml_declaration=True, encoding="UTF-8")


write("llama.svg", False)
write("glyph.svg", True)
PY

# 256 user units at 1536 dpi: 4096 px, rendered large and scaled down.
N=4096
magick -background none -density 1536 MSVG:"$SRC" -resize ${N}x${N}\! "$t/logo.png"
magick -background none -density 1536 MSVG:"$t/llama.svg" -resize ${N}x${N}\! "$t/llama-svg.png"
magick -background black -density 1536 MSVG:"$t/glyph.svg" -resize ${N}x${N}\! \
  -alpha remove -alpha off -colorspace gray "$t/glyph-alpha.png"

# The neck ends in the disc's curve. Every icon wants it to run off the
# bottom edge, so its sides are continued as straight lines down a taller
# canvas, with the slope they have above the curve.
H=$((N * 3 / 2))
Y1=3600
Y0=3940
row() { magick "$t/llama-svg.png" -alpha extract -crop ${N}x1+0+"$1" +repage -threshold 50% -format '%@' info:; }
IFS='x+' read -r w1 _ l1 _ <<<"$(row $Y1)"
IFS='x+' read -r w0 _ l0 _ <<<"$(row $Y0)"
r1=$((l1 + w1))
r0=$((l0 + w0))
lb=$(px "$l0 + ($l0 - $l1) * ($H - $Y0) / ($Y0 - $Y1)")
rb=$(px "$r0 + ($r0 - $r1) * ($H - $Y0) / ($Y0 - $Y1)")
NECK="polygon $l0,$((Y0 - 4)) $r0,$((Y0 - 4)) $rb,$H $lb,$H"
magick -size ${N}x${H} xc:none -fill white -draw "$NECK" "$t/llama-svg.png" -composite "$t/llama.png"
magick -size ${N}x${H} xc:black -fill white -draw "$NECK" \
  \( "$t/glyph-alpha.png" -background black -extent ${N}x${H} \) -compose lighten -composite "$t/glyph-alpha-tall.png"
magick -size ${N}x${H} xc:white "$t/glyph-alpha-tall.png" -alpha off -compose CopyOpacity -composite "$t/glyph.png"

IFS='x+' read -r LW _ LX LTOP <<<"$(magick "$t/llama-svg.png" -alpha extract -threshold 50% -format '%@' info:)"

# Adaptive layout on the 108 dp canvas (1024 px), as the old Vikunja app had
# it: the head with the ears inside the 66 dp safe zone (radius 313 px), so
# no launcher mask clips them, and the neck running off the bottom edge.
FG_WIDTH=252
FG_TOP=214
adaptive() { # <in.png> <out.png>
  local w x y
  w=$(px "$N * $FG_WIDTH / $LW")
  x=$(px "512 - ($LX + $LW / 2) * $w / $N")
  y=$(px "$FG_TOP - $LTOP * $w / $N")
  magick "$1" -filter Lanczos -resize "${w}x" "$t/scaled.png"
  magick -size 1024x1024 xc:none "$t/scaled.png" -geometry "$(printf '%+d%+d' "$x" "$y")" -composite "$2"
}

adaptive "$t/llama.png" png/icon-foreground-1024.png
adaptive "$t/glyph.png" png/icon-monochrome-1024.png
magick -size 1024x1024 xc:"$BLUE" -define png:color-type=2 png/icon-background-1024.png

# iOS: the llama where the logo has it, on full-bleed blue, opaque (App Store
# Connect rejects alpha); iOS 18 dark: the same llama on transparency, the
# system adds the dark background; tinted is desaturated from it by
# flutter_launcher_icons.
magick -size ${N}x${N} xc:"$BLUE" "$t/llama.png" -composite -filter Lanczos -resize 1024x1024 \
  -alpha off -define png:color-type=2 png/icon-ios-1024.png
magick -size ${N}x${N} xc:none "$t/llama.png" -composite -filter Lanczos -resize 1024x1024 png/icon-ios-dark-1024.png

# Android 7 (API 24-25) has no adaptive icons: the visible 72 dp of the
# adaptive layers as a rounded square. -extent composites with the current
# -compose, so it has to be reset to Over first.
magick png/icon-background-1024.png png/icon-foreground-1024.png -composite \
  -gravity center -crop 683x683+0+0 +repage -resize 940x940 "$t/legacy-tile.png"
magick -size 940x940 xc:black -fill white -draw 'roundrectangle 0,0 939,939 206,206' "$t/legacy-mask.png"
magick "$t/legacy-tile.png" "$t/legacy-mask.png" -alpha off -compose CopyOpacity -composite \
  -compose Over -background none -gravity center -extent 1024x1024 png/icon-android-legacy-1024.png

# In-app logo: the round logo itself.
magick "$t/logo.png" -filter Lanczos -resize 1024x1024 png/logo-1024.png

# Status bar icon: the head of the glyph down to the top of the neck, white
# on transparent, inside the 22 dp live area of the 24 dp icon.
HEAD_HEIGHT=$((2950 - LTOP))
magick "$t/glyph.png" -crop "${LW}x${HEAD_HEIGHT}+${LX}+${LTOP}" +repage -background none -gravity center \
  -extent ${HEAD_HEIGHT}x${HEAD_HEIGHT} -filter Lanczos -resize 880x880 -extent 960x960 png/notification-960.png

# Each file keeps the colour type it was written with: the solid background
# would otherwise become a palette image.
outputs=(png/icon-*.png png/logo-1024.png png/notification-960.png)
for f in "${outputs[@]}"; do
  magick "$f" -depth 8 -strip -define png:color-type="$(magick identify -format '%[png:IHDR.color-type-orig]' "$f")" "$f"
done
echo "Wrote ${#outputs[@]} files to png/"

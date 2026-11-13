# Branding

The app is called **Vikunja** and uses Vikunja's logo, the llama on the blue disc ([D83](../docs/decisions.md#d83-successor-of-the-official-vikunja-app-in-go-vikunjaapp)). Every icon is derived from the logo's SVG by script, with the icons of the previous official Vikunja app as the look to follow.

![Preview: iOS light, dark and tinted; Android circle, squircle and teardrop masks; the themed icon in light and dark; 96 and 48 px; the status bar icon at 48 and 24 px; the in-app logo on dark and light](png/preview-sheet.png)

## Source

[`source/logo.svg`](source/logo.svg) is the only source:

- **Origin:** [go-vikunja/vikunja](https://github.com/go-vikunja/vikunja), `frontend/originalMedia/images/logo.svg`, branch `main`
- **Downloaded:** 2026-11-13, with the owner's OK; copied byte for byte
- **Size:** 12,004 bytes
- **SHA-256:** `c98852b27657462d26317d2c1318a68d4666020e1758a46d523c363446a6e80b`

`app/test/app/app_icons_test.dart` fails when the file no longer has this hash. To take a newer logo, replace the file, update the list and run the scripts below.

The SVG is 256 × 256 user units: 16 paths with solid fills, no gradients, no external references. One path is the blue disc; the others draw the llama.

## Derivation

[`build-icons.sh`](build-icons.sh) never edits the source. It writes two copies of the SVG into a temporary folder (python3's `xml.etree`), renders them with ImageMagick's own SVG renderer (`MSVG:`) at 4096 px and scales every result down with Lanczos:

- **The llama:** the logo without its blue disc.
- **The glyph** (Android themed icon, status bar icon): the llama's silhouette with the eyes, the nose and mouth and the inner ears cut out; the muzzle and the wool curls stay filled. The system tints it: dark on light in light mode, light on dark in dark mode.
- **The neck:** in the logo it ends in the disc's curve. In the icons it runs off the bottom edge: its sides are continued as straight lines with the slope they have above the curve.
- **Adaptive layout** (108 dp canvas, 1024 px), as in the old app's adaptive icon: the head 252 px wide, the tips of the ears at y = 214, the head and the ears inside the 66 dp safe zone (a circle of radius 313 px around the centre), so no launcher mask clips them.
- **iOS:** the llama where the logo has it, on full-bleed blue, as in the old app's iOS icon.
- **Status bar icon:** the glyph's head down to the top of the neck.

### Colours

| Token | Hex | Use |
|---|---|---|
| Vikunja blue | `#196AFF` | The logo's disc; the adaptive background, the iOS icon and the Play graphics |
| Wool | `#FFFFFF` | The llama |
| Curls | `#FAEEE0` | The wool curls |
| Muzzle | `#F1E6D3` | The muzzle |
| Inner ears | `#F1D7D4` | The inner ears |
| Eyes | `#2C3844` | The closed eyes |
| Nose and mouth | `#494949` | The nose and the mouth |
| Theme seed | `#1973FF` | `AppTheme.seedColor` in `app/lib/app/theme/app_theme.dart`, unchanged: the Vikunja web's primary blue ([D56](../docs/decisions.md#d56-design-after-the-owners-mockups-blue-scheme-cards-one-task-row)) |

## Files

| File | What it is |
|---|---|
| `source/logo.svg` | Vikunja's logo as downloaded; the only source |
| `build-icons.sh` | Regenerates every icon PNG in `png/` from the source (ImageMagick 7 and python3) |
| `preview.sh` | Renders `png/preview-sheet.png` from the PNGs (ImageMagick 7 and a TrueType font) |
| `build-store-graphics.sh` | Builds the two Google Play graphics below from `png/icon-ios-1024.png` and `png/icon-ios-dark-1024.png` (ImageMagick 7) |
| `png/icon-foreground-1024.png` | Android adaptive icon foreground, RGBA: 108 dp canvas, the head inside the 66 dp safe zone, the neck running off the bottom |
| `png/icon-background-1024.png` | Android adaptive icon background, RGB: solid `#196AFF` |
| `png/icon-monochrome-1024.png` | Android 13+ themed icon layer, white with alpha (only alpha counts), same layout as the foreground |
| `png/icon-android-legacy-1024.png` | RGBA: the visible 72 dp of the adaptive layers as a rounded square, for Android 7 launchers without adaptive icons |
| `png/icon-ios-1024.png` | iOS icon, RGB, **no alpha channel** (App Store requirement): the llama on full-bleed blue |
| `png/icon-ios-dark-1024.png` | iOS 18 dark icon, RGBA: the same llama at the same place on transparency (the system adds the dark background); also the source of the tinted icon |
| `png/logo-1024.png` | In-app logo, RGBA: the round logo itself, with transparent corners |
| `png/notification-960.png` | Status bar icon source: the glyph's head, white on transparent, inside the 22 dp live area |
| `png/preview-sheet.png` | Preview of every variant |
| `png/play-icon-512.png` | Google Play icon, 512 × 512, 32-bit PNG with an opaque alpha channel: the iOS icon scaled down, full bleed, because Play rounds the corners and adds the shadow itself |
| `png/feature-graphic-1024x500.png` | Google Play feature graphic, 1024 × 500, RGB without alpha: the llama of the iOS dark icon, centred and flush with the bottom, on `#196AFF`; no text, so it serves every language |

The llama of Rurana, the app's former name (`source/logo-llama.jpg`, `explorations-v1/`, `explorations-v2/`), and the "Name and logo" terms in [NOTICE.md](../NOTICE.md#name-and-logo) stay until step 38d, which settles the terms for Vikunja's name and logo; until then NOTICE.md's file table still calls the files above derivatives of that llama.

## Regenerating

```sh
./branding/build-icons.sh
./branding/preview.sh
./branding/build-store-graphics.sh
```

ImageMagick 7 renders the SVG itself; rsvg, Inkscape or cairosvg are not needed.

## Using the assets in the app

The launcher icons are wired up with `flutter_launcher_icons` (config in `app/pubspec.yaml`); the generated files are committed. After changing the PNGs:

```sh
cd app && dart run flutter_launcher_icons
```

flutter_launcher_icons 0.14.4 rewrites `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` to `AppIcon` in the Debug and Release configurations of `app/ios/Runner.xcodeproj/project.pbxproj`. Set it back to `YES` afterwards. It also writes `"scale" : "1x"` into the three universal 1024 × 1024 entries of `app/ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json`; remove the key there (the `ios-marketing` entry keeps it), or actool warns about missing 60 and 76 pt icons and leaves out `CFBundleIconFiles`. `app/test/app/xcode_project_test.dart` fails until both are fixed, and also when the set references a missing PNG or the folder holds an unreferenced one.

| Platform icon | Source |
|---|---|
| Android 8+ adaptive icon | `icon-background-1024.png` + `icon-foreground-1024.png` (`adaptive_icon_foreground_inset: 0`, the foreground already respects the safe zone) |
| Android 13+ themed icon | `icon-monochrome-1024.png` |
| Android 7 (API 24–25) legacy icon | `icon-android-legacy-1024.png` |
| iOS | `icon-ios-1024.png`, with `remove_alpha_ios: true` |
| iOS 18 dark | `icon-ios-dark-1024.png` (`image_path_ios_dark_transparent`) |
| iOS 18 tinted | `icon-ios-dark-1024.png`, desaturated by the tool (`image_path_ios_tinted_grayscale`, `desaturate_tinted_to_grayscale_ios: true`) |

The tool's scaling rounds: at hdpi a regular grid of background pixels comes out one step off `#196AFF`, which no one can see.

The connect, first-sync and notification setup screens show the logo at 72 × 72 pt from `app/assets/branding/logo.png`, and the notifications use the status bar icon from `app/android/app/src/main/res/drawable-*dpi/ic_notification.png`:

```sh
cd app
for s in 1:72 2:144 3:216; do f=${s%%:*}; px=${s##*:}; dir=assets/branding; [ "$f" != 1 ] && dir=assets/branding/$f.0x
  magick ../branding/png/logo-1024.png -filter Lanczos -resize ${px}x${px} -strip -define png:color-type=6 $dir/logo.png; done
for d in mdpi:24 hdpi:36 xhdpi:48 xxhdpi:72 xxxhdpi:96; do n=${d%%:*}; px=${d##*:}
  magick ../branding/png/notification-960.png -filter Lanczos -resize ${px}x${px} -strip -define png:color-type=6 android/app/src/main/res/drawable-$n/ic_notification.png; done
```

`app/test/app/app_icons_test.dart` checks the sizes of these files, the white status bar icon, the blue background, the opaque iOS icon and the in-app logo's transparent corners.

The old app's status bar icon was called `vikunja_notification_logo`. Since step 38b that name is an alias of `ic_notification` (`app/android/app/src/main/res/values/legacy_drawables.xml`, kept from resource shrinking by `res/raw/keep.xml`), because the old app's reminders set before the update look their icon up by it ([D85](../docs/decisions.md#d85-update-from-the-old-app-server-prefill-one-session-try-leftovers-cleared-widgets-kept); in review). The icon here keeps the name `ic_notification`, and nothing is copied.

## Open points

- **Step 38d:** the terms for Vikunja's name and logo in `NOTICE.md`, the About page and this file, and the removal of the llama files above.

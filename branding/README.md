# Branding

Name and logo of **Rurana**, an unofficial Vikunja mobile client. Its `applicationId` and bundle id are `dev.coderoftime.rurana`, renamed from `dev.coderoftime.vikunja` on 2026-11-02 ([D77](../docs/decisions.md#d77-beta-preparation-the-app-id-devcoderoftimerurana-the-owners-own-app-signing-key-every-coderoftime-project-public-a-help-row-on-the-about-page-testers-through-a-google-group-and-a-public-testflight-link)).

The name and the logo, with every image derived from it, are not under the AGPL: all rights are reserved. The files may be passed on unmodified only as part of a copy of this repository or its history, or of an unmodified build published by Benedikt Lesch; an app built from modified source uses its own name and logo. [NOTICE.md](../NOTICE.md#name-and-logo) lists the files; the scripts and the Markdown files here are under the AGPL like the rest of the repository.

The name was chosen by the owner on 2026-10-09 from the shortlist in [`explorations-v2/names.md`](explorations-v2/names.md). The logo is the illustrated llama with a check badge the owner chose on 2026-10-13 ([D42](../docs/decisions.md#d42-app-icon-the-illustrated-llama-with-a-check-badge-adaptive-themed-and-ios-18-variants-derived-by-script)); it replaced the "checkbox ears" icon of 2026-10-09, whose sources stay in [`explorations-v2/checkbox-ears/final/`](explorations-v2/checkbox-ears/final/).

![Preview: iOS light, dark and tinted; Android circle, squircle and teardrop masks; the themed icon in light and dark; 96 and 48 px; the status bar icon at 48 and 24 px; the in-app logo](png/preview-sheet.png)

## Name: Rurana

- **Home screen:** `Rurana` (6 characters)
- **Store listing:** `Rurana` in both stores and languages; never "Vikunja" in the name, subtitle or keywords (owner decision of 2026-11-02, [docs/store-listing.md](../docs/store-listing.md))
- **Store description:** must say that the app is unofficial and that the Vikunja project does not make or endorse it, and can explain the name: *"Rurana" is Quechua for "what is to be done".* No store text explains it yet; have a Quechua speaker confirm the wording before any does.

Why Rurana:
- **It leans towards Vikunja.** Quechua is the language "vicuña" (German *Vikunja*) comes from. *Rurana* is the *-na* form of *ruray* "to do": "that which is to be done" — literally a to-do.
- **No overlap with other Vikunja clients.** No *Viku-*, no *-kuna* (the earlier working name Taskuna shared that ending with the iOS client Kuna).
- **Easy to say.** EN "roo-RAH-nuh", DE "Ru-ra-na". ASCII only.
- **No conflicts found** (2026-10-09): no app in the App Store (US, DE) or on Google Play, no brand or trademark in web results, no bad meaning in EN, DE, ES or PT (ES/PT ears may hear *rana* "frog", which is harmless).

Rejected names and the reasons are in [`explorations-v2/names.md`](explorations-v2/names.md) (round 2) and in the git history of this file (round 1: Taskuna, Vicudo, Puna, Chaku, Kunja; never usable: Viku/Vicu, Kuna, Cria, anything containing "Vikunja", Llama/Vicuna/Alpaca/Guanaco).

**No formal trademark search was done** (EUIPO, DPMA, USPTO). Do one before the first store release.

## Logo: llama with a check badge

A white, front-facing llama bust with tall ears on a blue-to-teal gradient, and an orange check badge on the lower right: a camelid for Vikunja and a done task for a to-do app.

- **Source:** [`source/logo-llama.jpg`](source/logo-llama.jpg), a 2000 × 2000 px raster illustration supplied by the owner. There is no vector source; every other asset is derived from it by [`build-icons.sh`](build-icons.sh).
- **Derived layers:** the background is modelled as a four-corner gradient, so the llama comes off it with soft edges and without a blue fringe (the edge colours are un-mixed against the model); the badge is cut out as an anti-aliased disk.
- **Monochrome glyph** (Android themed icon, status bar icon): the llama silhouette with the eyes, the muzzle (keeping nose and mouth) and the inner ears cut out, and the badge as a disk with the check cut out. The system tints it: dark on light in light mode, light on dark in dark mode.
- **Risk to weigh before the store release:** an illustrated front-facing llama head is closer to Vikunja's own artwork and to other llama logos (Ollama) than the previous checkbox-ears icon was; D15's check with the Vikunja maintainers covers it.

### Colours

| Token | Hex | Use |
|---|---|---|
| Gradient top left | `#3266DE` | Background, from the source (`rgb(50,102,222)`) |
| Gradient top right / bottom left | `#2092C4` / `#1E90C2` | Background corners |
| Gradient bottom right | `#0AAFAB` | Background, teal end |
| Wool | `#F7F3ED` | The llama |
| Muzzle | `#C8C9CD` | Muzzle grey |
| Badge | `#FF8130` | Check badge |
| Theme seed | `#1973FF` | `AppTheme.seedColor` in `app/lib/app/theme/app_theme.dart` (unchanged; blue fits the gradient) |

## Files

| File | What it is |
|---|---|
| `source/logo-llama.jpg` | The logo as supplied, 2000 × 2000 px; the only source |
| `build-icons.sh` | Regenerates every PNG in `png/` from the source (ImageMagick 7 and python3) |
| `preview.sh` | Renders `png/preview-sheet.png` from the PNGs (ImageMagick 7 and a TrueType font) |
| `build-store-graphics.sh` | Builds the two Google Play graphics below from `png/icon-ios-1024.png` and `png/icon-ios-dark-1024.png` (ImageMagick 7) |
| `png/icon-foreground-1024.png` | Android adaptive icon foreground, RGBA: 108 dp canvas, the head inside the 66 dp safe zone, the neck running past the bottom, the badge on the lower right |
| `png/icon-background-1024.png` | Android adaptive icon background, RGB: the gradient |
| `png/icon-monochrome-1024.png` | Android 13+ themed icon layer, white with alpha (only alpha counts), same layout as the foreground |
| `png/icon-android-legacy-1024.png` | RGBA: the visible 72 dp of the adaptive layers as a rounded square, for Android 7 launchers without adaptive icons |
| `png/icon-ios-1024.png` | iOS icon, RGB, **no alpha channel** (App Store requirement): the illustration itself |
| `png/icon-ios-dark-1024.png` | iOS 18 dark icon, RGBA: llama and badge on transparency (the system adds the dark background); also the source of the tinted icon |
| `png/logo-1024.png` | In-app logo: the illustration as a rounded square |
| `png/notification-960.png` | Status bar icon source: the monochrome head, white on transparent, inside the 22 dp live area |
| `png/preview-sheet.png` | Preview of every variant |
| `png/play-icon-512.png` | Google Play icon, 512 × 512, 32-bit PNG with an opaque alpha channel: the iOS icon scaled down, full bleed, because Play rounds the corners and adds the shadow itself |
| `png/feature-graphic-1024x500.png` | Google Play feature graphic, 1024 × 500, RGB without alpha: the llama and the badge of the iOS dark icon, centred and flush with the bottom, on the icon's gradient; no text, so it serves every language |
| `explorations-v2/` | Round 2 of the first branding: six concepts, blind tests, the four finalists, the checkbox-ears sources, `names.md` |
| `explorations-v1/` | Round 1 (rejected) |

## Regenerating

```sh
./branding/build-icons.sh
./branding/preview.sh
./branding/build-store-graphics.sh
```

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

The connect, first-sync and notification setup screens show the logo at 72 × 72 pt from `app/assets/branding/logo.png`, and the notifications use the status bar icon from `app/android/app/src/main/res/drawable-*dpi/ic_notification.png`:

```sh
cd app
for s in 1:72 2:144 3:216; do f=${s%%:*}; px=${s##*:}; dir=assets/branding; [ "$f" != 1 ] && dir=assets/branding/$f.0x
  magick ../branding/png/logo-1024.png -filter Lanczos -resize ${px}x${px} -strip -define png:color-type=6 $dir/logo.png; done
for d in mdpi:24 hdpi:36 xhdpi:48 xxhdpi:72 xxxhdpi:96; do n=${d%%:*}; px=${d##*:}
  magick ../branding/png/notification-960.png -filter Lanczos -resize ${px}x${px} -strip -define png:color-type=6 android/app/src/main/res/drawable-$n/ic_notification.png; done
```

## Open points

- **Vikunja maintainers:** [D15](../docs/decisions.md#d15-app-id-devcoderoftimevikunja) says to check the use of the name and logo with them before the store release (step 37). The store name no longer uses "Vikunja", and since 2026-11-02 neither does the app id; the icon still leans on Vikunja's artwork, which Apple's guideline 4.1(c) ties to the other developer's approval. The check is planned in step 37d before 1.0.0: [docs/beta.md](../docs/beta.md) carries the draft message, which the owner sends; the answer is kept, as Apple accepts such an email as evidence.
- **A vector source** would keep the small sizes and the glyph crisper than a raster derivation; worth commissioning before the store release.
- **Licence:** decided with [Q3](../docs/open-questions.md#q3-licence-and-distribution) on 2026-10-27 ([D67](../docs/decisions.md#d67-agpl-30-or-later-with-an-app-store-permission-contributions-under-the-dco-the-name-and-the-logo-reserved-no-f-droid-the-legal-notices-on-an-about-page-and-the-licence-page-the-source-code-published-before-the-first-store-release)): the name and the logo are not under the AGPL, and all rights are reserved, as above and in [NOTICE.md](../NOTICE.md#name-and-logo). Still open: the owner confirms the rights to the illustration (`source/logo-llama.jpg`, supplied by the owner).

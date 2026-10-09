# Branding

Name and logo of **Rurana**, an unofficial Vikunja mobile client. Its `applicationId` and bundle id are `dev.coderoftime.vikunja`.

Chosen by the owner on 2026-10-09 from the round-2 candidates in [`explorations-v2/`](explorations-v2/README.md) (logo C, "checkbox ears") and the name shortlist in [`explorations-v2/names.md`](explorations-v2/names.md).

![Preview: iOS squircle, Android circle, rounded square and squircle masks, themed icon, at 256, 96 and 48 px; logo mark on light and dark](png/preview-sheet.png)

## Name: Rurana

- **Home screen:** `Rurana` (6 characters)
- **Store listing:** `Rurana – client for Vikunja` (de: `Rurana – Client für Vikunja`)
- **Store description:** must say that the app is unofficial and that the Vikunja project does not make or endorse it, and can explain the name: *"Rurana" is Quechua for "what is to be done".* Have a Quechua speaker confirm the wording before publishing.

Why Rurana:
- **It leans towards Vikunja.** Quechua is the language "vicuña" (German *Vikunja*) comes from. *Rurana* is the *-na* form of *ruray* "to do": "that which is to be done" — literally a to-do.
- **No overlap with other Vikunja clients.** No *Viku-*, no *-kuna* (the earlier working name Taskuna shared that ending with the iOS client Kuna).
- **Easy to say.** EN "roo-RAH-nuh", DE "Ru-ra-na". ASCII only.
- **No conflicts found** (2026-10-09): no app in the App Store (US, DE) or on Google Play, no brand or trademark in web results, no bad meaning in EN, DE, ES or PT (ES/PT ears may hear *rana* "frog", which is harmless).

Rejected names and the reasons are in [`explorations-v2/names.md`](explorations-v2/names.md) (round 2) and in the git history of this file (round 1: Taskuna, Vicudo, Puna, Chaku, Kunja; never usable: Viku/Vicu, Kuna, Cria, anything containing "Vikunja", Llama/Vicuna/Alpaca/Guanaco).

**No formal trademark search was done** (EUIPO, DPMA, USPTO). Do one before the first store release.

## Logo: checkbox ears

The llama's head is a rounded checkbox with a bold check, crowned by an apricot wool tuft and two tall banana-shaped ears: a llama for Vikunja and a checkbox for tasks.

- **Blind test** (three viewers each, no context; details in [`explorations-v2/README.md`](explorations-v2/README.md)): read as a llama/alpaca by 3 of 3, legible at 48 px by 3 of 3. Named risks: at a glance some see a bunny (long ears) or a sheep (wool tuft).
- **Why this one** among the four finalists: the most distinctive, says "to-do app" immediately, and is the furthest from the Ollama logo and generic front-facing llama heads.
- **Distinct from Vikunja's artwork:** a checkbox-shaped head instead of an illustrated face with a neck, flat geometric shapes, a gradient squircle instead of a flat circle. The lean comes from the camelid and the blue family.
- The round-1 "check-llama" was rejected because it read as a serpent (Dratini); it is kept in [`explorations-v1/`](explorations-v1/).

### Colours

| Token | Hex | Use |
|---|---|---|
| Blue light | `#3A86FF` | Gradient start (top left) |
| Blue dark | `#1252E6` | Gradient end (bottom right); colour used to flatten alpha in PNGs |
| Logo outline | `#196AFF` | Outline and check of `logo-mark.svg` (in-app logo) |
| Ink | `#163679` | Eyes and check on the icon |
| Wool | `#FFD9AE` | Tuft |
| Ears / cheeks | `#FFBFA3`, `#FFD2C2` | Inner ears, cheeks |
| White | `#FFFFFF` | Head |
| Theme seed | `#1973FF` | `AppTheme.seedColor` in `app/lib/app/theme/app_theme.dart` |

The in-app logo mark is multi-coloured and has its own outline, so it is shown unchanged on light and dark backgrounds (never tinted).

## Files

| File | What it is |
|---|---|
| `logo-mark.svg` | The mark alone on a transparent background, for in-app use (connect screen, about page). |
| `icon-foreground.svg` | Android adaptive icon foreground: 108 × 108 canvas, mark inside the central 66 dp safe zone, transparent. |
| `icon-background.svg` | Android adaptive icon background: 108 × 108 blue gradient. |
| `icon-monochrome.svg` | Android 13+ themed icon layer. Only alpha counts; the system tints it. |
| `icon-ios.svg` | iOS app icon: 1024 × 1024 full bleed, opaque. iOS applies the squircle mask. |
| `png/icon-ios-1024.png` | RGB, **no alpha channel** (App Store requirement) |
| `png/icon-foreground-1024.png` | RGBA, transparent |
| `png/icon-background-1024.png` | RGB |
| `png/icon-monochrome-1024.png` | RGBA |
| `png/icon-android-legacy-1024.png` | RGBA: the visible 72 dp of the adaptive layers as a rounded square, for Android 7 launchers without adaptive icons |
| `png/logo-mark-1024.png` | RGBA |
| `png/preview-sheet.png` | Preview of the masks, sizes, themed icon and the logo mark on light and dark |
| `explorations-v2/` | Round 2: six concepts, blind tests, the four finalists, `comparison.png`, `homescreen-mock.png`, `names.md` |
| `explorations-v1/` | Round 1 (rejected) |
| `render.sh` | Regenerates every PNG in `png/` from the SVGs |

## Regenerating the PNGs

```sh
./branding/render.sh
```

Needs the Inkscape 1.x CLI (`inkscape` on `PATH`, or `/Applications/Inkscape.app/Contents/MacOS/inkscape`; override with `INKSCAPE=...`) and ImageMagick 7 (`magick`). ImageMagick here has no librsvg delegate and its internal MSVG renderer paints gradients black, so Inkscape rasterises and ImageMagick only flattens, resizes and composes previews.

## Using the assets in the app

The icons are wired up with `flutter_launcher_icons` (config in `app/pubspec.yaml`); the generated files are committed. After changing the PNGs here:

```sh
cd app && dart run flutter_launcher_icons
```

flutter_launcher_icons 0.14.4 rewrites `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` to `AppIcon` in the Debug and Release configurations of `app/ios/Runner.xcodeproj/project.pbxproj`. Set it back to `YES` afterwards; `app/test/app/xcode_project_test.dart` fails until you do.

| Platform icon | Source |
|---|---|
| Android 8+ adaptive icon | `icon-background-1024.png` + `icon-foreground-1024.png` (`adaptive_icon_foreground_inset: 0`, the foreground already respects the safe zone) |
| Android 13+ themed icon | `icon-monochrome-1024.png` |
| Android 7 (API 24–25) legacy icon | `icon-android-legacy-1024.png` |
| iOS | `icon-ios-1024.png`, with `remove_alpha_ios: true` |

The connect screen shows the logo mark at 72 × 72 pt from `app/assets/branding/`:

```sh
cd app
magick ../branding/png/logo-mark-1024.png -filter Lanczos -resize 72x72 -strip -define png:color-type=6 assets/branding/logo_mark.png
magick ../branding/png/logo-mark-1024.png -filter Lanczos -resize 144x144 -strip -define png:color-type=6 assets/branding/2.0x/logo_mark.png
magick ../branding/png/logo-mark-1024.png -filter Lanczos -resize 216x216 -strip -define png:color-type=6 assets/branding/3.0x/logo_mark.png
```

## Open points

- **Vikunja maintainers:** [D15](../docs/decisions.md#d15-app-id-devcoderoftimevikunja) says to check the use of the name and logo with them before the store release (step 37).
- **iOS 18 icon variants:** dark and tinted variants are not made yet; the monochrome layer is a good start for the tinted one.
- **Licence:** no licence is chosen for these assets ([Q3](../docs/open-questions.md#q3-licence-and-distribution) is deferred).

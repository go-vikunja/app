# Store listings

What the app's listings on Google Play and the App Store say, every form both consoles ask, the answers and why, and what the owner still has to do (step 37c, decision D76). The answers follow the stores' own help pages, read on 2026-11-02 and linked in [Sources](#sources); where a page says nothing about an app like this one, a client of servers that other people run, the entry says so. None of this is legal advice.

The owner's decisions behind it (2026-11-02):

- The name in both stores is **Vikunja**, the official app's, since step 38a ([D15](decisions.md#d15-app-id-iovikunjaapp-and-the-name-vikunja), [D83](decisions.md#d83-successor-of-the-official-vikunja-app-in-go-vikunjaapp); in review). No text calls the app unofficial; the keywords leave out "Vikunja", which the stores index with the name.
- The reviewers use **Vikunja's public demo** (`try.vikunja.io`, account `demo`, password `demo`) through the app's "Try the public demo" ([Q21](open-questions.md#q21-a-server-for-the-store-reviewers)).
- Play's Data safety form is answered **cautiously**: what the app sends to the user's server counts as collected for app functionality, not shared; encryption in transit is "No", because plain `http` can be allowed ([D65](decisions.md#d65-connection-settings-per-server-address-applied-in-the-apps-transport)). Apple's label is "Data Not Collected".
- The app's pages are part of the owner's website, **coderoftime.dev**, until step 38f: the privacy policy, the support page, which also says how to delete an account, and the site's Impressum as the legal notice ([The website](#the-website)). The owner is a **non-trader** in both stores; the Impressum gives a c/o address; `coderoftime@gmail.com` serves Play, support, privacy, TestFlight and the written source offer.
- **No location** in Play's Data safety: the app has no location permission and never reads the device's location, and it removes the location from photos and videos from the photo picker, the camera and, on Android, shares; a location that stays in an attachment is part of content the user chose ([Data safety](#app-content)). [uncertain]
- Defaults the owner did not object to: no exact-alarm and no foreground-service declaration, target audience 18 and over, content rating for all ages (4+) with "users interact", all countries except mainland China, free without ads, purchases or donations, listings in British English and German, "Create account" kept, with the deletion steps on the support page.

## The files

The listings live in `fastlane/` in the layout of fastlane's [supply][fastlane-supply] (Play) and [deliver][fastlane-deliver] (App Store), so that an upload can be automated later. fastlane itself is not installed or run; today everything is copied into the consoles by hand. English (`en-GB`) is the default listing on both stores, German (`de-DE`) the second.

| Files | What | Limit |
|---|---|---|
| `fastlane/metadata/android/<locale>/title.txt` | Play app name | 30 characters |
| `…/short_description.txt` | Play short description | 80 characters |
| `…/full_description.txt` | Play full description | 4000 characters |
| `…/changelogs/<version code>.txt` | Play "What's new" of a release; empty for the beta | 500 characters |
| `…/images/phoneScreenshots/`, `tenInchScreenshots/` | Play screenshots, from `tool/store_screenshots.sh` | 8 per type |
| `fastlane/metadata/<locale>/name.txt` | App Store name | 30 characters |
| `…/subtitle.txt` | App Store subtitle | 30 characters |
| `…/promotional_text.txt` | App Store promotional text, changeable without a new version | 170 characters |
| `…/description.txt` | App Store description | 4000 characters |
| `…/keywords.txt` | App Store keywords, comma-separated, no spaces | 100 bytes |
| `…/release_notes.txt` | "What's New"; empty, because a first version has none | 4000 characters |
| `…/support_url.txt`, `privacy_url.txt`, `marketing_url.txt` | The app's pages on coderoftime.dev in the listing's language ([The website](#the-website)) | |
| `fastlane/metadata/copyright.txt` | `2026 Benedikt Lesch` | |
| `fastlane/metadata/primary_category.txt` | `PRODUCTIVITY` | |
| `fastlane/metadata/review_information/` | App Review: `notes.txt` (4000 bytes), `demo_user.txt` and `demo_password.txt` (`demo`, public: the demo server shows them itself), `email_address.txt` (`coderoftime@gmail.com`) | |
| `fastlane/screenshots/<locale>/` | App Store screenshots, from `tool/store_screenshots.sh`; App Store Connect sorts them by size | 10 per size |

The limits are the stores' ([Play listing][play-listing], [Play assets][play-assets], [App information][apple-app-info], [Platform version information][apple-version-info]); `tool/check_store_metadata.py` checks them:

```sh
python3 -I tool/check_store_metadata.py            # the texts, the URLs, the email and the copyright
python3 -I tool/check_store_metadata.py --strict   # before submitting: the screenshots too
```

It checks that both languages have every file and nothing else, the limits (the keywords and the review notes in bytes, as Apple counts them), that the name, subtitle and keywords name no other product or company, that `title.txt` and `name.txt` are exactly "Vikunja" and no keyword names it, that no text calls the app unofficial (step 38a, in review), that the short fields make no ranking, price or call-to-action claim and contain no emoji, that neither store's texts name the other platform ([App Review Guideline 2.3.10][apple-guidelines]), the keyword format, the category, that the URLs, the email and the copyright are those under [The website](#the-website), and every screenshot's size and alpha channel. `--strict` also fails while a store's minimum set of screenshots is missing. The checks job runs its tests (`tool/ci/test_check_store_metadata.py`), and one of them checks the committed listing.

### The website

The app's pages are part of the owner's website, https://coderoftime.dev, which the owner's separate `webpage` repository builds and publishes on GitLab Pages (its README covers the hosting and the legal texts): the privacy policy from `src/content/legal/rurana-privacy.en.md` and `.de.md`, the support pages from `src/content/support/rurana.en.md` and `.de.md`, and the Impressum, whose name, c/o address and phone come from its `src/site.config.ts`. This repository only links them:

| What | URL | Used by |
|---|---|---|
| Privacy policy | `https://coderoftime.dev/rurana/privacy/`: one page, English, then German at `#de` | `en-GB/privacy_url.txt`, Play, the About page in every language but German |
| | `https://coderoftime.dev/rurana/privacy/#de` | `de-DE/privacy_url.txt`, the About page in German |
| Legal notice | `https://coderoftime.dev/impressum/`: German first, English at `#en` | the About page: `#de` in German, `#en` in every other language; no store asks for it |
| Support | `https://coderoftime.dev/rurana/support/`, `https://coderoftime.dev/de/rurana/support/` | `support_url.txt` (en-GB, de-DE) |
| Account deletion | `https://coderoftime.dev/rurana/support/#how-do-i-delete-my-account`, the question "How do I delete my account?" (German page: "Wie lösche ich mein Konto?") | Play's deletion URL |
| Website | `https://coderoftime.dev/rurana/`, `https://coderoftime.dev/de/rurana/` | `marketing_url.txt` (en-GB, de-DE); the English one in Play's contact details |
| Email | `coderoftime@gmail.com` | `review_information/email_address.txt`, Play's developer email, App Review, TestFlight feedback, the written source offer (`tool/build_android_notices.py`) |
| Copyright | `2026 Benedikt Lesch` | `copyright.txt` (App Store) |

The About page's links are in `app/lib/app/legal.dart`, and `tool/check_store_metadata.py` holds the store values; a change goes into both and this table. The anchor of the deletion question comes from its heading, so the English heading keeps its words. Once the URLs are in the stores, they must not change.

### Texts

- **Honest:** every feature named is in the app on that platform (README "What you can do now"); nothing is "best", "new" or "free" in the short fields. The Play texts mention Android's share target, wallpaper colours and screenshot blocking; the App Store texts leave them out and name Face ID, the Home Screen and the Lock Screen instead.
- **Vikunja:** the name (`title.txt`, `name.txt`), and in the descriptions; not in the keywords, which the stores index with the name. The first paragraph of each description says that Vikunja is the open-source task manager you can run on your own server and that this is its app for the platform; `tool/check_store_metadata.py` fails on a text that calls the app unofficial and on a name other than "Vikunja" (step 38a, in review).
- **Language:** British English, unlike the app's US English since step 38a, until step 38f decides the listing's languages, and German (du), as in the [glossary](glossary.md), with the app's own names for screens and features (Overview/Überblick, Upcoming/Anstehend, Quick Add Magic, App lock/App-Sperre). The German Play text calls the exact-alarm permission by the app's own words, "genaue Alarme", because Android's German name for the system page was not checked.
- **Promotional text** (App Store only) can change at any time without a review; use it for news.

## Graphics

| Asset | File | How |
|---|---|---|
| Play icon | `branding/png/play-icon-512.png`, 512 × 512, 32-bit PNG (an opaque alpha channel), sRGB | the full-bleed iOS icon scaled down; Play rounds the corners and adds the shadow itself ([icon specification][play-icon-spec]) |
| Play feature graphic | `branding/png/feature-graphic-1024x500.png`, 1024 × 500, 24-bit PNG without alpha | the llama of the iOS dark icon, centred and flush with the bottom, on `#196AFF` ([D42](decisions.md#d42-app-icon-vikunjas-logo-every-variant-derived-by-script); in review); no text, so one graphic serves both languages ([assets][play-assets]) |
| App Store icon | none to upload | App Store Connect takes the 1024 × 1024 icon from the build's asset catalogue |

`branding/build-store-graphics.sh` makes both Play graphics from the icons in `branding/png/` (see [branding/README.md](../branding/README.md)).

## Screenshots

**Motifs** (`tool/store_screenshots.sh --list`), each in English and German:

| Form | Motifs |
|---|---|
| Phone | 01 Overview, 02 a project's list (Work / Arbeit), 03 its Kanban board, 04 the task detail (Fix the dishwasher / Spülmaschine reparieren, its sheet pulled up and at its top: the title, the date, priority, progress and label; its checklist does not fit beside the title in 16:9), 05 the New task sheet, 06 Upcoming (scrolled to the end of its list: the days after tomorrow, one after the other, without repeating the Overview and with the New task button over empty space) |
| Tablet | 01 the Overview with Fix the dishwasher / Spülmaschine reparieren in the pane beside it, 02 Work / Arbeit's Kanban board with its three columns, 03 Upcoming with Prepare the 1:1 with Lena / 1:1 mit Lena vorbereiten in the pane, 04 Work / Arbeit's list with Finish the quarterly report / Quartalsbericht fertigstellen in the pane; four, because Google promotes an app on large screens only with at least four. *Note 2026-11-10, step 36g ([D82](decisions.md#d82-projects-listdetail-the-project-tree-beside-the-project-on-wide-windows)): 02 and 04 were taken on 2026-11-03, before the project tree's column; retaken at this size, they show the tree beside the project.* |

**Devices and sizes:**

| Store | Device | Size | Rule |
|---|---|---|---|
| Play phone | a Pixel 9 emulator from a Google Play system image (1080 × 2424), window set to 16:9 by the script | 1080 × 1920 | 2–8 screenshots; JPEG or 24-bit PNG without alpha; sides 320–3840 px, the long side at most twice the short one; at least 4 of at least 1080 px for promotion ([assets][play-assets]) |
| Play tablet (optional) | a Pixel Tablet emulator from a Google Play system image (2560 × 1600), 16:9 by the script | 2560 × 1440 | sides 1080–7680 px; Google promotes large screens with at least 4 |
| App Store iPhone 6.9" | iPhone 17 Pro Max simulator | 1320 × 2868 | no alpha, 1–10 per size and language ([screenshot specifications][apple-screenshots]) |
| App Store iPhone 6.3" | iPhone 17 Pro simulator | 1206 × 2622 | Apple's page names this size as required in its text and the 6.9" one in its table, so both are uploaded |
| App Store iPad 13" | iPad Pro 13-inch simulator | 2064 × 2752 | required, because the app runs on iPad |

**The session** (the owner signs in once per device; everything else can be scripted):

1. Start the local test server and create both test users: `docker-compose -f test_servers/docker-compose.yaml up -d`, `tool/wait_for_test_servers.sh`, `tool/seed_e2e_user.sh`, `E2E_USER_ENV=test_servers/seed/e2e-user-2.env tool/seed_e2e_user.sh`.
2. Seed the demo data: `python3 -I tool/seed_demo_data.py --lang en`. The English and the German set have the same projects, labels, tasks, saved filter and board; `--reset --lang de` replaces one with the other on the same account, so nobody has to sign in again. Dates are relative to the moment of seeding, so seed shortly before.
3. On each device, sign in to `http://localhost:34527` with the E2E user (the Android emulator needs `adb reverse tcp:34527 tcp:34527`, and a Google Play system image: the sign-in goes through the browser, and an AOSP image has only the WebView Browser Tester, without Custom Tabs) and wait for the first sync. Light mode, the app's language set to the listing's (Android 13 and later: `adb shell cmd locale set-app-locales io.vikunja.app --locales en-GB`; iOS: the app's language in Settings).
4. Run `tool/store_screenshots.sh android <emulator serial> <en-GB|de-DE> <phone|tablet>` or `tool/store_screenshots.sh ios <simulator UDID> …`. It refuses anything but an emulator (`emulator-<port>` that reports itself as one) or a booted simulator. It sets a clean status bar: a full battery and Wi-Fi, no notifications, on Android no mobile signal and the 24-hour clock (Android's SystemUI demo mode; `xcrun simctl status_bar … override` on iOS), and at each shot the device's own time, which the Overview's greeting and the due times follow; on Android also a 16:9 window, then asks for one motif after the other; open the motif and press Enter, `s` skips, `q` ends. Each screen is saved without alpha under the paths above. On exit, also after Ctrl-C or an error, it ends the demo mode and restores the clock format, the window size and the density, or clears the status bar. `--no-wait` with motif names takes them at once, for a device that already shows them.
5. Pull to refresh after a `--reset`, set the app's language, then take the other language. A page of a project the reset deleted says it is gone; go back to the list. Quick Add Magic knows only English words, so the German New task sheet gets its date from the date row („Morgen“) instead of the title.
6. `python3 -I tool/check_store_metadata.py`, then look at every screenshot: no stranger's data, nothing but the app's own screens (no web sign-in page with Vikunja's branding), German screens with German data.

## Google Play Console

Play shows the developer's legal name, the developer email and the country on the listing of a personal account ([developer identity][play-identity]).

### Store presence

| Form | Answer | Why |
|---|---|---|
| Main store listing | the files above: en-GB default, de-DE added as a translation; icon, feature graphic, phone (and tablet) screenshots | [Listing][play-listing], [assets][play-assets] |
| Store settings › App category | App, Productivity | a task manager |
| Store settings › Contact details | email: `coderoftime@gmail.com`; website: `https://coderoftime.dev/rurana/`; no phone | the email is required and shown; the website is recommended ([listing][play-listing]) |
| Privacy policy | `https://coderoftime.dev/rurana/privacy/` (one URL; the page holds the English and the German text) | public, not a PDF, names the app; also linked on the app's About page ([User Data policy][play-user-data]) |
| Countries and pricing | all countries; free; no in-app products | owner decision; a free app cannot become paid later |

### App content

| Declaration | Answer | Why and source |
|---|---|---|
| App access | "All or some functionality is restricted", with the instructions below | Sign-in details must work at any time, from anywhere, in English, without two-factor ([sign-in details][play-sign-in]) |
| Ads | No | no ads, no house ads ([app content][play-app-content]) |
| Content rating | the IARC answers below | apps without a rating are removed ([content ratings][play-content-rating]) |
| Target audience and content | 18 and over only; the listing does not appeal to children; "Restrict minor access" off | any younger group brings the Families policy ([target audience][play-target-audience]) |
| News apps | No | not a news app ([news][play-news]) |
| Data safety | the answers below | every app completes it ([Data safety][play-data-safety]) |
| Government apps | No | [government apps][play-government] |
| Financial features | "My app doesn't provide any financial features" | required of every app, closed tests included ([financial features][play-financial]) |
| Health apps | "My app does not have any health features" (confirm the label) | required of every app ([health][play-health]) |
| Advertising ID | No | the merged manifest has no `com.google.android.gms.permission.AD_ID` |
| Foreground service permissions | nothing to declare | Only the workmanager plugin brings `SystemForegroundService`, with the type `shortService`, which is not among the types Play asks about ([foreground services][play-fgs], [service types][android-fgs-types]); the app never runs expedited work, so the service never starts (`workmanager_background_scheduler.dart`). If the Console still asks, say exactly that. |
| Exact alarms | no declaration | Play's declaration is for `USE_EXACT_ALARM`, which only alarm, timer and calendar apps may use; the app uses `SCHEDULE_EXACT_ALARM`, which the user grants on Android's "Alarms & reminders" page and which needs no declaration ([permissions policy][play-permissions], [scheduling alarms][android-alarms]). If the Console asks after the upload: the app is not an alarm or calendar app, it asks the user for the permission and falls back to inexact alarms without it. This corrects D17 and D39, which expected a declaration. |
| Full-screen intent, photo and video permissions | none | no `USE_FULL_SCREEN_INTENT`, no `READ_MEDIA_*` in the merged manifest; photos come through the system's photo picker |
| Trader status (EEA and UK) | Non-trader | free, no ads, no purchases, no donations, a private project; Google's own example of a hobby is "unlikely" to be a trader ([trader status][play-trader]). New accounts declare it when the account is created; from 2027-03-01 Play shows traders' address and phone. The status must change if the app is ever monetised. |

**App access instructions** (Play, English):

- Name: Public demo server. Username: `demo`. Password: `demo`.
- Any other instructions: "The app is a client for Vikunja servers; it has no accounts of its own. Open the app, tap "Try the public demo" (https://try.vikunja.io, run by the Vikunja project), then "Continue to sign-in", and sign in on the server's page with demo / demo. The account is shared and the server is reset at irregular intervals, so tasks from other visitors may appear, or none; "New task" on the Overview creates one. Content lives on the user's own server and is visible only to people they share a project with; its operator moderates it."

**Content rating** (IARC; the questions' wording is from the research, confirm it in the Console):

| Question | Answer |
|---|---|
| Category | Utility, Productivity, Communication or Other |
| Violence, fear, sexuality, nudity, language, drugs, alcohol, tobacco, gambling, crude humour, hate | No |
| Users can interact or exchange content | Yes: comments, @mentions, shared projects and attachments among the people on one server |
| Shares the user's location | No: the app has no location permission, never reads the device's location and has no feature that shares a location; only an attachment the user chose can still carry one in its metadata, in the cases "Why no location" names (see Data safety) |
| Digital purchases | No |
| Unrestricted internet or browser | No: links open in the external browser |

Expected: PEGI 3, USK 0, ESRB Everyone, with "Users interact", like the old Vikunja app's and Nextcloud's. Play's UGC policy asks apps with user content for reporting and blocking ([UGC][play-ugc]); the app has no public content and no discovery of strangers, and the server's operator moderates, which the instructions say. If review asks for more, a "report to whoever runs the server" action is the fallback.

**Data safety:**

| Data type | Collected | Shared | Optional | Purpose | In the app |
|---|---|---|---|---|---|
| Personal info › Name | yes | no | yes | App functionality | the display name, changeable in Account settings |
| Personal info › User IDs | yes | no | no | App functionality | usernames and user ids in every request, share, assignment and mention |
| Photos and videos › Photos, Videos | yes | no | yes | App functionality | attachments and the avatar; their location is removed where the app can (see "Why no location") |
| Files and docs | yes | no | yes | App functionality | attachments, uploaded unchanged; on Android a photo or video shared into the app loses its location where the app can remove it, whatever type the other app gave it; a document that embeds a photo, such as a PDF, keeps that photo's (see "Why no location") |
| Messages › Other in-app messages | yes | no | yes | App functionality | comments and reactions |
| App activity › Other user-generated content | yes | no | no | App functionality | tasks, projects, descriptions, labels, saved filters, teams |

- **Why "collected":** Google counts any transmission off the device as collection, with no exception for a server the user chooses; its closest FAQ, uploads to the user's own cloud drive, needs the app never to access the data, which a task client does. Over-declaring breaks no rule, under-declaring does ([Data safety][play-data-safety]). The privacy policy says that the developer receives none of it.
- **Why not "shared":** what reaches other people (shared projects, comments, assignments) goes there through the user's own action on the user's server, which Google exempts.
- **Purpose:** App functionality only; Account management means an account with the developer.
- **Why no location:** the app has no location permission and never reads the device's location. On Android and iOS it removes the location from photos and videos the user picks in the photo picker or takes with the camera, and on Android also from photos and videos shared into the app from another app, before they are stored for upload. On Android it writes a JPEG, PNG or WebP again without its GPS tags and otherwise blanks the GPS values, GPS in XMP and a video's location boxes in place, as Android's own MediaProvider does for apps without the media location permission, without encoding or remuxing anything; the zeros left behind are no location, though some apps show a zeroed photo at 0° N, 0° E. Where it cannot, the file is uploaded with its location, as the privacy policy says: on Android for example a location that a video records in a track of its own (action cameras, dashcams), the video in a motion photo and further images after a photo's first, place names such as the city or the country, a location in a camera maker's own metadata or in compressed metadata, and formats the app does not read (GIF, WebM, MKV); on iOS photos and videos the system cannot copy that way. A file picked with the file picker ("as a file") is uploaded unchanged and can contain a location if the file has one. What stays is content the user chose to attach, declared under Photos and videos or Files and docs (owner decision of 2026-11-02); whether Google counts location metadata inside user-chosen media as location data is not stated anywhere. [uncertain]
- **Not declared:** device or other ids (the User-Agent names only the app and the system), app info and performance (no crash reporting or analytics), contacts, calendar, audio, health, financial info, web browsing. **Email address** is not declared either: the app never sends the user's own address (sign-in and email changes happen on the server's web pages); only a typed address of someone else, when looking people up to share with, reaches the server as a search. Declaring "Email address, optional" costs nothing if the owner prefers. [uncertain]
- **Security practices:** data encrypted in transit: **No** (the user can allow plain `http` for a server). Users can request deletion: **Yes**.
- **Account creation:** the app lets users create an account, because "Create account" leads to the server's registration ([account deletion][play-account-deletion]): username and password, and OAuth where the server offers a sign-in provider (confirm the labels). Deletion URL: `https://coderoftime.dev/rurana/support/#how-do-i-delete-my-account` (the support page's question, also on the German page); in the app: Account tab › Account settings › Delete account, which opens the server's own deletion page. Deleting some data without the account: Yes (tasks, comments, attachments).

### Testing and production

A personal account created after 13 November 2023 needs a closed test with at least 12 testers opted in for 14 days in a row before it can apply for production ([testing][play-testing]); that is step 37d. The closed test needs the whole setup above, its listing with screenshots included ([testing tracks][play-test-tracks]). The settings ([D77](decisions.md#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers); [beta.md](beta.md#the-closed-test-on-google-play) has the steps and the production application's draft answers):

| Setting | Answer |
|---|---|
| Testers | a Google Group that the owner creates; testers join it, then opt in |
| Opt-in link | `https://play.google.com/apps/testing/io.vikunja.app`, shown once the app's status is Published |
| Feedback URL or email | `coderoftime@gmail.com`, shown on the opt-in page |
| Countries | as for production (all), the track kept in sync with it |
| Release notes | none for the first beta (`changelogs/` stays empty); a line on what changed for each later one, typed in the Console |
| Internal testing | optional, before the closed test; its testers do not count among the closed test's 12 |

## App Store Connect

The seller is the owner's legal name; individual members cannot use another name ([enrolment][apple-enroll]).

| Form | Answer | Why and source |
|---|---|---|
| App information › Name, subtitle | from `fastlane/metadata/<locale>/` | [App information][apple-app-info] |
| App information › Category | Productivity; no secondary category | |
| App information › Content rights | Yes, it accesses third-party content (the user's own server), and the rights to it exist | the content is the user's own [uncertain: the question's exact wording] |
| App information › Age rating | the answers below, 4+ | |
| App Privacy › Privacy policy URL | per language: `https://coderoftime.dev/rurana/privacy/`, `https://coderoftime.dev/rurana/privacy/#de` | required for iOS ([Manage app privacy][apple-manage-privacy]); also linked on the About page ([Guideline 5.1.1(i)][apple-guidelines]) |
| App Privacy › Data collection | "No, we do not collect data from this app" | below |
| Pricing and availability | free; all countries and regions except China mainland | China mainland needs an ICP filing number, unrealistic for a private person ([China mainland][apple-china], from search results) |
| DSA trader status | "not a trader" | Apple's own example: a hobbyist without intention to commercialise may not be a trader ([DSA][apple-dsa]). A trader's address, phone and email would show on EU product pages. |
| Export compliance | nothing per build | `ITSAppUsesNonExemptEncryption` is false in `Runner/Info.plist` ([releasing](releasing.md#export-compliance)) |
| Version › texts, URLs, screenshots, copyright | the files above; What's New stays empty for the first version | [Platform version information][apple-version-info] |
| Version › App Review information | Sign-in required: username `demo` and password `demo` in the sign-in fields (`demo_user.txt`, `demo_password.txt`), never in the notes; notes: `review_information/notes.txt`; contact: the owner's name, `coderoftime@gmail.com` and a phone number in `+49…` form (not in the repository; customers do not see it) | the credentials must not expire ([complete review][apple-complete-review]); Apple's Beta App Review asks not to put account details in the notes ([test information][apple-testflight-info]), and the same notes serve both reviews ([D77](decisions.md#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers)) |
| Accessibility Nutrition Labels | blank | A feature may be claimed only when users can complete the app's common tasks with it ([accessibility labels][apple-accessibility-labels]); Apple will require the labels for new apps and updates over time, with no date given. They stay blank until the VoiceOver and device passes of [accessibility-checklist.md](accessibility-checklist.md#3-final-ios-phase) confirm a feature ([D77](decisions.md#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers)). |

**App Privacy, "Data Not Collected":** Apple counts data as collected when it leaves the device so that the developer or the developer's third-party partners (analytics, ads, SDKs, vendors) can access it ([App privacy details][apple-privacy-details]). The app has no backend, analytics, ads, crash reporting or SDK that sends data; it talks only to the server the user enters, or to `try.vikunja.io`, which the Vikunja project runs; neither is the developer's or a partner's. The privacy manifests say the same ([releasing](releasing.md#privacy-manifests)), and Nextcloud's, Immich's and Swiftfin's labels say "Data Not Collected" too. The answer has to change if the app ever offers a server of the owner's (a preset, a button), gains crash reporting, analytics or a "send logs" feature. Play's answer differs because Google's definition has no "accessible to the developer" part.

**Account deletion (Guideline 5.1.1(v)):** "Create account" makes the rule apply; the app starts the deletion (Account settings › Delete account), explains the mailed confirmation and the three days, and opens the server's own page, which Apple allows ([offering account deletion][apple-account-deletion]). Where the server does not allow it, the row says so and points to whoever runs the server.

**Age rating** ([values and definitions][apple-age-values], [setting it][apple-age-set]):

| Question | Answer | Why |
|---|---|---|
| Parental controls, age assurance | No | |
| Unrestricted web access | No | links open in Safari; the description editor's web view has no network; the sign-in sheet shows only the server's page |
| User-generated content | No | no broad distribution: content goes only to people the user shares a project with |
| Messaging and chat | Yes | comments and @mentions between users |
| Social media | No | no feed, no discovery |
| Advertising | No | |
| Mature themes, medical or wellness, sexuality, violence, gambling, contests | None | |
| Made for Kids, override | No | |

Result: 4+.

**App Transport Security:** `NSAllowsArbitraryLoads` stays ([D8](decisions.md#d8-cleartext-only-after-the-users-consent)). Apple asks for a justification for it ([preventing insecure connections][apple-ats]); there is no field for it, so it is part of the review notes.

**TestFlight test information** ([test information][apple-testflight-info]): beta app description "The app for your Vikunja server: your tasks and projects offline, with reminders, widgets and Kanban boards. Sign in to your own Vikunja server or try the public demo. Please report problems with Help and bug reports on the About page, through TestFlight or by email."; feedback email: `coderoftime@gmail.com`; the Beta App Review gets the same sign-in information, in its own fields, and the same notes as App Review. External testers come through a group with a public link and a tester limit ([external testers][apple-testflight-external], [D77](decisions.md#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers)); each build added to the group gets its What to Test, for beta.1 the texts of [beta.md](beta.md#what-to-test-for-beta1).

## The reviewers' server

Both stores review with Vikunja's public demo: "Try the public demo", then `demo` / `demo` on the server's page. The demo server shows these credentials itself, so they are not secret. Its message says it is reset at irregular intervals, Vikunja's privacy policy speaks of deleting demo data every 24 hours, and anyone can change the shared account. The notes therefore say that the account may be empty or hold other visitors' tasks, and ask the reviewers not to delete it: they could not finish anyway, because the confirmation goes to the demo account's email address. The risk: if the demo is down or changes its account during a review, the review fails, and Play wants credentials that work at any time ([sign-in details][play-sign-in]). The fallback is Q21's own server with a review account seeded by `tool/seed_demo_data.py`, kept off the app's screens so that Apple's privacy label stays true.

## Open points

- [uncertain] **Exact alarms and foreground services:** no Google page says "no declaration" outright; check App content after the first upload.
- [uncertain] **Self-hosted servers:** neither store's help pages cover Data safety, account deletion or 5.1.1(v) for clients of servers that users run; the answers above follow the general rules.
- [uncertain] **Console labels:** the IARC questions and the Data safety account-creation options are worded from the research, not from the Console.
- [uncertain] **Trader status** is a legal judgement; donations or any income would change it.
- **Name and icon** are the official app's, agreed with the Vikunja maintainers ([D83](decisions.md#d83-successor-of-the-official-vikunja-app-in-go-vikunjaapp)). Whether App Store Connect accepts the name "Vikunja" and the bundle id `io.vikunja.app` in the account that publishes the app is open ([D15](decisions.md#d15-app-id-iovikunjaapp-and-the-name-vikunja)); if Apple asks under Guideline 4.1(c), the maintainers' written agreement goes into App Review Information ([complete review][apple-complete-review]).
- **Apple's iPhone size requirement** contradicts itself on its page; hence both 6.9" and 6.3". From April 2027, builds with the iOS 27.1 SDK also need "iPhone Duo" screenshots ([screenshot specifications][apple-screenshots]).

## The owner's to-do list

In this order; [beta.md](beta.md) puts them among the rest of step 37d:

1. **c/o address and phone:** for the Impressum, an address service with authority to accept service (Zustellungsvollmacht; a P.O. box is not enough) and a phone number as the second fast contact channel; both go into `src/site.config.ts` of the `webpage` repository, where the address is not final yet.
2. **Website:** deploy the `webpage` repository to coderoftime.dev (its README, "Hosting") with the app's privacy policy and support pages, and check that every URL under [The website](#the-website) loads, with its anchor. *Done 2026-11-02: the pages are live; deploy again after the c/o address and phone.*
3. **Play Console forms:** create the app, then everything under [Google Play Console](#google-play-console): store settings and contact details, the main store listing in both languages with the graphics, the privacy policy, App access, Ads, Content rating, Target audience, News, Data safety, Government, Financial features, Health, Advertising ID, and confirm that App content asks for no foreground-service or exact-alarm declaration.
4. **App Store Connect forms:** everything under [App Store Connect](#app-store-connect): app information, category, content rights, age rating, App Privacy with the privacy policy URLs, pricing and availability, version texts and URLs, App Review information with the phone number, TestFlight test information.
5. **Trader declarations:** non-trader on Google Play (asked when the developer account is created) and "not a trader" on App Store Connect.
6. **Screenshots session:** sign in once per device (Android phone and tablet emulators, iPhone 17 Pro Max, iPhone 17 Pro, iPad Pro 13-inch simulators) to the seeded local server; the rest follows [Screenshots](#screenshots). Then `python3 -I tool/check_store_metadata.py --strict` passes.

## Sources

Read on 2026-11-02.

Google Play and Android:

[play-listing]: https://support.google.com/googleplay/android-developer/answer/9859152
[play-assets]: https://support.google.com/googleplay/android-developer/answer/9866151
[play-icon-spec]: https://developer.android.com/distribute/google-play/resources/icon-design-specifications
[play-metadata]: https://support.google.com/googleplay/android-developer/answer/9898842
[play-impersonation]: https://support.google.com/googleplay/android-developer/answer/9888374
[play-identity]: https://support.google.com/googleplay/android-developer/answer/10841920
[play-user-data]: https://support.google.com/googleplay/android-developer/answer/10144311
[play-data-safety]: https://support.google.com/googleplay/android-developer/answer/10787469
[play-account-deletion]: https://support.google.com/googleplay/android-developer/answer/13327111
[play-app-content]: https://support.google.com/googleplay/android-developer/answer/9859455
[play-sign-in]: https://support.google.com/googleplay/android-developer/answer/15748846
[play-content-rating]: https://support.google.com/googleplay/android-developer/answer/9898843
[play-ugc]: https://support.google.com/googleplay/android-developer/answer/9876937
[play-target-audience]: https://support.google.com/googleplay/android-developer/answer/9867159
[play-news]: https://support.google.com/googleplay/android-developer/answer/16189314
[play-government]: https://support.google.com/googleplay/android-developer/answer/9514050
[play-financial]: https://support.google.com/googleplay/android-developer/answer/13849271
[play-health]: https://support.google.com/googleplay/android-developer/answer/14738291
[play-fgs]: https://support.google.com/googleplay/android-developer/answer/13392821
[android-fgs-types]: https://developer.android.com/develop/background-work/services/fgs/service-types
[play-permissions]: https://support.google.com/googleplay/android-developer/answer/16558241
[android-alarms]: https://developer.android.com/develop/background-work/services/alarms
[play-trader]: https://support.google.com/googleplay/android-developer/answer/17594752
[play-testing]: https://support.google.com/googleplay/android-developer/answer/14151465
[play-test-tracks]: https://support.google.com/googleplay/android-developer/answer/9845334

- [Store listing text and contact details][play-listing], [preview assets][play-assets], [icon specification][play-icon-spec], [Metadata policy][play-metadata], [Impersonation][play-impersonation], [developer identity][play-identity]
- [User Data policy][play-user-data], [Data safety][play-data-safety], [account deletion][play-account-deletion], [App content][play-app-content], [sign-in details for review][play-sign-in]
- [Content ratings][play-content-rating], [UGC][play-ugc], [target audience][play-target-audience], [news][play-news], [government][play-government], [financial features][play-financial], [health][play-health]
- [Foreground services][play-fgs], [service types][android-fgs-types], [permissions and exact alarms][play-permissions], [scheduling alarms][android-alarms], [trader status][play-trader], [testing for new personal accounts][play-testing], [testing tracks][play-test-tracks]

Apple:

[apple-guidelines]: https://developer.apple.com/app-store/review/guidelines/
[apple-app-info]: https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/
[apple-version-info]: https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/
[apple-screenshots]: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/
[apple-privacy-details]: https://developer.apple.com/app-store/app-privacy-details/
[apple-manage-privacy]: https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/
[apple-account-deletion]: https://developer.apple.com/support/offering-account-deletion-in-your-app/
[apple-complete-review]: https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review
[apple-age-values]: https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions/
[apple-age-set]: https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/
[apple-dsa]: https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/
[apple-ats]: https://developer.apple.com/documentation/security/preventing-insecure-network-connections
[apple-testflight-info]: https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/
[apple-testflight-external]: https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/
[apple-accessibility-labels]: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels
[apple-china]: https://developer.apple.com/help/app-store-connect/manage-compliance-information/view-china-mainland-compliance-information
[apple-enroll]: https://developer.apple.com/programs/enroll/

- [App Review Guidelines][apple-guidelines] (last updated 2026-10-16: 1.2, 2.1, 2.3.7, 2.3.10, 4.1(c), 4.8, 5.1.1(i) and (v))
- [App information][apple-app-info], [platform version information][apple-version-info], [screenshot specifications][apple-screenshots]
- [App privacy details][apple-privacy-details], [manage app privacy][apple-manage-privacy], [offering account deletion][apple-account-deletion], [complete review][apple-complete-review]
- [Age ratings][apple-age-values], [setting the age rating][apple-age-set], [DSA trader requirements][apple-dsa], [preventing insecure network connections][apple-ats], [TestFlight test information][apple-testflight-info], [external testers][apple-testflight-external], [Accessibility Nutrition Labels][apple-accessibility-labels], [China mainland][apple-china], [enrolment][apple-enroll]

fastlane and Vikunja:

[fastlane-supply]: https://docs.fastlane.tools/actions/supply/
[fastlane-deliver]: https://docs.fastlane.tools/actions/deliver/

- [supply][fastlane-supply] and [deliver][fastlane-deliver] for the layout
- `https://try.vikunja.io/api/v1/info` (the demo's message, demo mode, deletion allowed) and Vikunja's privacy policy, https://vikunja.io/privacy/

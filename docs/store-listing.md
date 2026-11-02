# Store listings

What Rurana's listings on Google Play and the App Store say, every form both consoles ask, the answers and why, and what the owner still has to do (step 37c, decision D76). The answers follow the stores' own help pages, read on 2026-11-02 and linked in [Sources](#sources); where a page says nothing about an app like Rurana, a client of servers that other people run, the entry says so. None of this is legal advice.

The owner's decisions behind it (2026-11-02):

- The name in both stores is always **Rurana**: never "Vikunja" in the name, the subtitle or the keywords. The descriptions say that Rurana is an unofficial app for Vikunja servers and that it is not affiliated with or endorsed by the Vikunja project.
- The reviewers use **Vikunja's public demo** (`try.vikunja.io`, account `demo`, password `demo`) through the app's "Try the public demo" ([Q21](open-questions.md#q21-a-server-for-the-store-reviewers)).
- Play's Data safety form is answered **cautiously**: what the app sends to the user's server counts as collected for app functionality, not shared; encryption in transit is "No", because plain `http` can be allowed ([D65](decisions.md#d65-connection-settings-per-server-address-in-the-apps-transport-a-certificate-pinned-in-the-tls-handshake-or-a-trusted-ca-certificate-a-client-certificate-access-headers-and-unencrypted-connections-only-with-consent-failing-closed)). Apple's label is "Data Not Collected".
- The website (privacy policy, legal notice, support, deleting your account) runs on the owner's own domain; the owner is a **non-trader** in both stores; the legal notice gives a c/o address; one new public email address serves Play, support, privacy, TestFlight and the written source offer.
- Defaults the owner did not object to: no exact-alarm and no foreground-service declaration, target audience 18 and over, content rating for all ages (4+) with "users interact", all countries except mainland China, free without ads, purchases or donations, listings in British English and German, "Create account" kept, with a deletion page on the website.

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
| `…/support_url.txt`, `privacy_url.txt`, `marketing_url.txt` | from `site/site.json` | |
| `fastlane/metadata/copyright.txt` | from `site/site.json` | |
| `fastlane/metadata/primary_category.txt` | `PRODUCTIVITY` | |
| `fastlane/metadata/review_information/` | App Review: `notes.txt` (4000 bytes), `demo_user.txt` and `demo_password.txt` (`demo`, public: the demo server shows them itself), `email_address.txt` from `site/site.json` | |
| `fastlane/screenshots/<locale>/` | App Store screenshots, from `tool/store_screenshots.sh`; App Store Connect sorts them by size | 10 per size |

The limits are the stores' ([Play listing][play-listing], [Play assets][play-assets], [App information][apple-app-info], [Platform version information][apple-version-info]); `tool/check_store_metadata.py` checks them:

```sh
python3 -I tool/check_store_metadata.py            # the texts; values still missing from site/site.json are notes
python3 -I tool/check_store_metadata.py --fill     # writes the URLs, the copyright and the email from site/site.json first
python3 -I tool/check_store_metadata.py --strict   # before submitting: every value set and current, the screenshots there
```

It checks that both languages have every file and nothing else, the limits (the keywords and the review notes in bytes, as Apple counts them), that the name, subtitle and keywords name no other product or company (Vikunja included), that the short fields make no ranking, price or call-to-action claim and contain no emoji, that neither store's texts name the other platform ([App Review Guideline 2.3.10][apple-guidelines]), that both descriptions carry the "not affiliated" line, the keyword format, the category, and every screenshot's size and alpha channel. `--strict` also fails while `site/site.json` lacks a value, while a filled file differs from it, and while a store's minimum set of screenshots is missing. The checks job runs its tests (`tool/ci/test_check_store_metadata.py`), and one of them checks the committed listing.

### Values from `site/site.json`

`site/site.json` holds the owner's values; nothing else in the repository repeats them. `--fill` writes:

| File | Value |
|---|---|
| `fastlane/metadata/<locale>/support_url.txt` | `<site_url>/<lang>/support/` (`lang` is `en` or `de`) |
| `…/privacy_url.txt` | `<site_url>/<lang>/privacy/` |
| `…/marketing_url.txt` | `<site_url>/<lang>/` |
| `fastlane/metadata/copyright.txt` | `2026 <legal_name> and the Rurana contributors` (the app's own copyright line) |
| `fastlane/metadata/review_information/email_address.txt` | `<contact_email>` |

and prints the values that Play takes in its forms: the privacy policy `<site_url>/en/privacy/`, the account deletion URL `<site_url>/en/delete-account/`, the website `<site_url>/en/` and the email.

### Texts

- **Honest:** every feature named is in the app on that platform (README "What you can do now"); nothing is "best", "new" or "free" in the short fields. The Play texts mention Android's share target, wallpaper colours and screenshot blocking; the App Store texts leave them out and name Face ID, the Home Screen and the Lock Screen instead.
- **Vikunja:** only in the descriptions and Play's short description, which is a description too ([Impersonation][play-impersonation], [Metadata][play-metadata], [Guideline 4.1(c)][apple-guidelines] for names and icons). The first paragraph of both descriptions says the app is unofficial and not affiliated with or endorsed by the Vikunja project.
- **Language:** British English and German (du) as in the [glossary](glossary.md), with the app's own names for screens and features (Overview/Überblick, Upcoming/Anstehend, Quick Add Magic, App lock/App-Sperre). The German Play text calls the exact-alarm permission by the app's own words, "genaue Alarme", because Android's German name for the system page was not checked.
- **Promotional text** (App Store only) can change at any time without a review; use it for news.

## Graphics

| Asset | File | How |
|---|---|---|
| Play icon | `branding/png/play-icon-512.png`, 512 × 512, 32-bit PNG (an opaque alpha channel), sRGB | the full-bleed iOS icon scaled down; Play rounds the corners and adds the shadow itself ([icon specification][play-icon-spec]) |
| Play feature graphic | `branding/png/feature-graphic-1024x500.png`, 1024 × 500, 24-bit PNG without alpha | the llama and the badge from the iOS dark icon on the icon's gradient; no text, so one graphic serves both languages ([assets][play-assets]) |
| App Store icon | none to upload | App Store Connect takes the 1024 × 1024 icon from the build's asset catalogue |

`branding/build-store-graphics.sh` makes both Play graphics from the icons in `branding/png/` (see [branding/README.md](../branding/README.md)).

## Screenshots

**Motifs** (`tool/store_screenshots.sh --list`), each in English and German:

| Form | Motifs |
|---|---|
| Phone | 01 Overview, 02 a project's list (Work / Arbeit), 03 its Kanban board, 04 the task detail (Fix the dishwasher / Spülmaschine reparieren, with its checklist), 05 the New task sheet, 06 Upcoming |
| Tablet | 01 the Overview with a task open in the pane beside it |

**Devices and sizes:**

| Store | Device | Size | Rule |
|---|---|---|---|
| Play phone | an Android phone emulator, window set to 16:9 by the script | 1080 × 1920 | 2–8 screenshots; JPEG or 24-bit PNG without alpha; sides 320–3840 px, the long side at most twice the short one; at least 4 of at least 1080 px for promotion ([assets][play-assets]) |
| Play tablet (optional) | the Pixel Tablet emulator, 16:9 by the script | 2560 × 1440 | sides 1080–7680 px; Google promotes large screens with at least 4 |
| App Store iPhone 6.9" | iPhone 17 Pro Max simulator | 1320 × 2868 | no alpha, 1–10 per size and language ([screenshot specifications][apple-screenshots]) |
| App Store iPhone 6.3" | iPhone 17 Pro simulator | 1206 × 2622 | Apple's page names this size as required in its text and the 6.9" one in its table, so both are uploaded |
| App Store iPad 13" | iPad Pro 13-inch simulator | 2064 × 2752 | required, because the app runs on iPad |

**The session** (the owner signs in once per device; everything else can be scripted):

1. Start the local test server and create both test users: `docker-compose -f test_servers/docker-compose.yaml up -d`, `tool/wait_for_test_servers.sh`, `tool/seed_e2e_user.sh`, `E2E_USER_ENV=test_servers/seed/e2e-user-2.env tool/seed_e2e_user.sh`.
2. Seed the demo data: `python3 -I tool/seed_demo_data.py --lang en`. The English and the German set have the same projects, labels, tasks, saved filter and board; `--reset --lang de` replaces one with the other on the same account, so nobody has to sign in again. Dates are relative to the moment of seeding, so seed shortly before.
3. On each device, sign in to `http://localhost:34527` with the E2E user (the Android emulator needs `adb reverse tcp:34527 tcp:34527`) and wait for the first sync. Light mode, the app's language set to the listing's (Android 13 and later: `adb shell cmd locale set-app-locales dev.coderoftime.vikunja --locales en-GB`; iOS: the app's language in Settings).
4. Run `tool/store_screenshots.sh android <emulator serial> <en-GB|de-DE> <phone|tablet>` or `tool/store_screenshots.sh ios <simulator UDID> …`. It refuses anything but an emulator (`emulator-<port>` that reports itself as one) or a booted simulator. It sets the status bar to 9:41 with a full battery and signal and no notifications (Android's SystemUI demo mode; `xcrun simctl status_bar … override` on iOS), on Android a 16:9 window, then asks for one motif after the other; open the motif and press Enter, `s` skips, `q` ends. Each screen is saved without alpha under the paths above. On exit, also after Ctrl-C or an error, it ends the demo mode and restores the window size and density, or clears the status bar. `--no-wait` with motif names takes them at once, for a device that already shows them.
5. Pull to refresh after a `--reset`, then take the other language.
6. `python3 -I tool/check_store_metadata.py`, then look at every screenshot: no stranger's data, nothing but Rurana's own screens (no web sign-in page with Vikunja's branding), German screens with German data.

## Google Play Console

Play shows the developer's legal name, the developer email and the country on the listing of a personal account ([developer identity][play-identity]).

### Store presence

| Form | Answer | Why |
|---|---|---|
| Main store listing | the files above: en-GB default, de-DE added as a translation; icon, feature graphic, phone (and tablet) screenshots | [Listing][play-listing], [assets][play-assets] |
| Store settings › App category | App, Productivity | a task manager |
| Store settings › Contact details | email: `contact_email`; website: `<site_url>/en/`; no phone | the email is required and shown; the website is recommended ([listing][play-listing]) |
| Privacy policy | `<site_url>/en/privacy/` (one URL; the English page links the binding German one) | public, not a PDF, names the app; also linked on the app's About page ([User Data policy][play-user-data]) |
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
| Foreground service permissions | nothing to declare | Only the workmanager plugin brings `SystemForegroundService`, with the type `shortService`, which is not among the types Play asks about ([foreground services][play-fgs], [service types][android-fgs-types]); Rurana never runs expedited work, so the service never starts (`workmanager_background_scheduler.dart`). If the Console still asks, say exactly that. |
| Exact alarms | no declaration | Play's declaration is for `USE_EXACT_ALARM`, which only alarm, timer and calendar apps may use; Rurana uses `SCHEDULE_EXACT_ALARM`, which the user grants on Android's "Alarms & reminders" page and which needs no declaration ([permissions policy][play-permissions], [scheduling alarms][android-alarms]). If the Console asks after the upload: Rurana is not an alarm or calendar app, it asks the user for the permission and falls back to inexact alarms without it. This corrects D17 and D39, which expected a declaration. |
| Full-screen intent, photo and video permissions | none | no `USE_FULL_SCREEN_INTENT`, no `READ_MEDIA_*` in the merged manifest; photos come through the system's photo picker |
| Trader status (EEA and UK) | Non-trader | free, no ads, no purchases, no donations, a private project; Google's own example of a hobby is "unlikely" to be a trader ([trader status][play-trader]). New accounts declare it when the account is created; from 2027-03-01 Play shows traders' address and phone. The status must change if the app is ever monetised. |

**App access instructions** (Play, English):

- Name: Public demo server. Username: `demo`. Password: `demo`.
- Any other instructions: "Rurana is a client for Vikunja servers; it has no accounts of its own. Open the app, tap "Try the public demo" (https://try.vikunja.io, run by the Vikunja project), then "Continue to sign-in", and sign in on the server's page with demo / demo. The account is shared and the server is reset at irregular intervals, so tasks from other visitors may appear, or none; "New task" on the Overview creates one. Content lives on the user's own server and is visible only to people they share a project with; its operator moderates it."

**Content rating** (IARC; the questions' wording is from the research, confirm it in the Console):

| Question | Answer |
|---|---|
| Category | Utility, Productivity, Communication or Other |
| Violence, fear, sexuality, nudity, language, drugs, alcohol, tobacco, gambling, crude humour, hate | No |
| Users can interact or exchange content | Yes: comments, @mentions, shared projects and attachments among the people on one server |
| Shares the user's location | No: Rurana has no location feature and never reads the device's location; only a photo or file the user attaches can carry one in its metadata |
| Digital purchases | No |
| Unrestricted internet or browser | No: links open in the external browser |

Expected: PEGI 3, USK 0, ESRB Everyone, with "Users interact", like Vikunja's own app and Nextcloud's. Play's UGC policy asks apps with user content for reporting and blocking ([UGC][play-ugc]); Rurana has no public content and no discovery of strangers, and the server's operator moderates, which the instructions say. If review asks for more, a "report to whoever runs the server" action is the fallback.

**Data safety:**

| Data type | Collected | Shared | Optional | Purpose | In Rurana |
|---|---|---|---|---|---|
| Personal info › Name | yes | no | yes | App functionality | the display name, changeable in Account settings |
| Personal info › User IDs | yes | no | no | App functionality | usernames and user ids in every request, share, assignment and mention |
| Photos and videos › Photos, Videos | yes | no | yes | App functionality | attachments and the avatar |
| Files and docs | yes | no | yes | App functionality | attachments |
| Messages › Other in-app messages | yes | no | yes | App functionality | comments and reactions |
| App activity › Other user-generated content | yes | no | no | App functionality | tasks, projects, descriptions, labels, saved filters, teams |
| Location › Precise location | yes | no | yes | App functionality | only inside attachments: on Android, files picked as files or shared to Rurana and photos from the camera app are uploaded with their metadata, which can hold where they were taken; the app itself never reads the device's location [uncertain] |

- **Why "collected":** Google counts any transmission off the device as collection, with no exception for a server the user chooses; its closest FAQ, uploads to the user's own cloud drive, needs the app never to access the data, which a task client does. Over-declaring breaks no rule, under-declaring does ([Data safety][play-data-safety]). The privacy policy says that the developer receives none of it.
- **Why not "shared":** what reaches other people (shared projects, comments, assignments) goes there through the user's own action on the user's server, which Google exempts.
- **Purpose:** App functionality only; Account management means an account with the developer.
- **Why location:** Rurana has no location permission, but D74 removes photo locations on iOS only; on Android, camera photos, files and shared files go up as they are, as the privacy policy says. Following the cautious line, the location such metadata can carry is declared; whether Google counts metadata inside a file the user chose is not stated anywhere. Leaving it out would rest on that metadata being part of the photo or file, already declared. [uncertain]
- **Not declared:** device or other ids (the User-Agent names only the app and the system), app info and performance (no crash reporting or analytics), contacts, calendar, audio, health, financial info, web browsing. **Email address** is not declared either: the app never sends the user's own address (sign-in and email changes happen on the server's web pages); only a typed address of someone else, when looking people up to share with, reaches the server as a search. Declaring "Email address, optional" costs nothing if the owner prefers. [uncertain]
- **Security practices:** data encrypted in transit: **No** (the user can allow plain `http` for a server). Users can request deletion: **Yes**.
- **Account creation:** the app lets users create an account, because "Create account" leads to the server's registration ([account deletion][play-account-deletion]): username and password, and OAuth where the server offers a sign-in provider (confirm the labels). Deletion URL: `<site_url>/en/delete-account/` (the website's page, with the German one beside it); in the app: Account tab › Account settings › Delete account, which opens the server's own deletion page. Deleting some data without the account: Yes (tasks, comments, attachments).

### Testing and production

A personal account created after 13 November 2023 needs a closed test with at least 12 testers opted in for 14 days in a row before it can apply for production ([testing][play-testing]); that is step 37d.

## App Store Connect

The seller is the owner's legal name; individual members cannot use another name ([enrolment][apple-enroll]).

| Form | Answer | Why and source |
|---|---|---|
| App information › Name, subtitle | from `fastlane/metadata/<locale>/` | [App information][apple-app-info] |
| App information › Category | Productivity; no secondary category | |
| App information › Content rights | Yes, it accesses third-party content (the user's own server), and the rights to it exist | the content is the user's own [uncertain: the question's exact wording] |
| App information › Age rating | the answers below, 4+ | |
| App Privacy › Privacy policy URL | per language: `<site_url>/en/privacy/`, `<site_url>/de/privacy/` | required for iOS ([Manage app privacy][apple-manage-privacy]); also linked on the About page ([Guideline 5.1.1(i)][apple-guidelines]) |
| App Privacy › Data collection | "No, we do not collect data from this app" | below |
| Pricing and availability | free; all countries and regions except China mainland | China mainland needs an ICP filing number, unrealistic for a private person ([China mainland][apple-china], from search results) |
| DSA trader status | "not a trader" | Apple's own example: a hobbyist without intention to commercialise may not be a trader ([DSA][apple-dsa]). A trader's address, phone and email would show on EU product pages. |
| Export compliance | nothing per build | `ITSAppUsesNonExemptEncryption` is false in `Runner/Info.plist` ([releasing](releasing.md#export-compliance)) |
| Version › texts, URLs, screenshots, copyright | the files above; What's New stays empty for the first version | [Platform version information][apple-version-info] |
| Version › App Review information | Sign-in required: `demo` / `demo`; notes: `review_information/notes.txt`; contact: the owner's name, the contact email and a phone number in `+49…` form (not in the repository; customers do not see it) | the credentials must not expire ([complete review][apple-complete-review]) |

**App Privacy, "Data Not Collected":** Apple counts data as collected when it leaves the device so that the developer or the developer's third-party partners (analytics, ads, SDKs, vendors) can access it ([App privacy details][apple-privacy-details]). Rurana has no backend, analytics, ads, crash reporting or SDK that sends data; it talks only to the server the user enters, or to `try.vikunja.io`, which the Vikunja project runs; neither is the developer's or a partner's. The privacy manifests say the same ([releasing](releasing.md#privacy-manifests)), and Nextcloud's, Immich's and Swiftfin's labels say "Data Not Collected" too. The answer has to change if the app ever offers a server of the owner's (a preset, a button), gains crash reporting, analytics or a "send logs" feature. Play's answer differs because Google's definition has no "accessible to the developer" part.

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

**App Transport Security:** `NSAllowsArbitraryLoads` stays ([D8](decisions.md#d8-cleartext-policy)). Apple asks for a justification for it ([preventing insecure connections][apple-ats]); there is no field for it, so it is part of the review notes.

**TestFlight test information** ([test information][apple-testflight-info]): beta app description "Rurana is an unofficial app for Vikunja servers: your tasks and projects offline, with reminders, widgets and Kanban boards. Sign in to your own Vikunja server or try the public demo. Please report problems by email."; feedback email: `contact_email`; the Beta App Review gets the same sign-in and notes as App Review.

## The reviewers' server

Both stores review with Vikunja's public demo: "Try the public demo", then `demo` / `demo` on the server's page. The demo server shows these credentials itself, so they are not secret. Its message says it is reset at irregular intervals, Vikunja's privacy policy speaks of deleting demo data every 24 hours, and anyone can change the shared account. The notes therefore say that the account may be empty or hold other visitors' tasks, and ask the reviewers not to delete it: they could not finish anyway, because the confirmation goes to the demo account's email address. The risk: if the demo is down or changes its account during a review, the review fails, and Play wants credentials that work at any time ([sign-in details][play-sign-in]). The fallback is Q21's own server with a review account seeded by `tool/seed_demo_data.py`, kept off the app's screens so that Apple's privacy label stays true.

## Open points

- [uncertain] **Exact alarms and foreground services:** no Google page says "no declaration" outright; check App content after the first upload.
- [uncertain] **Self-hosted servers:** neither store's help pages cover Data safety, account deletion or 5.1.1(v) for clients of servers that users run; the answers above follow the general rules.
- [uncertain] **Console labels:** the IARC questions and the Data safety account-creation options are worded from the research, not from the Console.
- [uncertain] **Trader status** is a legal judgement; donations or any income would change it.
- **The llama icon** leans on Vikunja's artwork; Apple's Guideline 4.1(c) needs the other developer's approval for a name or icon that uses theirs. The name no longer does; the icon check with the Vikunja maintainers is planned for 37d ([branding](../branding/README.md#open-points)).
- **Apple's iPhone size requirement** contradicts itself on its page; hence both 6.9" and 6.3". From April 2027, builds with the iOS 27.1 SDK also need "iPhone Duo" screenshots ([screenshot specifications][apple-screenshots]).

## The owner's to-do list

In this order:

1. **Domain and DNS:** register the domain, add it to the GitLab project's Pages (Deploy › Pages › Domains), create the DNS records GitLab names (the verification TXT record and the address record) and turn on Let's Encrypt.
2. **Email:** create the dedicated public address for Play's developer contact, support, privacy questions, TestFlight feedback and the written source offer.
3. **c/o address:** an address service with authority to accept service (Zustellungsvollmacht) for the legal notice; a P.O. box is not enough.
4. **`site/site.json`:** fill `site_url` (https, no trailing slash), `contact_email`, `legal_name`, `address_lines` and `country`; run `python3 -I tool/build_site.py --check`, `python3 -I tool/check_store_metadata.py --fill` and `python3 -I tool/build_android_notices.py` (the written offer names `contact_email`, so `app/assets/legal/android.md` changes and the `checks` job fails until it is committed), and commit `site/site.json`, the filled metadata files and `app/assets/legal/android.md` together.
5. **Play Console forms:** create the app, then everything under [Google Play Console](#google-play-console): store settings and contact details, the main store listing in both languages with the graphics, the privacy policy, App access, Ads, Content rating, Target audience, News, Data safety, Government, Financial features, Health, Advertising ID, and confirm that App content asks for no foreground-service or exact-alarm declaration.
6. **App Store Connect forms:** everything under [App Store Connect](#app-store-connect): app information, category, content rights, age rating, App Privacy with the privacy policy URLs, pricing and availability, version texts and URLs, App Review information with the phone number, TestFlight test information.
7. **Trader declarations:** non-trader on Google Play (asked when the developer account is created) and "not a trader" on App Store Connect.
8. **Screenshots session:** sign in once per device (Android phone and tablet emulators, iPhone 17 Pro Max, iPhone 17 Pro, iPad Pro 13-inch simulators) to the seeded local server; the rest follows [Screenshots](#screenshots). Then `python3 -I tool/check_store_metadata.py --strict` passes.

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

- [Store listing text and contact details][play-listing], [preview assets][play-assets], [icon specification][play-icon-spec], [Metadata policy][play-metadata], [Impersonation][play-impersonation], [developer identity][play-identity]
- [User Data policy][play-user-data], [Data safety][play-data-safety], [account deletion][play-account-deletion], [App content][play-app-content], [sign-in details for review][play-sign-in]
- [Content ratings][play-content-rating], [UGC][play-ugc], [target audience][play-target-audience], [news][play-news], [government][play-government], [financial features][play-financial], [health][play-health]
- [Foreground services][play-fgs], [service types][android-fgs-types], [permissions and exact alarms][play-permissions], [scheduling alarms][android-alarms], [trader status][play-trader], [testing for new personal accounts][play-testing]

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
[apple-china]: https://developer.apple.com/help/app-store-connect/manage-compliance-information/view-china-mainland-compliance-information
[apple-enroll]: https://developer.apple.com/programs/enroll/

- [App Review Guidelines][apple-guidelines] (last updated 2026-10-16: 1.2, 2.1, 2.3.7, 2.3.10, 4.1(c), 4.8, 5.1.1(i) and (v))
- [App information][apple-app-info], [platform version information][apple-version-info], [screenshot specifications][apple-screenshots]
- [App privacy details][apple-privacy-details], [manage app privacy][apple-manage-privacy], [offering account deletion][apple-account-deletion], [complete review][apple-complete-review]
- [Age ratings][apple-age-values], [setting the age rating][apple-age-set], [DSA trader requirements][apple-dsa], [preventing insecure network connections][apple-ats], [TestFlight test information][apple-testflight-info], [China mainland][apple-china], [enrolment][apple-enroll]

fastlane and Vikunja:

[fastlane-supply]: https://docs.fastlane.tools/actions/supply/
[fastlane-deliver]: https://docs.fastlane.tools/actions/deliver/

- [supply][fastlane-supply] and [deliver][fastlane-deliver] for the layout
- `https://try.vikunja.io/api/v1/info` (the demo's message, demo mode, deletion allowed) and Vikunja's privacy policy, https://vikunja.io/privacy/

# Releasing

How a release of Rurana is cut ([D73](decisions.md#d73-gitlab-ci-from-local-scripts-versions-from-the-tag-release-signing)). Every Android build that is distributed comes from the GitLab job `release` of a `v*` tag pipeline; no Android build is signed on a laptop. The job builds the Play bundle and one APK, signs them with keys from protected CI variables, checks them, and publishes a GitLab release with the APK, `SHA256SUMS` and the desugar_jdk_libs source. The bundle goes to Google Play by hand. The iOS build of the same tag is signed on the owner's Mac and uploaded to App Store Connect for TestFlight ([iOS](#ios-testflight-from-the-mac)). Rurana's privacy policy, legal notice and support pages are part of the owner's website, coderoftime.dev, which its own repository publishes; the website and both stores' consoles need the owner's work ([below](#the-website-and-the-store-listings)). The beta itself, from the first push to 1.0.0, follows the owner's runbook in [beta.md](beta.md) ([D77](decisions.md#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers)), which links the steps here.

## Once, before the first release

1. **The keys ([Q20](open-questions.md#q20-signing-keys-and-the-apk-beside-the-play-build), option A, decided 2026-11-02, [D77](decisions.md#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers)):** the owner creates an app signing key that only the owner holds and, when creating the Play app, uploads it to Play App Signing with PEPK ("Provide a copy of your app signing key"); a separate upload key signs the bundles; the release job signs the APK with the app signing key (the `RURANA_APK_*` set of step 5), so Play's builds and the GitLab APK share one signature and update each other. Use PKCS12 keystores with an RSA key of 4096 bits and alphanumeric passwords of 20 characters or more; a PKCS12 keystore has one password, so the key password is the store password. Keep the keystores and their passwords out of the repository (`*.p12`, `*.jks`, `*.keystore`, `*.pepk` and `*.keystore.b64` are gitignored), and a copy of the app signing key offline: a lost or leaked one cannot be replaced for APK installs ([threat model](threat-model.md) R28).

   ```sh
   keytool -genkeypair -storetype PKCS12 -keystore app-signing.p12 -alias rurana -keyalg RSA -keysize 4096 -validity 10000
   keytool -genkeypair -storetype PKCS12 -keystore upload.p12 -alias upload -keyalg RSA -keysize 4096 -validity 10000
   ```

   - **Hybrid signing:** Play now enrols new apps in "quantum-ready hybrid signing" with keys Google generates ([Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756)), and an app can change to a key of its own only until a release reaches open testing or production. Whether an uploaded key also gets hybrid signing is not documented: the owner checks it in the Console while creating the app, before the first upload, and records what it shows in a dated note on D77. If Play adds hybrid keys to the uploaded one, check before tagging that a Play install and the GitLab APK still update each other.
   - **Developer verification:** an APK installed outside Play must be signed by a key registered to a verified developer ([Android developer verification](https://developer.android.com/developer-verification/guides); certified devices in a few countries since 2026-09-30, everywhere from 2027). Creating the app in the Play Console registers its id; under option A the APK's key is the app signing key that Play already knows, so no further key needs registering. Without the `RURANA_APK_*` set the upload key would sign the APK, and that key would have to be registered too.
2. **The GitLab project** `https://gitlab.com/coderoftime/rurana` exists, private, in the group `coderoftime` (`main` pushed on 2026-10-29): push `main`.
3. **Make every project of the group `coderoftime` public** ([D77](decisions.md#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers)), each with an OSI-approved licence, as GitLab for Open Source requires of the whole group (step 11). For this project, under Settings > General > Visibility set the repository, the releases and the package registry to "Everyone With Access". The release job refuses a project that is not public and checks that anonymous users can read the repository at the tag, the releases and the package registry: the app's source link and the release's files must open for everyone (AGPL section 6). The history goes public as it is.
4. **Protect the tags `v*`** (Settings > Repository > Protected tags), with "Allowed to create" set to Maintainers.
5. **Add the signing variables** (Settings > CI/CD > Variables). Each one is Protected and has the environment scope `release`, so it reaches only the release job of a protected tag. The keystores and the passwords are also "Masked and hidden", with "Expand variable reference" off; the aliases are not secret and may be shorter than the 8 characters masking needs, so they are only Protected and scoped.

   | Variable | Value | Needed |
   |---|---|---|
   | `RURANA_UPLOAD_KEYSTORE_BASE64` | the upload keystore, `base64 < upload.p12 \| tr -d '\n'` | yes |
   | `RURANA_UPLOAD_STORE_PASSWORD` | its password | yes |
   | `RURANA_UPLOAD_KEY_ALIAS` | the key's alias | yes |
   | `RURANA_UPLOAD_KEY_PASSWORD` | the same password | yes |
   | `RURANA_APK_KEYSTORE_BASE64`, `RURANA_APK_STORE_PASSWORD`, `RURANA_APK_KEY_ALIAS`, `RURANA_APK_KEY_PASSWORD` | the APK's keystore, the same way | all four or none |

   The upload set signs the bundle. The APK set signs the APK; under option A it is the app signing key. Without it the upload key signs the APK too, and the job warns in a box in its log and says so in the release's description. Sideloaded installs stay bound to the key of their first APK for good, so set it before the first release. A missing upload set, or a partial set of either kind, stops the job before it builds.
6. **Duplicate packages (optional):** `release.sh` already refuses to upload when the package `rurana/<name>` exists. GitLab's switch that turns off duplicates for generic packages is a group setting (the group's Settings > Packages and registries > Duplicate packages, from GitLab's documentation, not yet seen on a live project), which the project gets from the group `coderoftime`; it needs the group's Owner role.
7. **Artifacts:** the bundle stays a job artifact for 30 days. "Keep artifacts from most recent successful jobs" (Settings > CI/CD > Artifacts) keeps the latest one longer; download each bundle for Play within 30 days either way.
8. **The weekly scan:** a pipeline schedule (Build > Pipeline schedules) on `main`, `23 5 * * 1` in UTC. Scheduled pipelines run the job `osv` only.
9. **The written offer's contact:** `WRITTEN_OFFER_CONTACT` in `tool/build_android_notices.py` is `coderoftime@gmail.com` since 2026-11-02 ([D76](decisions.md#d76-store-listings-and-policies-ruranas-pages-photo-locations-removed-on-android)), and `app/assets/legal/android.md` names it. After a change, run `python3 -I tool/build_android_notices.py` and commit `app/assets/legal/android.md`. The release job fails while the contact is empty.
10. **Cronet:** done on 2026-10-29: `cronet-bundled` 500.1.0, Chromium 155.0.8059.16 (D73). Keep it current as [Raising Cronet](#raising-cronet) says.
11. **Runners ([Q22](open-questions.md#q22-ci-runners-on-gitlab)):** a full pipeline is estimated at about 100–150 compute minutes on GitLab's small shared runners. GitLab.com's free 400 minutes a month count for the whole top-level group `coderoftime`, the other projects' pipelines and the website's included, so they cover at most 3 or 4 of Rurana's pipelines, and each release costs two: the push of `main`, whose pipeline must be green, and the tag's (about 200–300 minutes). Apply for [GitLab for Open Source](https://about.gitlab.com/solutions/open-source/join/) for the group once every project in it is public ([D77](decisions.md#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers)): it takes only a group whose projects are all public with an OSI-approved licence, never a personal namespace, gives 50,000 compute minutes a month at a cost factor of 0.5 ([compute minutes](https://docs.gitlab.com/ci/pipelines/compute_minutes/)), and is renewed every year with the same form by whoever applied, from three months to one month before it ends ([community programs](https://docs.gitlab.com/subscriptions/community_programs/)); that is the only remedy 37a supports. The Mac runner described below takes only the job `ios` and saves no shared-runner minutes: moving the heavy Linux jobs to the Mac would need a setup of its own that 37a does not include (tags on those jobs or a runner that takes untagged jobs, plus Docker and the Android SDK on the Mac).

## The website and the store listings

Rurana's pages are part of the owner's website, https://coderoftime.dev ([D76](decisions.md#d76-store-listings-and-policies-ruranas-pages-photo-locations-removed-on-android)): the privacy policy, the support pages, which also say how to delete an account, the project page, and the website's Impressum as the legal notice, each in English and German. The owner's own repository, `webpage`, builds them and publishes them on GitLab Pages; its README covers the hosting and the legal texts. This repository only links them: the About page through `WebsitePage` in `app/lib/app/legal.dart`, the store metadata in `fastlane/metadata/`, which `tool/check_store_metadata.py` checks against the same addresses. `coderoftime@gmail.com`, the website's contact, is Play's developer email, the support and App Review address, TestFlight's feedback address and the written offer's contact. [store-listing.md](store-listing.md#the-website) lists every address and what uses it, and every form of both consoles with its answer and the reason. Once, in this order:

1. **The Impressum's c/o address and phone:** a service with authority to accept service (Zustellungsvollmacht; a P.O. box is not enough) and a phone number as the second fast contact channel, both in `src/site.config.ts` of the website's repository, where the address is not final yet. Only the website shows them, not the stores. They are the website's last missing part, and they come before the first rollout to testers ([beta.md](beta.md#6-the-impressum)).
2. **The website is deployed:** the pages have been live on coderoftime.dev since 2026-11-02, and every address below answered that day. After a change, deploy it again as its README's "Hosting" says, then open, signed out: `https://coderoftime.dev/rurana/privacy/` and its German part at `#de`, `https://coderoftime.dev/impressum/#de` and `#en`, `https://coderoftime.dev/rurana/support/#how-do-i-delete-my-account`, `https://coderoftime.dev/de/rurana/support/`, `https://coderoftime.dev/rurana/` and `https://coderoftime.dev/de/rurana/`. Once these addresses are in the stores they must not change; the deletion URL's anchor comes from the English support page's heading "How do I delete my account?", so that heading keeps its words. A change would have to go into `legal.dart`, `check_store_metadata.py`, `fastlane/metadata/`, [store-listing.md](store-listing.md#the-website) and both consoles at once.
3. **The Play Console and App Store Connect forms,** as [store-listing.md](store-listing.md#google-play-console) answers them, with the texts of `fastlane/metadata/` copied in by hand: in the Play Console the app, the store settings and contact details, the main store listing in both languages with the graphics of `branding/png/`, the privacy policy, App access, Ads, Content rating, Target audience, News, Data safety, Government, Financial features, Health and Advertising ID, and a check that App content asks for no foreground-service or exact-alarm declaration; in App Store Connect the app information, the category, content rights, the age rating, App Privacy with both privacy policy addresses, pricing and availability, the version's texts and addresses, App Review information with a phone number (never in the repository) and TestFlight's test information.
4. **The trader declarations:** non-trader on Google Play (asked when the developer account is created) and "not a trader" on App Store Connect. Any income, donations included, would change that.
5. **The screenshot session:** start the test server with both test users, seed the demo data with `python3 -I tool/seed_demo_data.py --lang en`, sign in once on each device (the Android phone and tablet emulators, the iPhone 17 Pro Max, iPhone 17 Pro and iPad Pro 13-inch simulators), then run `tool/store_screenshots.sh` for each device and language, with `--reset --lang de` for the German data ([store-listing.md](store-listing.md#screenshots) has each step). Then `python3 -I tool/check_store_metadata.py --strict` must pass; run it again before every submission.

Nothing in this repository waits for the website: the About page links its addresses in every build, the release scripts do not look at it, and `python3 -I tool/check_store_metadata.py --strict` fails only while a store's minimum set of screenshots is missing. An empty or changed URL, email or copyright file fails the check without `--strict` too.

## Cutting a release

1. **Bump the version** (after [raising Cronet](#raising-cronet) if Google has a newer one) in `app/pubspec.yaml` to the release's name, for example `version: 1.0.0-beta.1+1`. Only the part before `+` counts; the build number comes from the tag. Run the [dry run](#the-dry-run) for the tag, `tool/ci/release.sh --dry-run --tag v1.0.0-beta.1`: it must end with only the expected reasons, `placeholder source URL`, `throwaway keys` and `project not public` (a local run has no project); `no written-offer contact` means that the contact of step 9 above is empty, and the release job would fail. Commit on `main`, push, and wait for a green pipeline before you tag.
2. **Tag and push the tag:**

   ```sh
   git tag -a v1.0.0-beta.1 -m "Rurana 1.0.0-beta.1"
   git push origin v1.0.0-beta.1
   ```

   A release tag is `vMAJOR.MINOR.PATCH` or `vMAJOR.MINOR.PATCH-beta.N`: no leading zeros, major at most 2099, minor and patch at most 99, N from 1 to 98. The version code is major × 1,000,000 + minor × 10,000 + patch × 100 + N, with 99 for the final release, so every beta comes before its release:

   | Tag | Build name | Version code |
   |---|---|---|
   | `v1.0.0-beta.1` | 1.0.0-beta.1 | 1000001 |
   | `v1.0.0-beta.2` | 1.0.0-beta.2 | 1000002 |
   | `v1.0.0` | 1.0.0 | 1000099 |
   | `v1.0.1-beta.1` | 1.0.1-beta.1 | 1000101 |
   | `v1.2.3` | 1.2.3 | 1020399 |

   `python3 -I tool/ci/release_version.py v1.0.0-beta.1` prints the name and the code, and fails for another tag or when the pubspec's version name differs. A tag that starts with `v` but is malformed fails the release job; a tag that does not start with `v` runs no pipeline.
3. **The tag pipeline** runs `checks`, `editor`, `contract`, `android` and `osv`, then `release`, which:
   - computes the version from the tag and stops on the guards: an https project URL, a public project whose repository, releases and package registry anonymous users can read, the written offer's contact, the signing variables, and no release or package of that version yet;
   - runs the release-only source-link test, then the notices' self-test and check;
   - builds the Play bundle with the upload key and one universal APK with the APK key, both with the tag's build name and version code and `SOURCE_CODE_URL` set to the project's URL, which the About page links;
   - checks the exported components, both signatures against the keys' certificates (never the debug key) and the APK's version;
   - fetches the desugar_jdk_libs source of the recorded upstream commit and checks its commit and tree;
   - uploads `rurana-<name>.apk`, `SHA256SUMS` and `desugar_jdk_libs-<version>-src.tar.gz` to the generic package `rurana/<name>` and creates the release `Rurana <name>`, with " (beta)" for a beta; its description gives the APK's SHA-256, the SHA-256 of its signing certificate and the link to the source at the tag;
   - keeps `app-release.aab` and `SHA256SUMS` as job artifacts for members with the Developer role.
4. **Check the release** on the project's Releases page: the three files open signed out, `SHA256SUMS` matches the APK, and the certificate's SHA-256 is the expected one. GitLab has no pre-release flag, so a beta becomes the project's latest release: link a specific release from the README and elsewhere, never `/-/releases/permalink/latest`.
5. **Upload the bundle to Google Play** by hand (step 37d): download `build/release/app-release.aab` from the release job's artifacts, compare its SHA-256 with the line "Bundle for Play" in the job's log, and upload it in the Play Console to the closed test for a beta or to production for a final release ([beta.md](beta.md#the-closed-test-on-google-play)).
6. **Upload the iOS build** from the Mac: [each TestFlight build](#each-testflight-build).

## Raising Cronet

The app embeds Cronet, Chromium's network stack, which only an app update brings up to date ([threat model](threat-model.md) R34). Google has published `org.chromium.net:cronet-bundled` three times in nine weeks so far (3 to 6 weeks apart), each 1 to 2.5 weeks after the Chrome stable release it is built from. Look at `https://dl.google.com/android/maven2/org/chromium/net/cronet-bundled/maven-metadata.xml` at each Chrome stable release and before each release of the app. For a newer version:

1. **Check its POM:** the licence is still "Chromium License and licenses of built-in dependencies", and the dependencies are still `cronet` and the transitional artifacts that `app/android/app/build.gradle.kts` excludes (a new one needs its own exclude; the notices refuse any other `org.chromium.net` library).
2. **Raise the version** in `build.gradle.kts`, write the locks, build the release APK once so that Gradle has the new AARs, then copy their licences:

   ```sh
   (cd app/android && ./gradlew :app:dependencies --write-locks)
   (cd app && flutter build apk --release)
   python3 -I tool/build_android_notices.py --refresh-cronet
   ```

   `--refresh-cronet` checks both AARs against the SHA-256 that Google's Maven publishes, refuses a Chromium build that Chromium Dash does not list as a Chrome stable release for Android, copies the licence files into `tool/android_notices/cronet/` and writes `app/assets/legal/android.md`. Then check `CRONET_SUPPLEMENT` in `tool/build_android_notices.py`, what the native library links statically but the licence files do not name: `strings` on the AAR's `jni/arm64-v8a/libcronet.*.so` still shows `__Cr` names (libc++), `libc++abi:`, `libunwind:` and Rust's `panicked at`, and `third_party_licenses.txt` still names none of them; a new library of that kind gets its own entry and text.
3. **Test and commit:** run the tests (`embedded_cronet_test.dart` compares the declared version with `tool/android_notices/cronet/source.json`), check the app on a device or emulator, and commit `build.gradle.kts`, `gradle.lockfile`, `tool/android_notices/cronet/` and `android.md` together.

## Raising Flutter

The Flutter engine and the Dart runtime, with its BoringSSL and HTTP stack, ship in the app, and no scan sees their advisories ([threat model](threat-model.md) R26 and section 9): read [Flutter's changelog](https://raw.githubusercontent.com/flutter/flutter/stable/CHANGELOG.md) at each stable release and before each release of the app. On 2026-11-02 that found GHSA-frr6-h895-5pxp in 3.47.8 (BoringSSL in `dart:io` blocks compromised eMudhra intermediates, and on Android 14 and later `dart:io` uses the updatable Conscrypt root store), and the pin moved from 3.47.7 to 3.47.9, which also fixes a native-assets crash of `flutter test` in pub workspaces ([D77](decisions.md#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers)). For a newer version:

1. **The pin:** in `tool/ci/pins.sh`, `FLUTTER_VERSION` and `FLUTTER_LINUX_SHA256`, the `sha256` of that version's stable Linux archive in `https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json`; the comment above them keeps the earlier pin. The README's [prerequisites](../README.md#prerequisites) name the version with its Dart, and so does [the Mac runner's line](#the-mac-as-a-runner) below.
2. **The Mac's SDK:** run `flutter upgrade` from a folder outside the repository, for example `(cd ~ && flutter upgrade)`, until `flutter --version` prints the pinned version. Run inside the repository on 2026-11-02, the command also upgraded 29 packages in the workspace's `pubspec.lock`, which had to be restored. Afterwards `git status` must show no change, and `flutter pub get --enforce-lockfile` must resolve the committed lockfile.
3. **The checks:** `tool/ci/checks.sh`, `tool/ci/test.sh`, `tool/ci/android.sh` and, on the Mac, `tool/ci/ios.sh`, then both [dry runs](#the-dry-run); commit `pins.sh` and the README together. A Mac runner needs the same version on its PATH.

## When the release job fails

- **Before the upload** (a guard, a test, the build or a check): fix the cause, for example a variable, and retry the job.
- **During or after the upload:** the package `rurana/<name>` exists without a release. Delete it (Deploy > Package registry), then retry the job.
- **To publish a release again:** delete the release in the UI and its package, then retry the job.
- A fix in the code needs a new commit and a new tag, the next beta or the next patch.

## The Mac as a runner

The job `ios` builds the iOS app unsigned on a Mac and checks the notices of its licence page ([below](#licence-notices)). It is the only job such a runner takes; the Linux jobs stay on the shared runners. To run it:

- Register the Mac as a project runner with the tag `macos`, "Run untagged jobs" off and the shell executor, so the job runs directly on the Mac.
- Run the runner under a macOS user of its own that cannot read the keystores, the owner's other files or the owner's Keychain. The job runs whatever `tool/ci/ios.sh`, `tool/ci/lib.sh`, `.gitlab-ci.yml` and the build itself (build hooks, CocoaPods, Xcode's build phases) say on the protected main branch or the tag: the job never runs in a merge request pipeline, so only reviewed and merged code runs on this Mac ([threat model](threat-model.md) R35).
- Point `xcode-select` at Xcode: `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`. `ios.sh` refuses to run otherwise, as the native-asset build hooks ignore `DEVELOPER_DIR` ([README](../README.md#prerequisites)).
- Put exactly the Flutter that `tool/ci/pins.sh` pins (3.47.9) on the runner's PATH: the runner sets `CI=true`, and there another version is an error.
- Set the project variable `RURANA_MACOS_RUNNER` to `true`.

Pipelines on main and on `v*` tags then have the job, and it must pass; merge requests and the schedule never do. Unset the variable while the Mac is away or asleep: GitLab cannot tell an absent runner from a busy one, so the pending job holds each pipeline open for up to a day and then fails it.

## The dry run

```sh
tool/ci/release.sh --dry-run                       # the tag defaults to v<the pubspec's version name>
tool/ci/release.sh --dry-run --tag v1.0.0-beta.1   # the pubspec must have that version
```

It runs the whole release locally except the upload: two throwaway keystores, valid for one day, stand in for the keys, and `https://gitlab.example/rurana` for the project's URL. The visibility and contact guards only warn. It prints the files it would upload and the release it would create, and ends with `DRY RUN: NOT RELEASABLE (…)`. It needs Flutter, the Android SDK's build-tools, a JDK and access to GitHub for the desugar_jdk_libs source; the files land in `build/release/`.

A local `flutter build apk --release` is signed with the debug key and prints a warning, unless `app/android/key.properties` (gitignored) names a keystore with `storeFile`, `storePassword`, `keyAlias` and `keyPassword`. Such builds are for testing only.

## iOS: TestFlight from the Mac

`tool/ci/ios_release.sh` builds the iOS app of a release tag on the owner's Mac, signs it with Xcode's automatic signing for the owner's team, checks it and uploads it to App Store Connect, which hands it to TestFlight and later to App Review. No GitLab job runs it yet: `.gitlab-ci.yml` keeps only the unsigned build `ios`, and the owner runs the release by hand once the tag pipeline is green. Running it from the Mac runner on a tag would need the team's signing and the API key in the runner's macOS account, which [the runner's separate user](#the-mac-as-a-runner) is meant not to have.

### Once, before the first upload

1. **The Apple Developer Program:** the account that publishes Rurana, enrolled as an individual or an organisation; the App Store shows the enrolled name as the seller. The membership is renewed every year: when it lapses, the app leaves the App Store and takes no updates.
2. **The team id:** ten capital letters and digits, under Membership details in the developer account. The script reads it from `DEVELOPMENT_TEAM`. It is not secret (every signed build carries it, and Flutter prints it while signing), but it stays out of the repository so that a fork signs with its own team.
3. **Xcode signed in, with a device:** add the account under Xcode > Settings > Accounts, and register an iPhone with the team once: connect it to the Mac with Xcode open, or add its UDID under Certificates, Identifiers & Profiles > Devices. Automatic signing archives with a development profile, which Xcode cannot create for a team without a device ("Your team has no devices from which to generate a provisioning profile"); the export then signs for distribution. Automatic signing also needs the App IDs `dev.coderoftime.rurana` and `dev.coderoftime.rurana.RuranaWidgets`, both with the App Groups capability and only the group `group.dev.coderoftime.rurana` (renamed from `dev.coderoftime.vikunja` before any of them existed, [D77](decisions.md#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers)), a distribution certificate and the profiles; Xcode creates what is missing on the first signed build (`flutter build ipa` passes `-allowProvisioningUpdates`). If it cannot, create the App IDs and the group under Certificates, Identifiers & Profiles > Identifiers.
4. **The app record:** in App Store Connect, Apps > + > New App: iOS, the name `Rurana` ([D76](decisions.md#d76-store-listings-and-policies-ruranas-pages-photo-locations-removed-on-android)), the bundle id `dev.coderoftime.rurana`, a SKU of your choice (for example `rurana`). Creating the record reserves the name, so it can come before the first build. The listing, the screenshots and the App Privacy answers: [store-listing.md](store-listing.md#app-store-connect).
5. **The API key:** the Account Holder requests API access once under Users and Access > Integrations > App Store Connect API. Then generate a team key with the Developer role (it covers delivering builds; App Manager only if Apple refuses the upload with it) and download `AuthKey_<id>.p8`; Apple offers the file only once. Keep it outside the repository (`*.p8` is gitignored) with `chmod 600`: the script refuses a key file that other users can read. It reads three variables, prints none of them and takes them out of the environment before Flutter or Xcode runs, so that only altool gets them; altool gets the file's path, never its content:

   | Variable | Value |
   |---|---|
   | `RURANA_ASC_KEY_ID` | the key's id |
   | `RURANA_ASC_ISSUER_ID` | the issuer id shown above the team keys |
   | `RURANA_ASC_KEY_FILE` | the path of `AuthKey_<id>.p8` |

6. **The source link:** `RURANA_SOURCE_CODE_URL`, the project's https URL on GitLab exactly as `CI_PROJECT_URL` gives it to the Android release, `https://gitlab.com/coderoftime/rurana` without `.git`; the About page links it ([D67](decisions.md#d67-agpl-30-or-later-with-an-app-store-permission-dco-reserved-brand-embedded-cronet)). The script checks that `<URL>/-/tree/<tag>` opens signed out.

### Each TestFlight build

After the tag pipeline is green ([cutting a release](#cutting-a-release), step 3), on the Mac:

```sh
git fetch --tags && git checkout v1.0.0-beta.1
export DEVELOPMENT_TEAM=… RURANA_ASC_KEY_ID=… RURANA_ASC_ISSUER_ID=… RURANA_ASC_KEY_FILE=…/AuthKey_….p8
export RURANA_SOURCE_CODE_URL=https://gitlab.com/…
tool/ci/ios_release.sh --tag v1.0.0-beta.1
```

The script:

- refuses to run unless `xcode-select` points to Xcode (the native-asset build hooks ignore `DEVELOPER_DIR`), Flutter is exactly the version `tool/ci/pins.sh` pins, HEAD is the tag with a clean working tree, the source link opens signed out at the tag, the team id and the three key variables are set, and the App Store icon is 1024 × 1024, RGB without an alpha channel and untagged or sRGB;
- computes the version from the tag with `release_version.py` and runs the release-only source-link test;
- builds with `flutter build ipa --release`, the tag's version, `SOURCE_CODE_URL` and generated export options: method `app-store-connect`, automatic signing, the team, and `manageAppVersionAndBuildNumber` off so that Xcode never changes the version;
- checks the archived `Runner.app` and `RuranaWidgets.appex`: both carry the tag's version, the app declares `ITSAppUsesNonExemptEncryption` false, both privacy manifests are the committed ones, every required-reason API that a binary in them uses is declared (`tool/ci/required_reason_apis.py`, [below](#privacy-manifests)), and the licence page has every notice (`tool/ci/ios_notices.py`, [below](#licence-notices));
- requires exactly one IPA, since `flutter build ipa` reports success even when the export fails, prints its SHA-256 and uploads it with `xcrun altool --upload-package` and the key.

App Store Connect takes only `MAJOR.MINOR.PATCH` as the version (`CFBundleShortVersionString`), so every beta of a release has the release's version and the Android version code as its build number (`CFBundleVersion`), which grows with every tag:

| Tag | Version | Build |
|---|---|---|
| `v1.0.0-beta.1` | 1.0.0 | 1000001 |
| `v1.0.0-beta.2` | 1.0.0 | 1000002 |
| `v1.0.0` | 1.0.0 | 1000099 |
| `v1.0.1-beta.1` | 1.0.1 | 1000101 |

On iOS the app therefore reports 1.0.0 with the build number for every beta of 1.0.0, for example the User-Agent `Rurana/1.0.0+1000002`. A build number goes to App Store Connect only once per version, even when processing fails, and a version released in the App Store takes no more builds: a fix needs the next tag, as on Android.

The build shows up under TestFlight in App Store Connect after processing; Apple emails a problem found while processing, for example a missing API declaration. Internal testers (members of the team in App Store Connect) can install it at once; external testers, by invitation or a public link, only after Beta App Review has passed the first build of a version, which needs the test information of [store-listing.md](store-listing.md#app-store-connect): the public demo's account `demo` / `demo` in the sign-in fields, never in the notes, and the review notes ([Q21](open-questions.md#q21-a-server-for-the-store-reviewers)). The external group, its public link and each build's What to Test: [beta.md](beta.md#testflight).

### The iOS dry run

```sh
tool/ci/ios_release.sh --dry-run                       # the tag defaults to v<the pubspec's version name>
tool/ci/ios_release.sh --dry-run --tag v1.0.0-beta.1   # the pubspec must have that version
```

It builds the archive unsigned (`--no-codesign`) with the same checks, the licence notices included, and stops before the export and the upload. Without `RURANA_SOURCE_CODE_URL` it uses `https://gitlab.example/rurana`. The tag, the clean tree, the team id, the key variables, Flutter's version and an undeclared required-reason API only warn; it needs neither the Apple account nor the key, and checks them when they are set. It prints the export options it would use and ends with `DRY RUN: NOT RELEASABLE (unsigned build, …)`.

### Export compliance

`ITSAppUsesNonExemptEncryption` is `false` in `Runner/Info.plist`, so App Store Connect asks no encryption questions for each build. The extension needs no such key; App Store Connect reads the app's. The app uses encryption only through standard protocols: HTTPS through the system's `URLSession`, and for servers with a pinned certificate, a private CA or a client certificate the TLS of Dart's `dart:io` (BoringSSL in the Flutter engine, [D65](decisions.md#d65-connection-settings-per-server-address-applied-in-the-apps-transport)); the Keychain for tokens and secrets; SHA-256 for PKCE, account ids and certificate fingerprints. None of it is proprietary encryption, which is what Apple counts as exempt from the export documentation. Apple's page adds that an app with exempt encryption may still owe the U.S. government a year-end self-classification report: check that once before the App Store release (step 37d). If App Store Connect asks anyway, the answer is that the app uses only exempt encryption. *Note 2026-11-02, step 37d ([D77](decisions.md#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers)): checked for the United States: since BIS's rule of 29 March 2021 ([86 FR 16482](https://www.federalregister.gov/documents/2021/03/29/2021-05481/export-administration-regulations-implementation-of-wassenaar-arrangement-2019-plenary-decisions)) the annual report covers only mass-market components and executable software ([15 CFR 740.17(e)(3)](https://www.law.cornell.edu/cfr/text/15/740.17)), not an end-user app that uses only standard encryption, so none is due. France is open ([Q23](open-questions.md#q23-french-encryption-declaration-for-the-app-store)): Apple's [table](https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption/) asks for a French encryption declaration for an industry-standard algorithm that the operating system does not provide, which BoringSSL in the Flutter engine is ([beta.md](beta.md#before-100)). Neither is legal advice.*

### Privacy manifests

`Runner/PrivacyInfo.xcprivacy` and `RuranaWidgets/PrivacyInfo.xcprivacy` sit at the root of the app and of the extension, each in its target's resources (`tool/add_widget_extension.rb` adds them; rerun it after renaming either). Both say no tracking, no tracking domains and no collected data: Apple counts data as collected when it leaves the device in a way that the developer or the developer's partners can access, and Rurana sends data only to the Vikunja server the user chooses. That is usually the user's own or their organisation's; the onboarding's "Try the public demo" fills in `https://try.vikunja.io`, which the Vikunja project runs, but the user picks it, and the developer has no access to it and no partnership with its operator. The app has no analytics, crash reporting or advertising SDK. App Store Connect's App Privacy answer, "Data Not Collected", rests on the same reasoning ([store-listing.md](store-listing.md#app-store-connect)).

The required-reason APIs, from the code and from the symbols the release binaries import (`nm -u`), checked against [Apple's list](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api) on 2026-10-29:

| Bundle | Category | Reason | Why |
|---|---|---|---|
| `Runner.app` | File timestamp | `C617.1` | Timestamps and sizes of files in the app container and the App Group container: the attachment cache pruned by modification date (`dart:io` `stat`, which the Flutter engine declares as a wrapper, `0A2A.1`), package_info_plus reading the creation date of the app's Documents folder and the modification date of the app bundle (its own manifest declares nothing), picked files copied into the container |
| `Runner.app` | User defaults | `CA92.1` | The app's own preferences through shared_preferences in the standard defaults; no App Group defaults |
| `RuranaWidgets.appex` | File timestamp | `C617.1` | The extension prunes its list selections by the modification date of files in the App Group container |

Not declared: system boot time (Dart's `Stopwatch` reads `clock_gettime_nsec_np`, which is not on the list; the engine declares its own `systemUptime`), disk space and active keyboards. Apple asks the bundle that holds a binary to declare its APIs, so a framework needs a manifest of its own. The extension uses no user defaults. The plugin `rurana_widgets` uses none of these APIs; its Swift code is linked into the Runner and has no manifest of its own.

The plugins the app links bring their manifests as resource bundles inside the app: file_selector_ios, flutter_secure_storage_darwin, image_picker_ios, local_auth_darwin, package_info_plus, quick_actions_ios, share_plus, url_launcher_ios and webview_flutter_wkwebview declare no tracking, no collected data and no API; flutter_local_notifications and workmanager_apple declare user defaults `CA92.1`; shared_preferences_foundation declares user defaults `1C8F.1`; `Flutter.framework` declares file timestamp `0A2A.1` and `C617.1` and system boot time `35F9.1`. flutter_web_auth_2 has none and needs none (it uses no listed API).

**SQLite on iOS is the system's.** The frameworks that Flutter makes from the packages' build hooks have no manifest, and Flutter offers no way to give them one yet ([flutter/flutter#140966](https://github.com/flutter/flutter/issues/140966), [dart-lang/native#878](https://github.com/dart-lang/native/issues/878)). The SQLite that sqlite3's hook bundles (`sqlite3.framework`) imports `stat`, `fstat` and `lstat` and also `statfs` and `fstatfs`, disk space APIs: SQLite reads the file system's type to choose its locking, which none of Apple's disk space reasons describes ([sqlite3.dart#410](https://github.com/simolus3/sqlite3.dart/issues/410)). Since 1 May 2024 App Store Connect does not accept an app that uses such an API without declaring it, and a build refused in processing still uses up the tag's build number. The workspace's `pubspec.yaml` therefore has sqlite3's hook load the system's SQLite on iOS (`hooks.user_defines.sqlite3`, `/usr/lib/libsqlite3.dylib`, by its full path since `dlopen` searches `/usr/lib` only for old binaries); system libraries need no manifest, and Android keeps the bundled build. The app's SQL needs SQLite 3.30 (`NULLS LAST`; upserts 3.24), and iOS 15, the oldest the app supports, ships 3.36; the app's database tests pass on Apple's SQLite of macOS (3.51), but no build has run on iOS 15 itself yet. Apple's build keeps the WAL file (empty) and the shared-memory file after the last connection closes; the sign-out wipe deletes both with the database. `cupertino_http.framework` and `objective_c.framework` use none of the listed APIs. `tool/ci/required_reason_apis.py` checks this for every binary of the archive (`nm -u`, and the two listed Objective-C selectors in the bytes) against the manifests of its framework, or for the app's and the extension's executables against their bundle's and the plugins' resource bundles, and the release refuses an undeclared category.

### Licence notices

On iOS the licence page shows Flutter's `NOTICES` of the pub packages and the app's legal assets ([D67](decisions.md#d67-agpl-30-or-later-with-an-app-store-permission-dco-reserved-brand-embedded-cronet)). Flutter leaves out a package without a `NOTICES` or `LICENSE` file without a word, and the page leaves out an asset it cannot read, so `tool/ci/ios_notices.py` checks the built `Runner.app` ([D74](decisions.md#d74-ios-phase-app-store-prerequisites-testflight-from-the-mac-photo-locations-capture-cover)): every licence in each package's file is in `App.framework/flutter_assets/NOTICES.Z` (a package without one must be the repository's, under its `LICENSE`, or the Flutter SDK's, under the SDK's), the repository's `LICENSE` is listed under the name the app's own notice joins, the only frameworks are Flutter's, `App.framework` and the native assets of `NativeAssetsManifest.json`, and every legal asset of `app/lib/core/legal/app_licenses.dart` is bundled and equal to its source. The Android notice is bundled on iOS too but not shown. The script does not see Swift packages fetched by URL, which would be linked statically; no plugin uses one (2026-10-29). The job `ios`, each TestFlight build and the iOS dry run run it:

```sh
python3 -I tool/ci/ios_notices.py app/build/ios/iphoneos/Runner.app   # after flutter build ios --release --no-codesign
```

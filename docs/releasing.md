# Releasing

How a release of the app is cut ([D86](decisions.md#d86-ci-and-releases-on-github-actions)). Every Android build that is distributed comes from the workflow "Release" (`.github/workflows/release.yaml`) of a `v*` tag in go-vikunja/app on GitHub Actions; no Android build is signed on a laptop. Its job `build` makes the Play bundle and one APK unsigned, without any secret. Once a reviewer approves, its job `publish` in the protected environment `release` signs both with Vikunja's keys, checks them, and publishes the bundle to Google Play (a beta to the `beta` track, a final release to production as a staged rollout), the APK on dl.vikunja.io, and a GitHub release with the APK, `SHA256SUMS` and the desugar_jdk_libs source. Everywhere else a release is only rehearsed with throwaway keys: on a Mac with `tool/ci/release.sh --dry-run`, in a test repository on GitHub, and in GitLab's job `release`, which stays until the move into go-vikunja/app in step 38d ([D73](decisions.md#d73-ci-from-local-scripts-versions-from-the-tag-gitlab-until-the-move)). The iOS build of the same tag is signed on the owner's Mac and uploaded to App Store Connect for TestFlight ([iOS](#ios-testflight-from-the-mac)). The app's privacy policy, legal notice and support pages are part of the owner's website, coderoftime.dev, which its own repository publishes; the website and both stores' consoles need the owner's work ([below](#the-website-and-the-store-listings)). The beta itself, from the first push to 1.0.0, follows the owner's runbook in [beta.md](beta.md) ([D77](decisions.md#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers)), which links the steps here.

*Step 38c, in review: the GitHub workflows passed their trial in the owner's test repository on 2026-11-16 ([D86](decisions.md#d86-ci-and-releases-on-github-actions)): CI on pushes, the weekly schedule and a test tag's release with throwaway keys ([the dry run](#the-dry-run)). The environment, the real signing and the publishing first run on go-vikunja/app's first tag after the move.*

## Once, in go-vikunja/app

Vikunja's maintainers set these up after the move (step 38d) and before the first tag. The workflows need nothing else; they use no personal token, only the workflow's own `github.token`.

1. **The environment `release`** (Settings > Environments > New environment):
   - **Required reviewers:** the owner and kolaente; one approval is enough, and either may approve a release of their own tag, so "Prevent self-review" stays off ([D86](decisions.md#d86-ci-and-releases-on-github-actions), owner, 2026-11-14). "Allow administrators to bypass configured protection rules" is off.
   - **Deployment branches and tags:** "Selected branches and tags", with one tag rule, `v*`, and no branch.
   - **Environment secrets,** under the old app's names. A secret's value can be neither read back nor moved, so each is entered again here:

     | Secret | Value | Needed |
     |---|---|---|
     | `KEYSTORE_BASE64` | the upload keystore (the old app's `keystore.jks`; JKS or PKCS12): `base64 < keystore.jks \| tr -d '\n'`, a wrapped value works too | yes |
     | `KEY_PROPERTIES` | its properties, as in the old app's `key.properties`: `storePassword=…`, `keyAlias=…` and `keyPassword=…`, one per line; a `storeFile` line is ignored | yes |
     | `APK_KEYSTORE_BASE64`, `APK_KEY_PROPERTIES` | a separate key for the APK, the same way | both or neither |
     | `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | the Play service account's JSON key | yes |
     | `S3_ACCESS_KEY`, `S3_SECRET_KEY` | the access key of the storage behind dl.vikunja.io | yes |
     | `S3_ENDPOINT` | the storage's https URL or host name; only its host and port are used | yes |
     | `S3_BUCKET` | the bucket that dl.vikunja.io serves | yes |
     | `S3_REGION` | the bucket's region; `us-east-1` when unset, which Cloudflare R2 takes as `auto` | no |

     Without an APK key the upload key signs the APK too, as in the old app, so installs of the old app's APKs from dl.vikunja.io and GitHub keep updating. The key that signs the APK must be RSA: the job signs the APK twice and fails when the two files differ, as they do with an EC or DSA key, because a re-run must reproduce an APK already published. Without `KEYSTORE_BASE64` and `KEY_PROPERTIES` a tag signs with throwaway keys, publishes nothing and fails; a partial set fails before signing, naming what is missing.
2. **No copies outside the environment:** delete any repository secret of these names (Settings > Secrets and variables > Actions), and remove go-vikunja/app from the access list of every organisation secret named `KEYSTORE_BASE64`, `KEY_PROPERTIES`, `APK_KEYSTORE_BASE64`, `APK_KEY_PROPERTIES`, `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`, `S3_ACCESS_KEY` or `S3_SECRET_KEY`. A job outside the environment, which any workflow on any branch can start, reads such a copy without the reviewers; the job `secret-scope` fails every tag while one exists. `S3_ENDPOINT`, `S3_BUCKET` and `S3_REGION` may stay organisation secrets.
3. **The certificates,** in a reviewed pull request: `tool/ci/release_certificates.txt` gets `upload=` with the SHA-256 of the upload certificate, as the Play Console shows it under Test and release > App integrity > Upload key certificate, in lowercase hex without colons, and `apk=` only with a separate APK key, with that key's certificate. A real release fails while `upload=` is empty or names another key than `KEYSTORE_BASE64` holds (why: a swapped secret would otherwise sign the public APK with a stranger's key). The jobs read the file from the tag, so it is committed before the tag.
4. **The rollout (optional):** the repository variable `VIKUNJA_APP_PLAY_ROLLOUT` (Settings > Secrets and variables > Actions > Variables), the share of users a final release reaches first, a fraction such as `0.2`; 0.1 when unset.
5. **Rulesets** (Settings > Rules > Rulesets): one for the tags `v*` that restricts creations, updates and deletions to the maintainers in its bypass list, so a release tag is never moved; one for `main` that requires the status checks `checks`, `editor`, `contract`, `android`, `osv` and `ios`.
6. **Actions** (Settings > Actions > General): workflow permissions "Read repository contents and packages permissions", with "Allow GitHub Actions to create and approve pull requests" off; fork pull request workflows "Require approval for all external contributors". Once the old app's workflows are gone (step 38d): "Allow actions created by GitHub" only, and "Require actions to be pinned to a full-length commit SHA"; the workflows use only GitHub's own actions, pinned that way. The tag rule of the environment also keeps the Copilot coding agent away from it.
7. **Optional:** release immutability (Settings > General > Releases). The workflow creates each release with its files at once, which works with it.
8. **Google Play:** the service account keeps its release rights for `io.vikunja.app`, to production and to the testing tracks. The old pipeline's upload of every push to `main` is switched off before the first tag (step 38d). With managed publishing on, Play holds a committed release until a maintainer publishes it. **Developer verification:** an APK installed outside Play must be signed by a key registered to a verified developer ([Android developer verification](https://developer.android.com/developer-verification/guides); certified devices in a few countries since 2026-09-30, everywhere from 2027). Play knows its app signing key; the key that signs the APK, the upload key unless an APK key is added, has to be registered in Vikunja's Play Console too.
9. **dl.vikunja.io:** the bucket serves `app/<name>/vikunja-app-<name>.apk` with the content type the job sets. The old `/app/unstable/` is no longer updated (owner, 2026-11-14).
10. **The written offer's contact:** `WRITTEN_OFFER_CONTACT` in `tool/build_android_notices.py` is `coderoftime@gmail.com` since 2026-11-02 ([D76](decisions.md#d76-store-listings-and-policies-the-apps-pages-photo-locations-removed-on-android)), and `app/assets/legal/android.md` names it. After a change, run `python3 -I tool/build_android_notices.py` and commit `app/assets/legal/android.md`. The release build fails while the contact is empty.
11. **Cronet:** done on 2026-10-29: `cronet-bundled` 500.1.0, Chromium 155.0.8059.16 (D73). Keep it current as [Raising Cronet](#raising-cronet) says.

## GitLab until the move

Until step 38d the repository is also on GitLab, `https://gitlab.com/coderoftime/rurana` ([D73](decisions.md#d73-ci-from-local-scripts-versions-from-the-tag-gitlab-until-the-move)). Its pipeline runs the same scripts and publishes nothing: on a `v*` tag its job `release` runs `tool/ci/release.sh --tag "$CI_COMMIT_TAG" --dry-run` ([the dry run](#the-dry-run)), with no environment, no keys and no artifacts.

1. **The project** exists, private, in the group `coderoftime` (`main` pushed on 2026-10-29): push `main`. Every project of the group is to become public for GitLab for Open Source ([D77](decisions.md#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers)).
2. **CI/CD variables:** none is needed but `VIKUNJA_APP_MACOS_RUNNER` for [the Mac as a runner](#the-mac-as-a-runner). A `RURANA_*` variable or a variable of the former signing sets (Settings > CI/CD > Variables) is read by nothing any more: delete it.
3. **The weekly scan:** a pipeline schedule (Build > Pipeline schedules) on `main`, `23 5 * * 1` in UTC. Scheduled pipelines run the job `osv` only.
4. **Runners ([Q22](open-questions.md#q22-ci-runners-on-gitlab)):** a full pipeline is estimated at about 100–150 compute minutes on GitLab's small shared runners. GitLab.com's free 400 minutes a month count for the whole top-level group `coderoftime`, the other projects' pipelines and the website's included, so they cover at most 3 or 4 of the app's pipelines. [GitLab for Open Source](https://about.gitlab.com/solutions/open-source/join/) takes only a group whose projects are all public with an OSI-approved licence, gives 50,000 compute minutes a month at a cost factor of 0.5 ([compute minutes](https://docs.gitlab.com/ci/pipelines/compute_minutes/)), and is renewed every year ([community programs](https://docs.gitlab.com/subscriptions/community_programs/)). Releases do not depend on it: they come from GitHub, whose standard runners are free for go-vikunja/app, a public repository.

## The website and the store listings

The app's pages are part of the owner's website, https://coderoftime.dev ([D76](decisions.md#d76-store-listings-and-policies-the-apps-pages-photo-locations-removed-on-android)): the privacy policy, the support pages, which also say how to delete an account, the project page, and the website's Impressum as the legal notice, each in English and German. The owner's own repository, `webpage`, builds them and publishes them on GitLab Pages; its README covers the hosting and the legal texts. This repository only links them: the About page through `WebsitePage` in `app/lib/app/legal.dart`, the store metadata in `fastlane/metadata/`, which `tool/check_store_metadata.py` checks against the same addresses. `coderoftime@gmail.com`, the website's contact, is Play's developer email, the support and App Review address, TestFlight's feedback address and the written offer's contact. [store-listing.md](store-listing.md#the-website) lists every address and what uses it, and every form of both consoles with its answer and the reason. Once, in this order:

1. **The Impressum's c/o address and phone:** a service with authority to accept service (Zustellungsvollmacht; a P.O. box is not enough) and a phone number as the second fast contact channel, both in `src/site.config.ts` of the website's repository, where the address is not final yet. Only the website shows them, not the stores. They are the website's last missing part, and they come before the first rollout to testers ([beta.md](beta.md#6-the-impressum)).
2. **The website is deployed:** the pages have been live on coderoftime.dev since 2026-11-02, and every address below answered that day. After a change, deploy it again as its README's "Hosting" says, then open, signed out: `https://coderoftime.dev/rurana/privacy/` and its German part at `#de`, `https://coderoftime.dev/impressum/#de` and `#en`, `https://coderoftime.dev/rurana/support/#how-do-i-delete-my-account`, `https://coderoftime.dev/de/rurana/support/`, `https://coderoftime.dev/rurana/` and `https://coderoftime.dev/de/rurana/`. Once these addresses are in the stores they must not change; the deletion URL's anchor comes from the English support page's heading "How do I delete my account?", so that heading keeps its words. A change would have to go into `legal.dart`, `check_store_metadata.py`, `fastlane/metadata/`, [store-listing.md](store-listing.md#the-website) and both consoles at once.
3. **The Play Console and App Store Connect forms,** as [store-listing.md](store-listing.md#google-play-console) answers them, with the texts of `fastlane/metadata/` copied in by hand: in the Play Console the app, the store settings and contact details, the main store listing in both languages with the graphics of `branding/png/`, the privacy policy, App access, Ads, Content rating, Target audience, News, Data safety, Government, Financial features, Health and Advertising ID, and a check that App content asks for no foreground-service or exact-alarm declaration; in App Store Connect the app information, the category, content rights, the age rating, App Privacy with both privacy policy addresses, pricing and availability, the version's texts and addresses, App Review information with a phone number (never in the repository) and TestFlight's test information.
4. **The trader declarations:** non-trader on Google Play (asked when the developer account is created) and "not a trader" on App Store Connect. Any income, donations included, would change that.
5. **The screenshot session:** start the test server with both test users, seed the demo data with `python3 -I tool/seed_demo_data.py --lang en`, sign in once on each device (the Android phone and tablet emulators, the iPhone 17 Pro Max, iPhone 17 Pro and iPad Pro 13-inch simulators), then run `tool/store_screenshots.sh` for each device and language, with `--reset --lang de` for the German data ([store-listing.md](store-listing.md#screenshots) has each step). Then `python3 -I tool/check_store_metadata.py --strict` must pass; run it again before every submission.

Nothing in this repository waits for the website: the About page links its addresses in every build, the release scripts do not look at it, and `python3 -I tool/check_store_metadata.py --strict` fails only while a store's minimum set of screenshots is missing. An empty or changed URL, email or copyright file fails the check without `--strict` too.

## Cutting a release

1. **Bump the version** (after [raising Cronet](#raising-cronet) if Google has a newer one) in `app/pubspec.yaml` to the release's name, for example `version: 1.0.0-beta.1+1`. Only the part before `+` counts; the build number comes from the tag. Run the [dry run](#the-dry-run) for the tag, `tool/ci/release.sh --dry-run --tag v1.0.0-beta.1`: it must end with only the expected reasons, `not a tag run of go-vikunja/app on GitHub Actions`, `placeholder source URL` and `throwaway keys`, and `no committed certificate fingerprints (tool/ci/release_certificates.txt)` while the certificates of [step 3 above](#once-in-go-vikunjaapp) are not committed; `no written-offer contact` means that the contact of step 10 above is empty, and the release would fail. Run the contract tests once locally against the newest release of the previous minor version, today 2.7.1: `VIKUNJA_APP_TEST_VIKUNJA_IMAGE=vikunja/vikunja:2.7.1 tool/ci/contract.sh` starts the local test server again, empty, with that image, and the tests expect its version. The script stops at the first suite that fails: when the vikunja_api suite fails, run the app's suite alone against the same server, `(cd app && VIKUNJA_CONTRACT=1 TZ=Europe/Berlin flutter test --tags contract --concurrency=1 test/contract)`, before you record anything. Fix what fails or record it in [D28](decisions.md#d28-contract-tests-against-the-latest-vikunja-release-only). Then `docker compose -f test_servers/docker-compose.yaml up -d` brings back the latest release, and `tool/seed_e2e_user.sh` and `E2E_USER_ENV=test_servers/seed/e2e-user-2.env tool/seed_e2e_user.sh` the two sign-in test users. Merge the bump into `main` and wait for its green CI run before you tag.
2. **Tag and push the tag,** as a maintainer whom the tag ruleset allows:

   ```sh
   git tag -a v1.0.0-beta.1 -m "Vikunja app 1.0.0-beta.1"
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

   `python3 -I tool/ci/release_version.py v1.0.0-beta.1` prints the name and the code, and fails for another tag or when the pubspec's version name differs. A tag that starts with `v` but is malformed fails the job `build`; any other tag runs no release. Never move or delete a release tag: the job publishes nothing once the tag no longer points at the commit it built, and a fix is the next tag.
3. **The release workflow** runs `ci` (every CI job, `ios` included), `build` and `secret-scope`. Then `publish` waits: a reviewer of the environment `release` other than the person who pushed the tag opens the run and approves it under "Review deployments". `publish` then:
   - checks that the tag still points at the built commit and that the environment holds every secret the release needs;
   - signs the bundle and the APK, compares both certificates with `tool/ci/release_certificates.txt`, and checks the signatures (never the debug key), the APK's alignment and the version;
   - uploads the bundle to Google Play: a beta to the `beta` track, to all its testers at once; a final release to production as a staged rollout to the share `VIKUNJA_APP_PLAY_ROLLOUT` (0.1 when unset);
   - puts the APK on dl.vikunja.io at `app/<name>/vikunja-app-<name>.apk`;
   - creates the GitHub release "Vikunja app <name>" with `vikunja-app-<name>.apk`, `SHA256SUMS` and `desugar_jdk_libs-<version>-src.tar.gz`, a beta as a prerelease, a final release as the latest; its notes give the APK's SHA-256, the SHA-256 of its signing certificate and the link to the source at the tag, which the About page of this build links too.
4. **Check the release:** on the GitHub release, the three files open signed out, `SHA256SUMS` matches the APK, and the certificate's SHA-256 is the committed one; the APK on dl.vikunja.io has the same SHA-256; the Play Console shows the release on its track.
5. **A final release's rollout:** watch the Play Console's vitals, then raise the share or complete the rollout in the Play Console (Test and release > Production), or halt it there. The workflow never changes a rollout after its upload.
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

1. **The pin:** in `tool/ci/pins.sh`, `FLUTTER_VERSION`, `FLUTTER_LINUX_SHA256`, the `sha256` of that version's stable Linux archive in `https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json`, and `FLUTTER_MACOS_ARM64_SHA256`, the `sha256` of its macOS arm64 zip in `releases_macos.json` beside it, which GitHub's macOS runner downloads (step 38c, in review); the comment above them keeps the earlier pin. The README's [prerequisites](../README.md#prerequisites) name the version with its Dart, and so does [the Mac runner's line](#the-mac-as-a-runner) below.
2. **The Mac's SDK:** run `flutter upgrade` from a folder outside the repository, for example `(cd ~ && flutter upgrade)`, until `flutter --version` prints the pinned version. Run inside the repository on 2026-11-02, the command also upgraded 29 packages in the workspace's `pubspec.lock`, which had to be restored. Afterwards `git status` must show no change, and `flutter pub get --enforce-lockfile` must resolve the committed lockfile.
3. **The checks:** `tool/ci/checks.sh`, `tool/ci/test.sh`, `tool/ci/android.sh` and, on the Mac, `tool/ci/ios.sh`, then both [dry runs](#the-dry-run); commit `pins.sh` and the README together. GitHub's runners and GitLab's Linux runners download the pinned archives; a Mac runner on GitLab needs the same version on its PATH.

## When the publish job fails

- **A `ci` job failed or was cancelled,** so `publish` never started. One cause lies outside the repository: `ios` cancelled after 15 minutes with "The job was not acquired by Runner of type hosted", when GitHub had no macOS runner free. "Re-run failed jobs" runs that job again and keeps the build, whose artifact lasts 14 days (fewer if the repository's artifact retention setting is lower). The release waits for `ios` on purpose: a tag that does not build on iOS is not released on Android either.
- **Before Google Play** (the check, the signing, a certificate): nothing is published yet. Fix the cause, for example a secret of the environment, and use "Re-run failed jobs", which keeps the build and asks for the approval again.
- **During or after publishing:** "Re-run failed jobs" too. Each step skips what is already published with the same content and fails on other content: Play by the version code already on its track, dl.vikunja.io by the object's `sha256` metadata, the GitHub release by downloading its three files and comparing their SHA-256; a leftover draft release is deleted and created again.
- **Not "Re-run all jobs":** it builds and signs again, and the new APK need not equal the one already published, which dl.vikunja.io and the GitHub release then refuse.
- **To publish other files under a tag** that dl.vikunja.io or GitHub already has, delete the object from the bucket or the release on GitHub first. Play takes a version code only once.
- **`secret-scope` fails:** a release secret is also a repository or organisation secret ([step 2 above](#once-in-go-vikunjaapp)).
- **A fix in the repository,** `release_certificates.txt` included, needs a new commit and a new tag, the next beta or the next patch: the jobs check out the tag.

## The Mac as a runner

On GitHub the job `ios` runs on GitHub's macOS runner ([D86](decisions.md#d86-ci-and-releases-on-github-actions)). On GitLab, until the move, it needs a Mac of the owner's as a runner: it builds the iOS app unsigned on the Mac and checks the notices of its licence page ([below](#licence-notices)) and its required-reason APIs ([below](#privacy-manifests)). It is the only job such a runner takes; the Linux jobs stay on the shared runners. To run it:

- Register the Mac as a project runner with the tag `macos`, "Run untagged jobs" off and the shell executor, so the job runs directly on the Mac.
- Run the runner under a macOS user of its own that cannot read the keystores, the owner's other files or the owner's Keychain. The job runs whatever `tool/ci/ios.sh`, `tool/ci/lib.sh`, `.gitlab-ci.yml` and the build itself (build hooks, CocoaPods, Xcode's build phases) say on the protected main branch or the tag: the job never runs in a merge request pipeline, so only reviewed and merged code runs on this Mac ([threat model](threat-model.md) R35).
- Point `xcode-select` at Xcode: `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`. `ios.sh` refuses to run otherwise, as the native-asset build hooks ignore `DEVELOPER_DIR` ([README](../README.md#prerequisites)).
- Put exactly the Flutter that `tool/ci/pins.sh` pins (3.47.9) on the runner's PATH: the runner sets `CI=true`, and there another version is an error.
- Set the project variable `VIKUNJA_APP_MACOS_RUNNER` to `true`.

Pipelines on main and on `v*` tags then have the job, and it must pass; merge requests and the schedule never do. Unset the variable while the Mac is away or asleep: GitLab cannot tell an absent runner from a busy one, so the pending job holds each pipeline open for up to a day and then fails it.

## The dry run

```sh
tool/ci/release.sh --dry-run                       # the tag defaults to v<the pubspec's version name>
tool/ci/release.sh --dry-run --tag v1.0.0-beta.1   # the pubspec must have that version
```

It runs the whole Android release locally except the publication. `release_build.sh` builds the bundle and the APK unsigned with the release's checks, with `https://source.example/vikunja-app/tree/<tag>` standing in for the source link. `release_sign.sh` signs them with a throwaway JKS key, valid for one day, whose key password differs from its store password, and runs every check but the comparison with the committed certificates. Each publish step prints what it would publish and where, and why it does not. The script ends with `DRY RUN: NOT RELEASABLE (…)`; without `--dry-run` it refuses, as releases come only from go-vikunja/app. It needs Flutter, the Android SDK's build-tools (`apksigner`, `zipalign`, `aapt2`), a JDK and access to GitHub for the desugar_jdk_libs source; the files land in `build/release/unsigned/` and `build/release/signed/`.

The same rehearsal runs in two more places, and publishes nothing there either:

- **GitLab:** the job `release` of each `v*` tag, until the move ([D73](decisions.md#d73-ci-from-local-scripts-versions-from-the-tag-gitlab-until-the-move)). With the project private it also gives the reason `repository not public`.
- **A test repository on GitHub,** any repository but go-vikunja/app: with the repository variable `VIKUNJA_APP_RELEASE_DRY_RUN=true`, a `v*` tag runs the jobs `build` and `dry-run`, the release's steps with `--dry-run`, without an environment or a secret; the source link is that repository's tree at the tag, and a private repository gives the reason `repository not public`. `VIKUNJA_APP_IOS_JOB=true` adds the job `ios` to its CI, which costs macOS minutes in a private repository. Without the variable a tag there runs only the CI. Such a repository holds no secret and no key.

A local `flutter build apk --release` is signed with the debug key and prints a warning, unless `app/android/key.properties` (gitignored) names a keystore with `storeFile`, `storePassword`, `keyAlias` and `keyPassword`; with `VIKUNJA_APP_UNSIGNED=true` it stays unsigned. Such builds are for testing only.

## iOS: TestFlight from the Mac

`tool/ci/ios_release.sh` builds the iOS app of a release tag on the owner's Mac, signs it with Xcode's automatic signing for the owner's team, checks it and uploads it to App Store Connect, which hands it to TestFlight and later to App Review. No CI job runs it: the job `ios` on GitHub and on GitLab builds unsigned only, and the owner runs the release by hand once the tag's CI is green. Running it in CI would need the team's signing and the API key in CI secrets or in a runner's macOS account, which [the GitLab runner's separate user](#the-mac-as-a-runner) is meant not to have ([D74](decisions.md#d74-ios-phase-app-store-prerequisites-testflight-from-the-mac-photo-locations-capture-cover)).

### Once, before the first upload

1. **The Apple Developer Program:** the account that publishes the app, enrolled as an individual or an organisation; the App Store shows the enrolled name as the seller. The membership is renewed every year: when it lapses, the app leaves the App Store and takes no updates.
2. **The team id:** ten capital letters and digits, under Membership details in the developer account. The script reads it from `DEVELOPMENT_TEAM`. It is not secret (every signed build carries it, and Flutter prints it while signing), but it stays out of the repository so that a fork signs with its own team.
3. **Xcode signed in, with a device:** add the account under Xcode > Settings > Accounts, and register an iPhone with the team once: connect it to the Mac with Xcode open, or add its UDID under Certificates, Identifiers & Profiles > Devices. Automatic signing archives with a development profile, which Xcode cannot create for a team without a device ("Your team has no devices from which to generate a provisioning profile"); the export then signs for distribution. Automatic signing also needs the App IDs `io.vikunja.app` and `io.vikunja.app.widgets` (since step 38a; whether `io.vikunja.app` is still free at Apple is open, [D15](decisions.md#d15-app-id-iovikunjaapp-and-the-name-vikunja)), both with the App Groups capability and only the group `group.io.vikunja.app`, a distribution certificate and the profiles; Xcode creates what is missing on the first signed build (`flutter build ipa` passes `-allowProvisioningUpdates`). If it cannot, create the App IDs and the group under Certificates, Identifiers & Profiles > Identifiers.
4. **The app record:** in App Store Connect, Apps > + > New App: iOS, the name `Vikunja` ([D76](decisions.md#d76-store-listings-and-policies-the-apps-pages-photo-locations-removed-on-android); step 38f picks another if it is taken), the bundle id `io.vikunja.app`, a SKU of your choice (for example `vikunja-app`). Creating the record reserves the name, so it can come before the first build. The listing, the screenshots and the App Privacy answers: [store-listing.md](store-listing.md#app-store-connect).
5. **The API key:** the Account Holder requests API access once under Users and Access > Integrations > App Store Connect API. Then generate a team key with the Developer role (it covers delivering builds; App Manager only if Apple refuses the upload with it) and download `AuthKey_<id>.p8`; Apple offers the file only once. Keep it outside the repository (`*.p8` is gitignored) with `chmod 600`: the script refuses a key file that other users can read. It reads three variables, prints none of them and takes them out of the environment before Flutter or Xcode runs, so that only altool gets them; altool gets the file's path, never its content:

   | Variable | Value |
   |---|---|
   | `VIKUNJA_APP_ASC_KEY_ID` | the key's id |
   | `VIKUNJA_APP_ASC_ISSUER_ID` | the issuer id shown above the team keys |
   | `VIKUNJA_APP_ASC_KEY_FILE` | the path of `AuthKey_<id>.p8` |

   The names are `VIKUNJA_APP_ASC_*` since step 38c (in review); a shell profile that still exports `RURANA_ASC_*` gets the refusal "VIKUNJA_APP_ASC_KEY_ID is not set".

6. **The source link** (step 38c, in review): `VIKUNJA_APP_SOURCE_CODE_URL`, the repository's https URL without `.git`, by default `https://github.com/go-vikunja/app`. The build links the repository's tree at the tag, `<URL>/tree/<tag>` on github.com and `<URL>/-/tree/<tag>` on another host, as the Android release does; the About page shows it ([D67](decisions.md#d67-agpl-30-or-later-with-an-app-store-permission-dco-reserved-brand-embedded-cronet)), and the script checks that it opens signed out. Until the move (step 38d) go-vikunja/app has no such tag: set the variable to a public repository that has it.

### Each TestFlight build

After the tag's CI is green ([cutting a release](#cutting-a-release), step 3), on the Mac:

```sh
git fetch --tags && git checkout v1.0.0-beta.1
export DEVELOPMENT_TEAM=… VIKUNJA_APP_ASC_KEY_ID=… VIKUNJA_APP_ASC_ISSUER_ID=… VIKUNJA_APP_ASC_KEY_FILE=…/AuthKey_….p8
export VIKUNJA_APP_SOURCE_CODE_URL=https://github.com/go-vikunja/app   # the default; another public repository before the move
tool/ci/ios_release.sh --tag v1.0.0-beta.1
```

The script:

- refuses to run unless `xcode-select` points to Xcode (the native-asset build hooks ignore `DEVELOPER_DIR`), Flutter is exactly the version `tool/ci/pins.sh` pins, HEAD is the tag with a clean working tree, the source link opens signed out at the tag, the team id and the three key variables are set, and the App Store icon is 1024 × 1024, RGB without an alpha channel and untagged or sRGB;
- computes the version from the tag with `release_version.py` and runs the release-only source-link test;
- builds with `flutter build ipa --release`, the tag's version, `SOURCE_CODE_URL` and generated export options: method `app-store-connect`, automatic signing, the team, and `manageAppVersionAndBuildNumber` off so that Xcode never changes the version;
- checks the archived `Runner.app` and `VikunjaWidgets.appex`: both carry the tag's version, the app declares `ITSAppUsesNonExemptEncryption` false, both privacy manifests are the committed ones, every required-reason API that a binary in them uses is declared (`tool/ci/required_reason_apis.py`, [below](#privacy-manifests)), and the licence page has every notice (`tool/ci/ios_notices.py`, [below](#licence-notices));
- requires exactly one IPA, since `flutter build ipa` reports success even when the export fails, prints its SHA-256 and uploads it with `xcrun altool --upload-package` and the key.

App Store Connect takes only `MAJOR.MINOR.PATCH` as the version (`CFBundleShortVersionString`), so every beta of a release has the release's version and the Android version code as its build number (`CFBundleVersion`), which grows with every tag:

| Tag | Version | Build |
|---|---|---|
| `v1.0.0-beta.1` | 1.0.0 | 1000001 |
| `v1.0.0-beta.2` | 1.0.0 | 1000002 |
| `v1.0.0` | 1.0.0 | 1000099 |
| `v1.0.1-beta.1` | 1.0.1 | 1000101 |

On iOS the app therefore reports 1.0.0 with the build number for every beta of 1.0.0, for example the User-Agent `Vikunja-App/1.0.0+1000002`. A build number goes to App Store Connect only once per version, even when processing fails, and a version released in the App Store takes no more builds: a fix needs the next tag, as on Android.

The build shows up under TestFlight in App Store Connect after processing; Apple emails a problem found while processing, for example a missing API declaration. Internal testers (members of the team in App Store Connect) can install it at once; external testers, by invitation or a public link, only after Beta App Review has passed the first build of a version, which needs the test information of [store-listing.md](store-listing.md#app-store-connect): the public demo's account `demo` / `demo` in the sign-in fields, never in the notes, and the review notes ([Q21](open-questions.md#q21-a-server-for-the-store-reviewers)). The external group, its public link and each build's What to Test: [beta.md](beta.md#testflight).

### The iOS dry run

```sh
tool/ci/ios_release.sh --dry-run                       # the tag defaults to v<the pubspec's version name>
tool/ci/ios_release.sh --dry-run --tag v1.0.0-beta.1   # the pubspec must have that version
```

It builds the archive unsigned (`--no-codesign`) with the same checks, the licence notices included, and stops before the export and the upload. It prints the source link it would check, the tree at the tag of `VIKUNJA_APP_SOURCE_CODE_URL` or its default, without opening it. The tag, the clean tree, the team id, the key variables, Flutter's version and an undeclared required-reason API only warn; it needs neither the Apple account nor the key, and checks them when they are set. It prints the export options it would use and ends with `DRY RUN: NOT RELEASABLE (unsigned build, …)`.

### Export compliance

`ITSAppUsesNonExemptEncryption` is `false` in `Runner/Info.plist`, so App Store Connect asks no encryption questions for each build. The extension needs no such key; App Store Connect reads the app's. The app uses encryption only through standard protocols: HTTPS through the system's `URLSession`, and for servers with a pinned certificate, a private CA or a client certificate the TLS of Dart's `dart:io` (BoringSSL in the Flutter engine, [D65](decisions.md#d65-connection-settings-per-server-address-applied-in-the-apps-transport)); the Keychain for tokens and secrets; SHA-256 for PKCE, account ids and certificate fingerprints. None of it is proprietary encryption, which is what Apple counts as exempt from the export documentation. Apple's page adds that an app with exempt encryption may still owe the U.S. government a year-end self-classification report: check that once before the App Store release (step 37d). If App Store Connect asks anyway, the answer is that the app uses only exempt encryption. *Note 2026-11-02, step 37d ([D77](decisions.md#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers)): checked for the United States: since BIS's rule of 29 March 2021 ([86 FR 16482](https://www.federalregister.gov/documents/2021/03/29/2021-05481/export-administration-regulations-implementation-of-wassenaar-arrangement-2019-plenary-decisions)) the annual report covers only mass-market components and executable software ([15 CFR 740.17(e)(3)](https://www.law.cornell.edu/cfr/text/15/740.17)), not an end-user app that uses only standard encryption, so none is due. France is open ([Q23](open-questions.md#q23-french-encryption-declaration-for-the-app-store)): Apple's [table](https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption/) asks for a French encryption declaration for an industry-standard algorithm that the operating system does not provide, which BoringSSL in the Flutter engine is ([beta.md](beta.md#before-100)). Neither is legal advice.*

### Privacy manifests

`Runner/PrivacyInfo.xcprivacy` and `VikunjaWidgets/PrivacyInfo.xcprivacy` sit at the root of the app and of the extension, each in its target's resources (`tool/add_widget_extension.rb` adds them; rerun it after renaming either). Both say no tracking, no tracking domains and no collected data: Apple counts data as collected when it leaves the device in a way that the developer or the developer's partners can access, and the app sends data only to the Vikunja server the user chooses. That is usually the user's own or their organisation's; the onboarding's "Try the public demo" fills in `https://try.vikunja.io`, which the Vikunja project runs, but the user picks it, and the developer has no access to it and no partnership with its operator. The app has no analytics, crash reporting or advertising SDK. App Store Connect's App Privacy answer, "Data Not Collected", rests on the same reasoning ([store-listing.md](store-listing.md#app-store-connect)).

The required-reason APIs, from the code and from the symbols the release binaries import (`nm -u`), checked against [Apple's list](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api) on 2026-10-29:

| Bundle | Category | Reason | Why |
|---|---|---|---|
| `Runner.app` | File timestamp | `C617.1` | Timestamps and sizes of files in the app container and the App Group container: the attachment cache pruned by modification date (`dart:io` `stat`, which the Flutter engine declares as a wrapper, `0A2A.1`), package_info_plus reading the creation date of the app's Documents folder and the modification date of the app bundle (its own manifest declares nothing), picked files copied into the container |
| `Runner.app` | User defaults | `CA92.1` | The app's own preferences through shared_preferences in the standard defaults; no App Group defaults |
| `VikunjaWidgets.appex` | File timestamp | `C617.1` | The extension prunes its list selections by the modification date of files in the App Group container |

Not declared: system boot time (Dart's `Stopwatch` reads `clock_gettime_nsec_np`, which is not on the list; the engine declares its own `systemUptime`), disk space and active keyboards. Apple asks the bundle that holds a binary to declare its APIs, so a framework needs a manifest of its own. The extension uses no user defaults. The plugin `vikunja_widgets` uses none of these APIs; its Swift code is linked into the Runner and has no manifest of its own.

The plugins the app links bring their manifests as resource bundles inside the app: file_selector_ios, flutter_secure_storage_darwin, image_picker_ios, local_auth_darwin, package_info_plus, quick_actions_ios, share_plus, url_launcher_ios and webview_flutter_wkwebview declare no tracking, no collected data and no API; flutter_local_notifications and workmanager_apple declare user defaults `CA92.1`; shared_preferences_foundation declares user defaults `1C8F.1`; `Flutter.framework` declares file timestamp `0A2A.1` and `C617.1` and system boot time `35F9.1`. flutter_web_auth_2 has none and needs none (it uses no listed API).

**SQLite on iOS is the system's.** The frameworks that Flutter makes from the packages' build hooks have no manifest, and Flutter offers no way to give them one yet ([flutter/flutter#140966](https://github.com/flutter/flutter/issues/140966), [dart-lang/native#878](https://github.com/dart-lang/native/issues/878)). The SQLite that sqlite3's hook bundles (`sqlite3.framework`) imports `stat`, `fstat` and `lstat` and also `statfs` and `fstatfs`, disk space APIs: SQLite reads the file system's type to choose its locking, which none of Apple's disk space reasons describes ([sqlite3.dart#410](https://github.com/simolus3/sqlite3.dart/issues/410)). Since 1 May 2024 App Store Connect does not accept an app that uses such an API without declaring it, and a build refused in processing still uses up the tag's build number. The workspace's `pubspec.yaml` therefore has sqlite3's hook load the system's SQLite on iOS (`hooks.user_defines.sqlite3`, `/usr/lib/libsqlite3.dylib`, by its full path since `dlopen` searches `/usr/lib` only for old binaries); system libraries need no manifest, and Android keeps the bundled build. The app's SQL needs SQLite 3.30 (`NULLS LAST`; upserts 3.24), and iOS 15, the oldest the app supports, ships 3.36; the app's database tests pass on Apple's SQLite of macOS (3.51), but no build has run on iOS 15 itself yet. Apple's build keeps the WAL file (empty) and the shared-memory file after the last connection closes; the sign-out wipe deletes both with the database. `cupertino_http.framework` and `objective_c.framework` use none of the listed APIs. `tool/ci/required_reason_apis.py` checks this for every binary of the archive (`nm -u`, and the two listed Objective-C selectors in the bytes) against the manifests of its framework, or for the app's and the extension's executables against their bundle's and the plugins' resource bundles, and the release refuses an undeclared category.

### Licence notices

On iOS the licence page shows Flutter's `NOTICES` of the pub packages and the app's legal assets ([D67](decisions.md#d67-agpl-30-or-later-with-an-app-store-permission-dco-reserved-brand-embedded-cronet)). Flutter leaves out a package without a `NOTICES` or `LICENSE` file without a word, and the page leaves out an asset it cannot read, so `tool/ci/ios_notices.py` checks the built `Runner.app` ([D74](decisions.md#d74-ios-phase-app-store-prerequisites-testflight-from-the-mac-photo-locations-capture-cover)): every licence in each package's file is in `App.framework/flutter_assets/NOTICES.Z` (a package without one must be the repository's, under its `LICENSE`, or the Flutter SDK's, under the SDK's), the repository's `LICENSE` is listed under the name the app's own notice joins, the only frameworks are Flutter's, `App.framework` and the native assets of `NativeAssetsManifest.json`, and every legal asset of `app/lib/core/legal/app_licenses.dart` is bundled and equal to its source. The Android notice is bundled on iOS too but not shown. The script does not see Swift packages fetched by URL, which would be linked statically; no plugin uses one (2026-10-29). The job `ios`, each TestFlight build and the iOS dry run run it:

```sh
python3 -I tool/ci/ios_notices.py app/build/ios/iphoneos/Runner.app   # after flutter build ios --release --no-codesign
```

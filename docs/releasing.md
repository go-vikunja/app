# Releasing

How a release of Rurana is cut ([D73](decisions.md#d73-gitlab-ci-from-scripts-that-run-the-same-locally-images-and-downloads-pinned-the-version-from-the-release-tag-release-signing-from-protected-ci-variables-the-source-link-from-the-build-a-gitlab-release-with-the-apk-its-checksums-and-the-desugar_jdk_libs-source)). Every build that is distributed comes from the GitLab job `release` of a `v*` tag pipeline; nothing is signed on a laptop. The job builds the Play bundle and one APK, signs them with keys from protected CI variables, checks them, and publishes a GitLab release with the APK, `SHA256SUMS` and the desugar_jdk_libs source. The bundle goes to Google Play by hand.

## Once, before the first release

1. **Decide [Q20](open-questions.md#q20-signing-keys-and-the-apk-beside-the-play-build)** and create the keys. The default is option A: one app signing key that only the owner holds, uploaded to Play App Signing with PEPK, signs the APK, and a separate upload key signs the bundles. Use PKCS12 keystores with an RSA key of 4096 bits and alphanumeric passwords of 20 characters or more; a PKCS12 keystore has one password, so the key password is the store password. Keep the keystores and their passwords out of the repository (`*.p12`, `*.jks`, `*.keystore`, `*.pepk` and `*.keystore.b64` are gitignored).
2. **Create the GitLab project** and push `main`.
3. **Make the project public**, and under Settings > General > Visibility set the repository, the releases and the package registry to "Everyone With Access". The release job refuses a project that is not public and checks that anonymous users can read the repository at the tag, the releases and the package registry: the app's source link and the release's files must open for everyone (AGPL section 6).
4. **Protect the tags `v*`** (Settings > Repository > Protected tags), with "Allowed to create" set to Maintainers.
5. **Add the signing variables** (Settings > CI/CD > Variables). Each one is Protected and has the environment scope `release`, so it reaches only the release job of a protected tag. The keystores and the passwords are also "Masked and hidden", with "Expand variable reference" off; the aliases are not secret and may be shorter than the 8 characters masking needs, so they are only Protected and scoped.

   | Variable | Value | Needed |
   |---|---|---|
   | `RURANA_UPLOAD_KEYSTORE_BASE64` | the upload keystore, `base64 < upload.p12 \| tr -d '\n'` | yes |
   | `RURANA_UPLOAD_STORE_PASSWORD` | its password | yes |
   | `RURANA_UPLOAD_KEY_ALIAS` | the key's alias | yes |
   | `RURANA_UPLOAD_KEY_PASSWORD` | the same password | yes |
   | `RURANA_APK_KEYSTORE_BASE64`, `RURANA_APK_STORE_PASSWORD`, `RURANA_APK_KEY_ALIAS`, `RURANA_APK_KEY_PASSWORD` | the APK's keystore, the same way | all four or none |

   The upload set signs the bundle. The APK set signs the APK; without it the upload key signs the APK too, and the job warns in a box in its log and says so in the release's description. Sideloaded installs stay bound to the key of their first APK for good, so decide this before the first release. A missing upload set, or a partial set of either kind, stops the job before it builds.
6. **Duplicate packages (optional):** `release.sh` already refuses to upload when the package `rurana/<name>` exists. GitLab's switch that turns off duplicates for generic packages is a group setting (the group's Settings > Packages and registries > Duplicate packages, from GitLab's documentation, not yet seen on a live project), so it applies only when the project sits in a group; a project in a personal namespace relies on the script's check.
7. **Artifacts:** the bundle stays a job artifact for 30 days. "Keep artifacts from most recent successful jobs" (Settings > CI/CD > Artifacts) keeps the latest one longer; download each bundle for Play within 30 days either way.
8. **The weekly scan:** a pipeline schedule (Build > Pipeline schedules) on `main`, `23 5 * * 1` in UTC. Scheduled pipelines run the job `osv` only.
9. **The written offer's contact:** set `WRITTEN_OFFER_CONTACT` in `tool/build_android_notices.py`, run `python3 -I tool/build_android_notices.py` and commit `app/assets/legal/android.md`. The release job fails while the contact is empty.
10. **Cronet:** done on 2026-10-29: `cronet-bundled` 500.1.0, Chromium 155.0.8059.16 (D73). Keep it current as [Raising Cronet](#raising-cronet) says.
11. **Runners ([Q22](open-questions.md#q22-ci-runners-on-gitlab)):** a full pipeline is estimated at about 100–150 compute minutes on GitLab's small shared runners, so GitLab.com's free 400 minutes a month cover only 3 or 4 pipelines. Apply for GitLab for Open Source once the project is public; that is the only remedy 37a supports. The Mac runner described below takes only the job `ios` and saves no shared-runner minutes: moving the heavy Linux jobs to the Mac would need a setup of its own that 37a does not include (tags on those jobs or a runner that takes untagged jobs, plus Docker and the Android SDK on the Mac).

## Cutting a release

1. **Bump the version** (after [raising Cronet](#raising-cronet) if Google has a newer one) in `app/pubspec.yaml` to the release's name, for example `version: 1.0.0-beta.1+1`. Only the part before `+` counts; the build number comes from the tag. Run the [dry run](#the-dry-run) for the tag, `tool/ci/release.sh --dry-run --tag v1.0.0-beta.1`: it must end with only the expected reasons, `placeholder source URL`, `throwaway keys` and `project not public` (a local run has no project); `no written-offer contact` means step 9 above is not done, and the release job would fail. Commit on `main`, push, and wait for a green pipeline before you tag.
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
5. **Upload the bundle to Google Play** by hand (step 37d): download `build/release/app-release.aab` from the release job's artifacts, compare its SHA-256 with the line "Bundle for Play" in the job's log, and upload it in the Play Console to the closed test for a beta or to production for a final release.

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

## When the release job fails

- **Before the upload** (a guard, a test, the build or a check): fix the cause, for example a variable, and retry the job.
- **During or after the upload:** the package `rurana/<name>` exists without a release. Delete it (Deploy > Package registry), then retry the job.
- **To publish a release again:** delete the release in the UI and its package, then retry the job.
- A fix in the code needs a new commit and a new tag, the next beta or the next patch.

## The Mac as a runner

The job `ios` builds the iOS app unsigned on a Mac. It is the only job such a runner takes; the Linux jobs stay on the shared runners. To run it:

- Register the Mac as a project runner with the tag `macos`, "Run untagged jobs" off and the shell executor, so the job runs directly on the Mac.
- Run the runner under a macOS user of its own that cannot read the keystores, the owner's other files or the owner's Keychain. The job runs whatever `tool/ci/ios.sh`, `tool/ci/lib.sh`, `.gitlab-ci.yml` and the build itself (build hooks, CocoaPods, Xcode's build phases) say on the protected main branch or the tag: the job never runs in a merge request pipeline, so only reviewed and merged code runs on this Mac ([threat model](threat-model.md) R35).
- Point `xcode-select` at Xcode: `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`. `ios.sh` sets `DEVELOPER_DIR` when `xcode-select` points to the Command Line Tools, but the native-asset build hooks ignore it ([README](../README.md#prerequisites)), so expect the job to fail without the switch.
- Put exactly the Flutter that `tool/ci/pins.sh` pins (3.47.7) on the runner's PATH: the runner sets `CI=true`, and there another version is an error.
- Set the project variable `RURANA_MACOS_RUNNER` to `true`.

Pipelines on main and on `v*` tags then have the job, and it must pass; merge requests and the schedule never do. Unset the variable while the Mac is away or asleep: GitLab cannot tell an absent runner from a busy one, so the pending job holds each pipeline open for up to a day and then fails it.

## The dry run

```sh
tool/ci/release.sh --dry-run                       # the tag defaults to v<the pubspec's version name>
tool/ci/release.sh --dry-run --tag v1.0.0-beta.1   # the pubspec must have that version
```

It runs the whole release locally except the upload: two throwaway keystores, valid for one day, stand in for the keys, and `https://gitlab.example/rurana` for the project's URL. The visibility and contact guards only warn. It prints the files it would upload and the release it would create, and ends with `DRY RUN: NOT RELEASABLE (…)`. It needs Flutter, the Android SDK's build-tools, a JDK and access to GitHub for the desugar_jdk_libs source; the files land in `build/release/`.

A local `flutter build apk --release` is signed with the debug key and prints a warning, unless `app/android/key.properties` (gitignored) names a keystore with `storeFile`, `storePassword`, `keyAlias` and `keyPassword`. Such builds are for testing only.

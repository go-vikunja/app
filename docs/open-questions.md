# Open questions

The project owner answered Q1–Q15 on 2026-10-09 and took up the deferred Q3 on 2026-10-27. This page records each answer and where it was turned into a decision. The questions themselves are condensed from [research/synthesis.md](research/synthesis.md) §5.

**Still deferred:** [Q11](#q11-optional-near-real-time-push-on-android) push, [Q12](#q12-crash-reporting) crash reporting, [Q14](#q14-licensed-features) licensed features.

**Derived lead decision:** browser OAuth + PKCE is the only sign-in method (Q4), and it exists only on Vikunja 2.3.0 and newer. The effective support floor is therefore **2.3.0**, not the 2.0.0 of option A in Q1, and the `standard` tier for 2.0–2.2 is dropped ([D13](decisions.md#d13-support-floor-230)).

## Q1: Minimum server version

- **Asked:** floor 2.0.0 (A), or also 0.24–1.x (B)?
- **Answer:** A. The app is meant to be released some day, and older servers are very rare.
- **Result:** floor 2.3.0 because of Q4 (see the lead decision above); step 38 is removed. [D13](decisions.md#d13-support-floor-230), superseding [D7](decisions.md#d7-support-floor-200).

## Q2: App identity

- **Asked:** app name and logo, `applicationId` and bundle id, OAuth `client_id` and redirect scheme, App Group and keychain group.
- **Answer:** `applicationId` and bundle id `dev.coderoftime.vikunja`. Generate a name and a logo that lean on Vikunja's.
- **Result:** [D15](decisions.md#d15-app-id-devcoderoftimevikunja), superseding [D10](decisions.md#d10-placeholder-application-ids). Name **Rurana** with the "checkbox ears" llama icon, chosen by the owner on 2026-10-09 after the first proposal (Taskuna, check-llama) was rejected, and on 2026-10-13 replaced by the illustrated llama with a check badge ([D42](decisions.md#d42-app-icon-the-illustrated-llama-with-a-check-badge-adaptive-themed-and-ios-18-variants-derived-by-script)); store listing `Rurana – client for Vikunja` (de: `Rurana – Client für Vikunja`). See [branding/README.md](../branding/README.md). The OAuth `client_id` and the `vikunja-…` redirect scheme were fixed in step 2+3 ([D23](decisions.md#d23-browser-sign-in-through-flutter_web_auth_2-client-id-and-redirect-uri)); the App Group and keychain group derive from the app id in step 19.

## Q3: Licence and distribution

**Answered 2026-10-27** (deferred on 2026-10-09: "leave it for now").

- **Asked:** the licence, given that the app ports the web frontend's behaviour and Vikunja is AGPL-3.0-or-later; the stores: Play, App Store, F-Droid.
- **Answer:** AGPL-3.0-or-later for the whole repository, with an additional permission under section 7 for app stores such as Apple's from the start; contributions signed off under the Developer Certificate of Origin; the name and the llama logo not under the AGPL, all rights reserved; F-Droid is not a distribution target.
- **Result:** `LICENSE`, `NOTICE.md`, `CONTRIBUTING.md` and a sign-off check on pull requests; an About page and a complete licence page in the app; the audit's copied texts and editor code rewritten. Step 37 publishes the source code before the first store release. The owner answered both follow-up questions the same day: the app ships embedded Cronet instead of Google Play services Cronet, and the logo files may be copied unmodified only as part of a copy of the repository or of an unmodified build published by Benedikt Lesch. [D67](decisions.md#d67-agpl-30-or-later-with-an-app-store-permission-contributions-under-the-dco-the-name-and-the-logo-reserved-no-f-droid-the-legal-notices-on-an-about-page-and-the-licence-page-the-source-code-published-before-the-first-store-release). Not legal advice.

## Q4: Login methods

- **Asked:** browser OAuth + PKCE in step 3, then password + TOTP and API tokens in step 4?
- **Answer:** browser OAuth only, for now. Username and password login will be removed from Vikunja at some point.
- **Result:** no password + TOTP form and no API-token login; step 4 becomes multi-account. [D14](decisions.md#d14-browser-sign-in-only).

## Q5: Session lifetime

- **Asked:** how to live with OAuth sessions that expire after 72 h without a refresh.
- **Answer:** the background sync keeps the session alive.
- **Result:** background runs refresh every account's session (step 16). [D22](decisions.md#d22-session-keep-alive-through-background-sync).

## Q6: Multi-account

- **Asked:** account switcher in the first release, or later?
- **Answer:** in the first release.
- **Result:** roadmap step 4 adds, switches and removes accounts. [D16](decisions.md#d16-multi-account-in-the-first-release).

## Q7: Notification policy defaults

- **Asked:** which tasks get reminders, when due-date notifications fire, overdue digest, when to ask for Android exact alarms.
- **Answer:**
  - Reminders only for tasks where the user is the creator or an assignee.
  - Due-date notification at the exact due time, using exact alarms.
  - Ask for exact alarms during onboarding.
  - No overdue digest for now.
- **Result:** step 15. [D17](decisions.md#d17-notification-policy).

## Q8: Description editing

- **Asked:** TipTap in a WebView, Markdown-only editing, or plain text?
- **Answer:** TipTap in a WebView, for now.
- **Result:** step 25. [D18](decisions.md#d18-tiptap-description-editor-in-a-webview).

## Q9: Quick-add quirks

- **Asked:** replicate the web exactly, or fix obvious bugs?
- **Answer:** as recommended: fix the four known bugs, document the fixes, keep the grammar.
- **Result:** step 13. [D19](decisions.md#d19-quick-add-quirk-policy).

## Q10: Desktop-centric features

- **Asked:** confirm the mobile adaptations of desktop features.
- **Answer:** confirmed, except that the MCP information page and the admin panel are dropped entirely.
  - Confirmed: Gantt as a read-only timeline, table as a detailed list, keyboard shortcuts on iPad only, widgets and app shortcuts instead of the desktop quick-entry window, no seasonal logo or PWA banners.
- **Result:** steps 13, 18, 19, 29, 33 and 36. [D20](decisions.md#d20-scope-cuts-and-desktop-adaptations).

## Q11: Optional near-real-time push on Android

**Deferred** ("leave it for now").

- **Idea:** a Vikunja webhook → self-hosted ntfy → UnifiedPush. Android only; it needs per-project webhooks, and LAN targets need `webhooks.allownonroutableips`.
- **Result:** not on the roadmap. [D20](decisions.md#d20-scope-cuts-and-desktop-adaptations).

## Q12: Crash reporting

**Deferred** ("leave for now").

- **Result:** no crash reporting SDK. If it comes back, the alternative was opt-in self-hosted Sentry or GlitchTip. [D20](decisions.md#d20-scope-cuts-and-desktop-adaptations).

## Q13: Launch languages

- **Asked:** English and German first, or all 32 web locales from step 36?
- **Answer:** English and German for the beginning.
- **Result:** step 36 no longer imports the web locales. [D21](decisions.md#d21-languages-english-and-german).

## Q14: Licensed features

**Deferred.** The owner has no Vikunja licence yet and is working on getting one.

- **Result:** time tracking (step 34) is deferred until a licence is available; the admin panel is dropped anyway (Q10). [D20](decisions.md#d20-scope-cuts-and-desktop-adaptations).

## Q15: iOS toolchain on the development Mac (local setup action)

- **Asked:** run `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`, because the Dart native-asset build hooks ignore `DEVELOPER_DIR`.
- **Answer:** done. `xcode-select -p` prints the Xcode path, and local iOS builds work. CI was never affected.

## Q16: Community translation platform

**Open**, needed by step 36f.

- **Asked:** which platform the community translates on, and when it is connected.
- **Options:** Hosted Weblate (Libre plan; the repository prepared in 36f, the project connected in step 37 once the repository is public); Crowdin's open-source plan (commits as a bot, proprietary); self-hosted Weblate; no platform, merge requests only.
- **Recommendation:** Hosted Weblate. It is libre, keeps each translator's authorship in git, offers contributor agreements, checks ICU messages and also handles the Android and Apple string formats of the widgets and permission texts.

## Q17: Licence path for community translations

**Open**, needed by step 36f.

- **Asked:** how translations come in under the AGPL with the app store permission and the DCO ([D67](decisions.md#d67-agpl-30-or-later-with-an-app-store-permission-contributions-under-the-dco-the-name-and-the-logo-reserved-no-f-droid-the-legal-notices-on-an-about-page-and-the-licence-page-the-source-code-published-before-the-first-store-release)).
- **Options:** a contributor agreement on the platform that covers the DCO 1.1, the AGPL with the app store permission and "nothing copied from Vikunja", plus a `Signed-off-by` line in the platform's commit template (a narrow DCO-check exemption only for the platform's own add-on commits, if the pilot shows they need it); exempting all platform commits from the DCO check with the agreement only; deciding in step 37.
- **Recommendation:** the contributor agreement with the sign-off template. Without the permission, translations could not ship in App Store builds (not legal advice).

## Q18: Generated localisation code in git

**Open**, needed by step 36f.

- **Asked:** whether `app/lib/l10n/generated/` (about 210 KB per language) stays committed. Today every commit that changes only an ARB file fails CI's check for stale generated code, so every translation merge request would fail.
- **Options:** stop committing it (gen-l10n runs on `pub get`, on every build and in every CI job); keep committing it and regenerate on every translation merge request; keep committing it and let a CI bot push the regenerated files to the platform's branch.
- **Recommendation:** stop committing it.

## Q19: Device setup for the manual TalkBack pass

**Open**, needed by step 36a.

- **Asked:** the manual TalkBack, Switch Access and Accessibility Scanner pass needs a Google Play sign-in on an emulator and the installation of Android Accessibility Suite and Accessibility Scanner. The usual phone emulator has too little space left, and the large phone emulator has no Play.
- **Options:** now on the Pixel_Tablet emulator (Play image), VoiceOver in the final iOS phase; now on a new phone emulator from the Play image (more disk, a second sign-in); TalkBack and VoiceOver both at the end of the project.
- **Recommendation:** the Pixel_Tablet emulator now; only the owner can sign in to Play.
- **2026-10-28:** on the Pixel_Tablet emulator TalkBack 16 came preinstalled, but it ignored the touch and key events an agent injects over adb, so the pass could not be performed there ([D68](decisions.md#d68-screen-readers-heading-levels-on-screen-titles-and-section-headers-one-announcer-with-the-apps-own-live-region-on-android-high-contrast-and-reduce-motion-followed-and-a-route-sweep-that-every-route-pushed-page-and-overlay-must-pass-wcag-22-aa-as-the-yardstick-with-written-deviations)). Left open: the owner on that emulator with the host keyboard (Accessibility Scanner still needs the Play sign-in), or TalkBack together with VoiceOver in the final device phase. The steps are in the [accessibility checklist](accessibility-checklist.md).
- **2026-10-28, later:** the owner accepted step 36a with this pass still open; the question stays open for the pass itself.
- **2026-10-28, step 36c:** the pass also covers the task detail pane on the tablet in landscape: opening, a task inside the pane, closing, and the selected row ([D70](decisions.md#d70-task-detail-pane-on-windows-at-least-840-dp-wide-and-480-dp-high-a-task-opens-beside-the-list-one-pane-per-tab-with-a-back-stack-and-a-selected-row-the-sheet-everywhere-else-back-through-the-pane-first-and-pages-in-a-tab-without-androids-predictive-back), [checklist](accessibility-checklist.md) section 2.4). It was not checked with TalkBack in step 36c; the question stays open.

## Q20: Signing keys and the APK beside the Play build

**Open**, needed before the first release tag (step 37d). Since step 37a the release job reads the keys from CI variables whichever way this is decided.

- **Asked:** which key signs the APK in each GitLab release, and how it relates to the build Google Play delivers ([D72](decisions.md#d72-first-release-android-and-ios-together-on-google-play-with-an-apk-in-every-gitlab-release-the-repository-on-gitlab-version-100-after-a-beta)). Android installs an update only when its signature matches the installed app's.
- **Options:** one app signing key that only the owner holds, uploaded to Play App Signing when the app is created, so Play's build and the repository's APK share one signature and update each other (CI signs with it from protected variables, or the owner signs the APK on their Mac); Play's own app signing key and a separate key for the APK under the same application id, so a phone keeps the channel it was installed from and changing it needs an uninstall; the APK under its own application id, installable beside the Play build.
- **Recommendation:** one app signing key held by the owner and uploaded to Play App Signing, with a separate upload key for the Play bundle; the APK signed with the app signing key on the owner's Mac or a protected runner. Only the owner can create the keys and the Play app.
- **Since step 37a** ([D73](decisions.md#d73-gitlab-ci-from-scripts-that-run-the-same-locally-images-and-downloads-pinned-the-version-from-the-release-tag-release-signing-from-protected-ci-variables-the-source-link-from-the-build-a-gitlab-release-with-the-apk-its-checksums-and-the-desugar_jdk_libs-source)): the release job signs the bundle with the `RURANA_UPLOAD_*` variables and the APK with the `RURANA_APK_*` variables, or with the upload key and a warning when those are not set; the variables are protected and scoped to the environment `release` ([releasing.md](releasing.md)). Option A, the main session's default, puts the app signing key into the APK set; the other options use the same variables. The application-id option would need a second application id in the build, which 37a does not have.

## Q21: A server for the store reviewers

**Open**, needed by step 37c.

- **Asked:** Google's and Apple's reviewers have to sign in to try the app, and Rurana works only against a Vikunja server.
- **Options:** a small public Vikunja server run by the owner with a review account and demo data (`tool/seed_demo_data.py`), named in the review notes; a link share on such a server, so reviewers need no password (the guest flow of [D62](decisions.md#d62-create-account-password-reset-and-invite-links-through-the-browser-sign-in-page-link-share-guests-as-an-account-kind-with-token-renewal-and-a-reduced-ui)); no server, with a video of the app in the notes.
- **Recommendation:** the owner's demo server with a review account and seeded data, kept online through the review and the beta.

## Q22: CI runners on GitLab

**Open**, needed before CI runs regularly on GitLab and before the first release tag (step 37d); step 37a works with every option.

- **Asked:** where the pipelines run once CI moves to GitLab ([D72](decisions.md#d72-first-release-android-and-ios-together-on-google-play-with-an-apk-in-every-gitlab-release-the-repository-on-gitlab-version-100-after-a-beta)). A full pipeline with the contract tests takes about 25 to 30 minutes, GitLab.com's free tier has about 400 compute minutes a month, and iOS builds need a macOS runner, which GitLab.com offers only on paid tiers.
- **Options:** GitLab's shared Linux runners with the GitLab for Open Source programme (free once the repository is public and under an OSI licence); a self-hosted runner on the owner's Mac for everything; both: shared Linux runners for the checks and the Android builds, the owner's Mac as a runner (or by hand) for the iOS builds and TestFlight.
- **Recommendation:** both. Until the repository is public, the pipelines can run on the owner's Mac runner or by hand with the same scripts.
- **Since step 37a** ([D73](decisions.md#d73-gitlab-ci-from-scripts-that-run-the-same-locally-images-and-downloads-pinned-the-version-from-the-release-tag-release-signing-from-protected-ci-variables-the-source-link-from-the-build-a-gitlab-release-with-the-apk-its-checksums-and-the-desugar_jdk_libs-source)): the jobs run on GitLab's small shared Linux runners with Gradle's memory capped; the job `ios` runs only on a project runner tagged `macos` while the variable `RURANA_MACOS_RUNNER` is `true`. A full pipeline is now estimated at about 100–150 compute minutes on the small shared runners, so the free 400 minutes a month cover only 3 or 4 pipelines: CI can run regularly only with GitLab for Open Source or with the owner's Mac as a runner for the heavy jobs, which 37a does not set up.

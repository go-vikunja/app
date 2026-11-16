# Open questions

The project owner answered Q1–Q15 on 2026-10-09, took up the deferred Q3 on 2026-10-27, answered Q21 on 2026-11-02 (step 37c) and Q20 and Q22 the same day (step 37d). Step 38d made Q22 obsolete and removed the DCO of Q3 and Q17 ([D87](decisions.md#d87-mit-vikunjas-contribution-rules-and-the-move-into-go-vikunjaapp)). This page records each answer and where it was turned into a decision. The questions themselves are condensed from [research/synthesis.md](research/synthesis.md) §5.

**Still deferred:** [Q11](#q11-optional-near-real-time-push-on-android) push, [Q12](#q12-crash-reporting) crash reporting, [Q14](#q14-licensed-features) licensed features.

**Derived lead decision:** browser OAuth + PKCE is the only sign-in method (Q4), and it exists only on Vikunja 2.3.0 and newer. The effective support floor is therefore **2.3.0**, not the 2.0.0 of option A in Q1, and the `standard` tier for 2.0–2.2 is dropped ([D13](decisions.md#d13-support-floor-230)).

## Q1: Minimum server version

- **Asked:** floor 2.0.0 (A), or also 0.24–1.x (B)?
- **Answer:** A. The app is meant to be released some day, and older servers are very rare.
- **Result:** floor 2.3.0 because of Q4 (see the lead decision above); step 38 is removed. [D13](decisions.md#d13-support-floor-230), superseding [D7](decisions.md#d7-support-floor-200).

## Q2: App identity

- **Asked:** app name and logo, `applicationId` and bundle id, OAuth `client_id` and redirect scheme, App Group and keychain group.
- **Answer:** `applicationId` and bundle id `dev.coderoftime.vikunja`. Generate a name and a logo that lean on Vikunja's.
- **Result:** [D15](decisions.md#d15-app-id-iovikunjaapp-and-the-name-vikunja), superseding [D10](decisions.md#d10-placeholder-application-ids). Name **Rurana** with the "checkbox ears" llama icon, chosen by the owner on 2026-10-09 after the first proposal (Taskuna, check-llama) was rejected, and on 2026-10-13 replaced by the illustrated llama with a check badge ([D42](decisions.md#d42-app-icon-vikunjas-logo-every-variant-derived-by-script)); store listing `Rurana – client for Vikunja` (de: `Rurana – Client für Vikunja`). See [branding/README.md](../branding/README.md). *Note 2026-11-02, step 37c ([D76](decisions.md#d76-store-listings-and-policies-the-apps-pages-photo-locations-removed-on-android)): the store name is just `Rurana` in both stores, by the owner's decision.* The OAuth `client_id` and the `vikunja-…` redirect scheme were fixed in step 2+3 ([D23](decisions.md#d23-browser-sign-in-through-flutter_web_auth_2-in-an-ephemeral-session)); the App Group and keychain group derive from the app id in step 19. *Note 2026-11-02, step 37d ([D77](decisions.md#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers)): the owner had the app id renamed to `dev.coderoftime.rurana`, with every id derived from it, before any store record or signing key exists.* *Note 2026-11-13, step 38a ([D83](decisions.md#d83-successor-of-the-official-vikunja-app-in-go-vikunjaapp)): the app takes the official Vikunja app's identity: the id `io.vikunja.app`, the App Group `group.io.vikunja.app`, the scheme and `client_id` `vikunja-io.vikunja.app` and the name Vikunja ([D15](decisions.md#d15-app-id-iovikunjaapp-and-the-name-vikunja)), and an icon derived from Vikunja's logo ([D42](decisions.md#d42-app-icon-vikunjas-logo-every-variant-derived-by-script)); no keychain group exists.*

## Q3: Licence and distribution

**Answered 2026-10-27** (deferred on 2026-10-09: "leave it for now").

- **Asked:** the licence, given that the app ports the web frontend's behaviour and Vikunja is AGPL-3.0-or-later; the stores: Play, App Store, F-Droid.
- **Answer:** AGPL-3.0-or-later for the whole repository, with an additional permission under section 7 for app stores such as Apple's from the start; contributions signed off under the Developer Certificate of Origin; the name and the llama logo not under the AGPL, all rights reserved; F-Droid is not a distribution target.
- **Result:** `LICENSE`, `NOTICE.md`, `CONTRIBUTING.md` and a sign-off check on pull requests; an About page and a complete licence page in the app; the audit's copied texts and editor code rewritten. Step 37 publishes the source code before the first store release. The owner answered both follow-up questions the same day: the app ships embedded Cronet instead of Google Play services Cronet, and the logo files may be copied unmodified only as part of a copy of the repository or of an unmodified build published by Benedikt Lesch. [D67](decisions.md#d67-agpl-30-or-later-with-an-app-store-permission-dco-reserved-brand-embedded-cronet). Not legal advice.
- **Since step 38d** ([D87](decisions.md#d87-mit-vikunjas-contribution-rules-and-the-move-into-go-vikunjaapp)): the repository is under the MIT License, as D83 decided for the move into go-vikunja/app. The AGPL text, the app store permission, the DCO and its sign-off check are gone: Vikunja's rules ask for no CLA and no DCO. The name and the logo are Vikunja's; the former name Rurana and its llama stay reserved in the history. The source link and the About page stay without their AGPL reasons, and embedded Cronet stays for D5's reasons.

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
- **Result:** step 25. [D18](decisions.md#d18-descriptions-edited-with-tiptap-in-a-webview-shown-natively).

## Q9: Quick-add quirks

- **Asked:** replicate the web exactly, or fix obvious bugs?
- **Answer:** as recommended: fix the four known bugs, document the fixes, keep the grammar.
- **Result:** step 13. [D19](decisions.md#d19-quick-add-keeps-the-web-grammar-and-fixes-four-parser-bugs).

## Q10: Desktop-centric features

- **Asked:** confirm the mobile adaptations of desktop features.
- **Answer:** confirmed, except that the MCP information page and the admin panel are dropped entirely.
  - Confirmed: Gantt as a read-only timeline, table as a detailed list, keyboard shortcuts on iPad only, widgets and app shortcuts instead of the desktop quick-entry window, no seasonal logo or PWA banners.
- **Result:** steps 13, 18, 19, 29, 33 and 36. [D20](decisions.md#d20-scope-cuts-and-mobile-forms-of-desktop-features).

## Q11: Optional near-real-time push on Android

**Deferred** ("leave it for now").

- **Idea:** a Vikunja webhook → self-hosted ntfy → UnifiedPush. Android only; it needs per-project webhooks, and LAN targets need `webhooks.allownonroutableips`.
- **Result:** not on the roadmap. [D20](decisions.md#d20-scope-cuts-and-mobile-forms-of-desktop-features).

## Q12: Crash reporting

**Deferred** ("leave for now").

- **Result:** no crash reporting SDK. If it comes back, the alternative was opt-in self-hosted Sentry or GlitchTip. [D20](decisions.md#d20-scope-cuts-and-mobile-forms-of-desktop-features).

## Q13: Launch languages

- **Asked:** English and German first, or all 32 web locales from step 36?
- **Answer:** English and German for the beginning.
- **Result:** step 36 no longer imports the web locales. [D21](decisions.md#d21-languages-english-and-german).

## Q14: Licensed features

**Deferred.** The owner has no Vikunja licence yet and is working on getting one.

- **Result:** time tracking (step 34) is deferred until a licence is available; the admin panel is dropped anyway (Q10). [D20](decisions.md#d20-scope-cuts-and-mobile-forms-of-desktop-features).

## Q15: iOS toolchain on the development Mac (local setup action)

- **Asked:** run `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`, because the Dart native-asset build hooks ignore `DEVELOPER_DIR`.
- **Answer:** done. `xcode-select -p` prints the Xcode path, and local iOS builds work. CI was never affected.

## Q16: Community translation platform

**Answered 2026-11-12** by the owner: Vikunja's existing Crowdin project, which the official app's repository already uses ([D83](decisions.md#d83-successor-of-the-official-vikunja-app-in-go-vikunjaapp)); its integration is still to be built.

- **Asked:** which platform the community translates on, and when it is connected.
- **Options:** Hosted Weblate (Libre plan; the repository prepared in 36f, the project connected in step 37 once the repository is public); Crowdin's open-source plan (commits as a bot, proprietary); self-hosted Weblate; no platform, merge requests only.
- **Recommendation:** Hosted Weblate. It is libre, keeps each translator's authorship in git, offers contributor agreements, checks ICU messages and also handles the Android and Apple string formats of the widgets and permission texts.

## Q17: Licence path for community translations

**Answered 2026-11-12** by the owner: with the move to go-vikunja/app the licence becomes MIT, which needs no extra permission from translators ([D83](decisions.md#d83-successor-of-the-official-vikunja-app-in-go-vikunjaapp)).

- **Asked:** how translations come in under the AGPL with the app store permission and the DCO ([D67](decisions.md#d67-agpl-30-or-later-with-an-app-store-permission-dco-reserved-brand-embedded-cronet)).
- **Options:** a contributor agreement on the platform that covers the DCO 1.1, the AGPL with the app store permission and "nothing copied from Vikunja", plus a `Signed-off-by` line in the platform's commit template (a narrow DCO-check exemption only for the platform's own add-on commits, if the pilot shows they need it); exempting all platform commits from the DCO check with the agreement only; deciding in step 37.
- **Recommendation:** the contributor agreement with the sign-off template. Without the permission, translations could not ship in App Store builds (not legal advice).
- **Since step 38d** ([D87](decisions.md#d87-mit-vikunjas-contribution-rules-and-the-move-into-go-vikunjaapp)): neither option is needed. The DCO and its check are gone (Vikunja's rules: no CLA, no DCO), and translations come only through Crowdin.

## Q18: Generated localisation code in git

**Open**, needed by the Crowdin integration, whose pull requests change the ARB files.

- **Asked:** whether `app/lib/l10n/generated/` (about 210 KB per language) stays committed. Today every commit that changes only an ARB file fails CI's check for stale generated code, so every translation merge request would fail.
- **Options:** stop committing it (gen-l10n runs on `pub get`, on every build and in every CI job); keep committing it and regenerate on every translation merge request; keep committing it and let a CI bot push the regenerated files to the platform's branch.
- **Recommendation:** stop committing it.

## Q19: Device setup for the manual TalkBack pass

**Open.** Step 36a was accepted with the pass still open; it is planned in step 37d before 1.0.0, with VoiceOver in the iOS device test ([beta.md](beta.md), [D77](decisions.md#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers)).

- **Asked:** the manual TalkBack, Switch Access and Accessibility Scanner pass needs a Google Play sign-in on an emulator and the installation of Android Accessibility Suite and Accessibility Scanner. The usual phone emulator has too little space left, and the large phone emulator has no Play.
- **Options:** now on the Pixel_Tablet emulator (Play image), VoiceOver in the final iOS phase; now on a new phone emulator from the Play image (more disk, a second sign-in); TalkBack and VoiceOver both at the end of the project.
- **Recommendation:** the Pixel_Tablet emulator now; only the owner can sign in to Play.
- **2026-10-28:** on the Pixel_Tablet emulator TalkBack 16 came preinstalled, but it ignored the touch and key events an agent injects over adb, so the pass could not be performed there ([D68](decisions.md#d68-screen-readers-headings-one-announcer-high-contrast-reduce-motion-route-sweep)). Left open: the owner on that emulator with the host keyboard (Accessibility Scanner still needs the Play sign-in), or TalkBack together with VoiceOver in the final device phase. The steps are in the [accessibility checklist](accessibility-checklist.md).
- **2026-10-28, later:** the owner accepted step 36a with this pass still open; the question stays open for the pass itself.
- **2026-10-28, step 36c:** the pass also covers the task detail pane on the tablet in landscape: opening, a task inside the pane, closing, and the selected row ([D70](decisions.md#d70-task-detail-pane-beside-the-list-on-two-pane-windows-the-sheet-elsewhere), [checklist](accessibility-checklist.md) section 2.4). It was not checked with TalkBack in step 36c; the question stays open.
- **2026-11-10, step 36g:** the pass also covers the project tree's column beside the open project on the tablet in landscape: the three regions in order, the marked rows and the page that says no project is open ([D82](decisions.md#d82-projects-listdetail-the-project-tree-beside-the-project-on-wide-windows), [checklist](accessibility-checklist.md) section 2.5). It was not checked with TalkBack in step 36g; the question stays open.

## Q20: Signing keys and the APK beside the Play build

**Answered 2026-11-02**, step 37d.

- **Asked:** which key signs the APK in each GitLab release, and how it relates to the build Google Play delivers ([D72](decisions.md#d72-first-release-android-and-ios-together-play-and-an-apk-beta-first)). Android installs an update only when its signature matches the installed app's.
- **Options:** one app signing key that only the owner holds, uploaded to Play App Signing when the app is created, so Play's build and the repository's APK share one signature and update each other (CI signs with it from protected variables, or the owner signs the APK on their Mac); Play's own app signing key and a separate key for the APK under the same application id, so a phone keeps the channel it was installed from and changing it needs an uninstall; the APK under its own application id, installable beside the Play build.
- **Recommendation:** one app signing key held by the owner and uploaded to Play App Signing, with a separate upload key for the Play bundle; the APK signed with the app signing key on the owner's Mac or a protected runner. Only the owner can create the keys and the Play app.
- **Since step 37a** ([D73](decisions.md#d73-ci-from-local-scripts-versions-from-the-tag-gitlab-until-the-move)): the release job signs the bundle with the `RURANA_UPLOAD_*` variables and the APK with the `RURANA_APK_*` variables, or with the upload key and a warning when those are not set; the variables are protected and scoped to the environment `release` ([releasing.md](releasing.md)). Option A, the main session's default, puts the app signing key into the APK set; the other options use the same variables. The application-id option would need a second application id in the build, which 37a does not have.
- **Answer:** option A. The owner creates an app signing key that only the owner holds and uploads it to Play App Signing with PEPK when creating the app ("Provide a copy of your app signing key"); a separate upload key signs the bundles; the release job signs the APK with the app signing key (`RURANA_APK_*`), so Play's builds and the GitLab APK share one signature.
- **Result:** [D77](decisions.md#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers) decision 2. Two facts the options above did not have (2026-11-02):
  - Play now enrols a new app in "quantum-ready hybrid signing" with keys Google generates (an RSA-4096 and an ML-DSA-65 key, and a classical key for Android 16 and older). Another choice, the provided key among them, is possible only until a release reaches open testing or production, and the page does not say whether a provided key gets hybrid signing too ([Play Console Help](https://support.google.com/googleplay/android-developer/answer/9842756)).
  - Android's developer verification: since 2026-09-30 certified devices in Brazil, Indonesia, Singapore and Thailand install an app from any source only when it is registered to a verified developer, and Google plans the same for every certified device in 2027; an APK installed outside Play must be signed by a registered key ([developer verification](https://developer.android.com/developer-verification/guides)). With option A the APK's key is the app signing key Play already knows, so nothing else needs registering.

  When creating the app the owner checks in the console whether the provided key gets hybrid signing, and so whether Play's builds and an APK signed with RSA alone still update each other on Android 17 and later. If they would not, this question comes back before a release reaches open testing or production, after which the key cannot change.
- **Since step 38c** ([D86](decisions.md#d86-ci-and-releases-on-github-actions)): the app ships in Vikunja's listing ([D83](decisions.md#d83-successor-of-the-official-vikunja-app-in-go-vikunjaapp)), so option A no longer applies and no key of the owner's is created. Vikunja's upload key, the old app's `KEYSTORE_BASE64` and `KEY_PROPERTIES` in the environment `release` of go-vikunja/app, signs the bundle and, without a separate APK key (`APK_KEYSTORE_BASE64`), the APK, as in the old app, so installs of the old app's APKs keep updating. A real release needs the upload certificate's SHA-256 committed in `tool/ci/release_certificates.txt`, which Vikunja's maintainers read in the Play Console; it is not committed yet.

## Q21: A server for the store reviewers

**Answered 2026-11-02**, step 37c.

- **Asked:** Google's and Apple's reviewers have to sign in to try the app, and the app works only against a Vikunja server.
- **Options:** a small public Vikunja server run by the owner with a review account and demo data (`tool/seed_demo_data.py`), named in the review notes; a link share on such a server, so reviewers need no password (the guest flow of [D62](decisions.md#d62-onboarding-through-the-browser-link-share-guests-as-an-account-kind)); no server, with a video of the app in the notes.
- **Recommendation:** the owner's demo server with a review account and seeded data, kept online through the review and the beta.
- **Answer:** Vikunja's public demo, `try.vikunja.io`, through the app's "Try the public demo", with its shared account `demo` / `demo`, which the server shows itself.
- **Result:** [D76](decisions.md#d76-store-listings-and-policies-the-apps-pages-photo-locations-removed-on-android) decision 2. The review notes (`fastlane/metadata/review_information/notes.txt`) and Play's App access instructions lead through the demo and say that the shared account may be empty or hold other visitors' tasks; the review notes also ask the reviewers not to delete it, as its confirmation link goes to the demo account's email address ([store-listing.md](store-listing.md#the-reviewers-server)). The demo is reset at irregular intervals, so a review fails if it is down or its account has changed; the fallback is the recommended own server, with a review account seeded by `tool/seed_demo_data.py`.

## Q22: CI runners on GitLab

**Answered 2026-11-02**, step 37d; **obsolete since step 38d**, which deleted the GitLab pipeline ([D87](decisions.md#d87-mit-vikunjas-contribution-rules-and-the-move-into-go-vikunjaapp)).

- **Asked:** where the pipelines run once CI moves to GitLab ([D72](decisions.md#d72-first-release-android-and-ios-together-play-and-an-apk-beta-first)). A full pipeline with the contract tests takes about 25 to 30 minutes, GitLab.com's free tier has about 400 compute minutes a month, and iOS builds need a macOS runner, which GitLab.com offers only on paid tiers.
- **Options:** GitLab's shared Linux runners with the GitLab for Open Source programme (free once the repository is public and under an OSI licence); a self-hosted runner on the owner's Mac for everything; both: shared Linux runners for the checks and the Android builds, the owner's Mac as a runner (or by hand) for the iOS builds and TestFlight.
- **Recommendation:** both. Until the repository is public, the pipelines can run on the owner's Mac runner or by hand with the same scripts.
- **Since step 37a** ([D73](decisions.md#d73-ci-from-local-scripts-versions-from-the-tag-gitlab-until-the-move)): the jobs run on GitLab's small shared Linux runners with Gradle's memory capped; the job `ios` runs only on a project runner tagged `macos` while the variable `RURANA_MACOS_RUNNER` is `true`. A full pipeline is now estimated at about 100–150 compute minutes on the small shared runners, so the free 400 minutes a month cover only 3 or 4 pipelines: CI can run regularly only with GitLab for Open Source or with the owner's Mac as a runner for the heavy jobs, which 37a does not set up.
- **Answer:** every project of the group `coderoftime` becomes public, so that the whole group can join GitLab for Open Source, which asks for every project in the namespace to be public under an OSI-approved licence. The project stays https://gitlab.com/coderoftime/rurana, with its history as it is. iOS builds stay on the owner's Mac, by hand.
- **Result:** [D77](decisions.md#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers) decision 1. Compute minutes count against the top-level group, so until the programme is granted the free 400 a month are shared with the group's other projects, the website's pipelines included ([compute minutes](https://docs.gitlab.com/ci/pipelines/compute_minutes/)); each beta costs two full pipelines, the push to `main` and the tag ([releasing.md](releasing.md#cutting-a-release)), about 200–300 minutes. The programme takes groups, not personal namespaces, gives 50,000 compute minutes a month at a cost factor of 0.5 and is renewed every year ([GitLab for Open Source](https://about.gitlab.com/solutions/open-source/join/)). The iOS release runs on the Mac with `tool/ci/ios_release.sh` ([releasing.md](releasing.md#ios-testflight-from-the-mac)); a Mac runner for the job `ios` stayed optional until step 38d deleted it.
- **Since step 38c** ([D86](decisions.md#d86-ci-and-releases-on-github-actions)): GitHub Actions run the same jobs in go-vikunja/app, a public repository, where the standard runners, macOS included, are free; the job `ios` runs on GitHub's macOS runner there. GitLab's pipeline stays until the move (step 38d) and publishes nothing, so its minutes no longer limit releases.
- **Since step 38d** ([D87](decisions.md#d87-mit-vikunjas-contribution-rules-and-the-move-into-go-vikunjaapp)): `.gitlab-ci.yml`, its tests, the job `dco` and the Mac as a GitLab runner are deleted, and CI runs on GitHub Actions only ([D86](decisions.md#d86-ci-and-releases-on-github-actions)). The app no longer needs GitLab for Open Source. The GitLab project `coderoftime/rurana` is public and is archived with a pointer to go-vikunja/app once the import is merged.

## Q23: French encryption declaration for the App Store

**Open**, needed before the App Store release in France (1.0.0); raised in step 37d ([D77](decisions.md#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers)).

- **Asked:** whether the app needs a French encryption declaration to be on the App Store in France, and what its export compliance answer is then.
- **Facts (2026-11-02, not legal advice):**
  - Apple's table of export compliance documentation asks for an uploaded French encryption declaration for an industry-standard algorithm "not provided within the Apple operating system", and only for an app on the App Store in France ([Apple](https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption/)).
  - The app's connections to a server with a pinned certificate, a trusted CA or a client certificate use the TLS of `dart:io`, which is BoringSSL in the Flutter engine; every other connection uses the system's `URLSession` ([releasing.md](releasing.md#export-compliance), [D65](decisions.md#d65-connection-settings-per-server-address-applied-in-the-apps-transport)).
  - The App Store availability is every country and region except mainland China, France included ([D76](decisions.md#d76-store-listings-and-policies-the-apps-pages-photo-locations-removed-on-android)). `ITSAppUsesNonExemptEncryption` is `false` ([D74](decisions.md#d74-ios-phase-app-store-prerequisites-testflight-from-the-mac-photo-locations-capture-cover)), so App Store Connect asks nothing for each build; Apple leaves the liability for a wrong exemption with the developer.
  - France's rules are the décret 2007-663 and ANSSI's procedures. Whether an exemption of the décret's Annex 1 covers a TLS client like this one was not checked.
  - The US side needs nothing more: since the rule 86 FR 16482 of 2021, an end-user app with only standard, mass-market encryption owes no year-end self-classification report ([15 CFR 740.17](https://www.law.cornell.edu/cfr/text/15/740.17)). Google Play has no such step.
- **Options:**
  - File a declaration with ANSSI, then tell App Store Connect that the app uses standard encryption besides the system's and upload the declaration; `ITSAppUsesNonExemptEncryption` would then no longer be `false`, which needs a new build.
  - Have someone qualified check the exemptions of the décret's Annex 1, and keep `ITSAppUsesNonExemptEncryption` `false` if one applies, with the reason written down.
  - Leave France out of the App Store's availability at first, and add it once one of the two above is done.
- **Recommendation:** start the declaration during the beta, and leave France out of the App Store for 1.0.0 unless the declaration, or a clear exemption from a qualified check, is in hand by then. The declaration is a known procedure that makes the answer accurate; an exemption rests on a reading of the décret that nobody here has checked. Unverified: what the declaration asks for and how long ANSSI takes; whether testers in France on TestFlight are affected, as Apple's footnote names only the App Store; how App Store Connect handles France for a build that keeps the key `false`.

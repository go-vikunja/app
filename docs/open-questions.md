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

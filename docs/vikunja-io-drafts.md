# Drafts for vikunja.io

The app's privacy policy, help page and legal notice belong on vikunja.io ([D89](decisions.md#d89-store-listing-and-web-pages-of-the-official-app)). This page holds the drafts of their texts for kolaente, who puts them into [go-vikunja/website](https://github.com/go-vikunja/website) himself; nothing here is prepared as a pull request for that repository (owner, 2026-11-17). Until he publishes them, the addresses that the app's About page and both store listings link lead to a policy without the app's section and to a missing help page, so no build is distributed before then ([store-listing.md](store-listing.md#the-website) lists the addresses).

The drafts are in vikunja.io's voice: "we" is the Vikunja project, and the controller is the one vikunja.io's privacy policy names. They are English only, like vikunja.io, in US English and with the app's own labels as `app/lib/l10n/arb/app_en.arb` has them on 2026-11-17. They follow the former privacy policy and support page of the app, which were on the owner's website until step 38f, and the writing rules of the website's help pages (second person, short sentences, labels in bold, relative links).

| File in go-vikunja/website | Change | Linked by |
|---|---|---|
| `src/pages/privacy.md` | a new subsection "Mobile app" under "Individual processing activities / operations", after "Demo Version on try.vikunja.io"; the scope in "Controller"; the date in "Effective:" | the About page: `https://vikunja.io/privacy/#mobile-app`; the stores: `https://vikunja.io/privacy/` |
| `src/content/help/mobile.mdx` | a new help page, like `desktop.mdx` | the About page's "Help and bug reports", the stores' support and marketing URL: `https://vikunja.io/help/mobile`; Play's account deletion URL: `https://vikunja.io/help/mobile#delete-your-account` |
| `src/pages/imprint.md` | the scope sentence | the About page's "Legal notice": `https://vikunja.io/imprint/` |

The app and the stores link two anchors and a slug, so these keep their words: the heading "Mobile app", the heading "Delete your account" and the slug `mobile`.

## The privacy section

**Scope.** The "Controller" section names the websites the policy covers ("As operator of the websites https://vikunja.io, https://try.vikunja.io and https://community.vikunja.io …"). Add the downloads and the app there, for example:

```markdown
As operator of the websites https://vikunja.io, https://try.vikunja.io, https://dl.vikunja.io and https://community.vikunja.io, and as publisher of the Vikunja app for Android and iOS (see [Mobile app](#mobile-app)), …
```

**The subsection,** under `## Individual processing activities / operations`, after `### Demo Version on try.vikunja.io`:

```markdown
### Mobile app

This section covers the Vikunja app for Android, iPhone and iPad ("the app"), which we publish on Google Play and the App Store and as an APK file on GitHub and dl.vikunja.io. The rest of this privacy policy applies too, in particular [Controller](#controller) and [Rights of the data subject](#rights-of-the-data-subject).

In short:

- The app has no server of its own. Apart from the crash reports you allow (below), it sends your data only to the Vikunja servers you add, to a server named in a link to a shared project that you open in it, and to try.vikunja.io if you tap **Try the public demo**.
- The app contains no analytics, no advertising and no tracking. It sends us crash reports only if you allow it, and you can turn them off at any time.
- Apart from those crash reports, we receive nothing from the app about you or about how you use it. Your tasks reach us only if you use a server that we run: the public demo or Vikunja Cloud.
- Because of the app, we process personal data only when you download the APK from dl.vikunja.io, when the app stores give us statistics and crash reports, when you allow the app's crash reports, when you test a beta version, and when you contact us.

#### Your Vikunja server

Everything you see and enter in the app (tasks, projects, comments, attachments, your profile and your settings) comes from and goes to the Vikunja server you signed in to. Whoever runs that server is responsible for the data on it, and their privacy policy applies. If the server names one, the app shows it on the **Account** tab under **Server**.

- **The public demo:** if you tap **Try the public demo**, the app connects to try.vikunja.io, and [Demo Version on try.vikunja.io](#demo-version-on-tryvikunjaio) applies. Everyone shares the demo account, so don't enter personal data there.
- **Vikunja Cloud:** if your account is on Vikunja Cloud, we run your server, and the [terms of Vikunja Cloud](VIKUNJA-CLOUD-TERMS-URL) apply.

Like any app that connects to a server, the app sends your device's IP address with every request. It also tells the server the app's name, version and build, and the name and version of your device's operating system. The server can show these in your list of sessions.

The app uses encrypted connections (HTTPS). If a server can only be reached over unencrypted HTTP, the app reads only the server's public information until you allow the unencrypted connection. After that, anyone on that network can read what is sent, including the sign-in tokens. You can withdraw this permission in the server's connection settings.

Links in tasks and comments open in your browser or another app only when you tap them, and from then on that website's or app's privacy policy applies. The same goes for the app's own links to this privacy policy, the help page, the imprint, the source code on GitHub and the Vikunja documentation. The app sends those websites nothing. Images from other websites in descriptions and comments are never loaded.

#### Signing in

You sign in on your server's own sign-in page, which the app opens in your device's browser. The app never sees your password or your two-factor code. The server gives the app tokens for your session, which the app keeps in the device's secure storage (the Keychain on iOS, storage protected by the Android Keystore on Android). Creating an account, resetting or changing your password, changing your email address and deleting your account also happen on your server's web pages, which the app opens.

If you open a project that someone shared with you by link, the app signs you in as a guest and keeps the link and the guest's token in the secure storage. If the link has a password, the app asks for it and never saves it.

#### Data on your device

So that the app works offline, it keeps the following in its own storage on your device:

- for each account, a copy of your projects, tasks and notifications, the attachments list, reactions and comments of tasks you opened, changes and uploads not sent yet, drafts of comments and descriptions, attachments you opened (cached for up to three days after their last use), and the images and profile pictures you saw (up to 100 MB, each kept for up to 30 days after its last use);
- the sign-in tokens and, if you set them up, your servers' access headers and client certificates, in the secure storage;
- the list of your accounts with server address, username and name, the connection settings, and your settings on this device.

The app sends none of this anywhere but to your server. It does not encrypt this data itself and relies on your device's encryption, so please use a screen lock. The app lock, if you turn it on, guards the screen, not the stored data.

When you sign out of an account or remove it, the app deletes that account's data, drafts, widget content, notifications and tokens from the device, and asks the server to end the session. Changes not sent yet are lost, and the app warns you first. A server's connection settings stay until you forget them, and the app offers to forget them when no other account uses that server. Deleting the app deletes its data. On iOS the system can keep the secure storage after the app is deleted, and the app clears it the first time it starts after being installed again. A session you never signed out of ends on the server once it has gone unused for the server's session lifetime, three days by default.

On Android, the app's data is excluded from backups and device transfers. On iOS, the copy of your tasks, the uploads not sent yet, your drafts and the widgets' content are excluded from backups, while your settings, the account list and the connection settings are part of the device's backup. The secure storage never moves to another device.

#### Notifications and widgets

The app creates reminders, due dates and activity from your server as notifications on your device, from its copy of your tasks. No push service is involved: nothing about your tasks passes through us, Google or Apple to reach your device. The home screen widgets, and on iOS the Lock Screen widgets, show what the app saved on your device after its last sync.

Notifications and widgets can show task titles on the lock screen and the home screen. You choose what they show on the **Account** tab under **App lock and privacy**.

#### Permissions

The app asks only for permissions that one of its features needs: network access; notifications; exact alarms (Android), so that reminders come on time; running after a restart and in the background, to plan reminders and sync; Face ID, fingerprint or screen lock, only for the app lock; the camera, for photos you attach or use as your avatar; the photos and files you pick in the system's picker or share to the app; adding to your photos (iOS), which the system asks for the first time you save an attachment there; and the local network (iOS), to reach a server at home or at work. The app has no location permission and never reads your device's location.

The app removes the location from photos and videos that you pick in the photo picker or take with the camera, from pictures that you pick as files, and on Android also from photos and videos that you share to the app, before it stores them for upload. If it finds a location that it cannot remove, it asks you before the upload and skips the file unless you choose to upload it anyway, for files you pick and files you share alike. Some locations the app does not find, and these stay in the file: on Android for example a location in a separate video track (action cameras, dashcams), the video of a motion photo, place names such as the city, a location in a camera maker's own metadata, and formats such as GIF, WebM or MKV. Other files that you pick as files, such as videos and documents, are uploaded unchanged.

#### Crash reports

If you allow it, the app sends a report to the Vikunja project's error tracking at Sentry (Functional Software, Inc.) when an error occurs or the app crashes, so that we can find and fix defects. The app asks you once after your first sign-in, and you can change your answer at any time on the **Account** tab under **App lock and privacy**. Until you allow it, the app sends no reports. When you turn them off, it stops at once and deletes the reports it has not sent yet. What you chose in the earlier Vikunja app is not carried over.

A report contains the error and where in the app it occurred, the app's warnings before it, the app's version, your device's model and the version of its operating system. Before a report leaves your device, the app removes server addresses, account details and anything else it recognizes as your data, such as IP addresses, file paths, tokens and email addresses, and it sends an error's own text only for kinds of errors whose text it can strip of your data. As the app recognizes your data by patterns, a rare error text may still carry a piece of it, such as part of a task's title. A report can contain the app's internal numbers of a task or a saved filter. Like every request, it reaches Sentry with your device's IP address, which Sentry does not store for us. Sentry processes the reports on our behalf, SENTRY-REGION, and we keep them for SENTRY-RETENTION days. The legal basis is your consent (Art. 6(1)(a) GDPR), which you can withdraw at any time with effect for the future by turning the crash reports off.

#### App stores, downloads and beta versions

Google Play and the App Store handle downloads, updates, ratings and diagnostics under their own responsibility (see the privacy policies of [Google](https://policies.google.com/privacy) and [Apple](https://www.apple.com/legal/privacy/)). Depending on your device's settings, they give us statistics and crash reports that do not tell us who you are. We use them to find and fix defects. The legal basis is Art. 6(1)(f) GDPR, and our legitimate interest is an app that works. They stay in the stores' consoles for as long as the stores keep them.

If you test a beta version through Google Play, Google does not tell us who you are; we see only the feedback you send through Google Play. If you test it through TestFlight on iPhone or iPad, we see what TestFlight shows us about you, such as your email address, and the feedback and crash reports you send. We use them only to run the beta (Art. 6(1)(b) GDPR) and remove you from the list of testers when the beta ends or you leave it.

If you download the APK file from GitHub, [GitHub's privacy statement](https://docs.github.com/en/site-policy/privacy-policies/github-general-privacy-statement) applies. If you download it from dl.vikunja.io, [Server log files](#server-log-files) applies.

#### Questions and bug reports

If you email us about the app, we use your address and message only to answer you, and delete them once your request is dealt with, unless the law requires us to keep them longer. The legal basis is Art. 6(1)(b) GDPR where your message concerns a contract with us, otherwise Art. 6(1)(f) GDPR, our legitimate interest being to answer messages sent to us. Issues in the app's repository on GitHub are public, and GitHub processes them under its own privacy statement. The app's **Support details** leave your device only if you share them yourself, and they never contain your tasks, names or passwords.

#### Your rights

You have the rights described under [Rights of the data subject](#rights-of-the-data-subject). To use them, write to [hello@vikunja.io](mailto:hello@vikunja.io).

We have no access to the data on your Vikunja server, unless it is a server we run, or to the data on your device. For the data on a server, contact whoever runs it. The data on your device you can delete yourself, by signing out, by forgetting a server's connection settings or by deleting the app.
```

Then the line `Effective:` gets the date the section is published.

Notes for kolaente:
- `VIKUNJA-CLOUD-TERMS-URL` is Vikunja Cloud's terms or data processing agreement; `vikunja.cloud/privacy` and `vikunja.io/terms` were 404 on 2026-11-16. Whether the app's texts name Vikunja Cloud as a server at all is yours to decide; without it, the Vikunja Cloud item and its mention in the short list go.
- The anchors `#controller`, `#rights-of-the-data-subject`, `#demo-version-on-tryvikunjaio` and `#server-log-files` are the headings of the policy as read on 2026-11-17. Whether "Server log files" covers dl.vikunja.io, and the legal bases and periods above, are yours to check. None of this is legal advice.
- **Crash reports** (step 41, [D113](decisions.md#d113-opt-in-crash-reports-through-vikunjas-sentry)): `SENTRY-REGION` is where Vikunja's Sentry organisation stores its data, for example "in the United States, under the EU Standard Contractual Clauses" or "in the EU", and `SENTRY-RETENTION` the project's retention. "Which Sentry does not store for us" holds once the project's "Prevent Storing of IP Addresses" is on ([beta.md](beta.md#what-kolaente-does)). Whether Sentry's data processing agreement covers the app, and whether the policy's existing Sentry section, written for try.vikunja.io, should name the app as well, are yours to check. A build without the project's key has no crash reports at all; the texts stay true for it.
- The earlier Vikunja app, which this app replaces on Google Play, also sends crash reports, traces, profiles and logs to Sentry if its user turned on **Enable Sentry** or said yes when it asked (off by default), and Play's Data safety declares them for it ([store-listing.md](store-listing.md#app-content)). Both apps send to the same Sentry project (owner, 2026-11-21), and devices that never update keep sending the old app's reports, so either the section names them, for example "The earlier Vikunja app, which this app replaces, sends error reports to Sentry if you turned that on in its settings.", or you confirm that the policy's existing Sentry section covers them.
- The iOS parts assume that Vikunja's Apple account publishes the app: the scope sentence ("publisher of the Vikunja app for Android and iOS"), "which we publish on … the App Store", the App Store half of "give us statistics and crash reports" and the TestFlight sentences. Which Apple account publishes is still open ([D83](decisions.md#d83-successor-of-the-official-vikunja-app-in-go-vikunjaapp), [D89](decisions.md#d89-store-listing-and-web-pages-of-the-official-app)). If another account publishes, these sentences name that account as the App Store publisher and as the controller of the App Store statistics and the TestFlight testers' data. Until the account is decided, they can name Android only and leave out the App Store and TestFlight.
- The beta runs on Google Play's open testing track and TestFlight's public link. What App Store Connect shows of testers who join through a public link is to check before the first TestFlight beta.
- The help page's address and the beta's email address are in the app's other texts; if a maintainers' address for testers is set up, the section can name it beside hello@vikunja.io.

## The help page

`src/content/help/mobile.mdx`, which the website serves as `https://vikunja.io/help/mobile`:

```mdx
---
title: Mobile App
slug: mobile
description: >-
  Get the Vikunja app for Android and iOS, sign in to your server, work offline,
  get reminders and widgets, delete your account and report a bug.
---

The Vikunja app brings your tasks to your Android phone or tablet, iPhone and iPad. It keeps a copy of your projects and tasks on your device, so you can read and change them without a connection. Your changes go to your server as soon as it can be reached.

## Get the app

- **Android:** [Google Play](https://play.google.com/store/apps/details?id=io.vikunja.app). Without Google Play, install an APK from the [GitHub releases](https://github.com/go-vikunja/app/releases) or [dl.vikunja.io](https://dl.vikunja.io/app/): the one for your phone's processor, usually `arm64-v8a`, is much smaller than the one for every device. Each release lists the SHA-256 of every APK and that of the signing certificate. An APK installed this way gets no updates by itself, security fixes included.
- **iPhone and iPad:** APP-STORE-LINK

The app needs Android 7.0 or newer, or iOS 15 or newer, and a Vikunja server with version 2.3.0 or newer. It is free, without ads or in-app purchases.

To test new versions before they are released, join the beta on [Google Play](https://play.google.com/apps/testing/io.vikunja.app) or through TESTFLIGHT-LINK.

### Updating from the earlier Android app

The app replaces the earlier Vikunja app on Google Play and updates it. On its first start it fills in your server's address and tries to keep you signed in; if that does not work, sign in again. Your theme and language come along. Widgets you placed stay on your home screen: after you sign in, tap one to set it up again.

## Signing in

1. Open the app and enter your server's address, the one you open Vikunja with in your browser, for example `https://vikunja.example.com`.
2. Tap **Continue**. The app checks the server.
3. Tap **Continue to sign-in** and sign in on your server's page in the browser. Single sign-on works too. The app never sees your password.

If your server sits behind an access proxy that needs extra headers, uses its own certificate or asks for a client certificate, set that up under **Connection options** below the address field. Where your server allows it, **Create account** and **Forgot password?** open the server's own pages.

To open a project someone shared with you by link, without an account, paste the link into the address field or tap **Open a shared link**.

To add another account, on the same server or another one, tap **Add account** under **Accounts** on the **Account** tab.

### Try it without a server

Tap **Try the public demo** and sign in with username `demo` and password `demo`. Everyone shares this account, and the demo is reset regularly, so don't enter anything personal and don't delete the account.

## Working offline

After the first sync, lists, tables, timelines, filters, saved filters and search work offline. Checking off, creating and editing tasks, descriptions and their checklists, subtasks and relations, moving cards on a Kanban board, adding attachments and creating labels work offline too; they are sent when the server can be reached. A task you opened before shows its attachments, reactions and comments offline as they were then, with the time they were loaded, and the images you saw stay on your device for up to 30 days. Writing comments and reactions, deleting attachments, changing or deleting a label that is already on your server, managing projects, views and Kanban columns, teams and sharing need a connection.

While you are offline, a banner says so. On the **Account** tab, **Pending changes** shows how many changes are waiting, with **Send now**, and **Sync problems** lists the changes the server refused, which you can try again or discard. If you sign out while changes are waiting, they are lost; the app warns you first.

## Working through a list

Swipe a task to the right to check it off, or to the left to change its due date. With a screen reader, both are among the task's actions.

To change several tasks at once, touch and hold one of them, or choose **Select tasks** in the list's menu, then tap the others. The bar at the bottom checks them off, changes their due date or priority, moves them to another project or deletes them; each can be undone right after, a delete on Vikunja 2.8.0 and later. In a project sorted by hand, touching and holding a task moves it, so there use **Select tasks**.

**Reschedule** next to **Overdue** moves all overdue tasks at once: to today, tomorrow or next week, each keeping its time of day (moved to today, a time that has passed becomes the end of the day), or to one date and time you pick.

## Reminders and notifications

The app creates reminders on your device from its copy of your tasks, at each reminder and at the due time, so they come without a connection too. A task created on the web reaches your device with the next sync: about every 30 minutes on Android while the app is closed, and when iOS allows it on iPhone and iPad. Opening the app syncs at once.

On Vikunja 2.8.0 and later, reminders and due dates come for the tasks you follow: the ones you create or are assigned to, and those in projects you follow. To follow a task or stop its notifications, tap the bell at the top of the task (**Follow task** or **Unfollow task**), or choose **Follow project** in a project's menu; this needs a connection.

A reminder can be snoozed from the notification: for an hour or until tomorrow morning (at your default due time, else 9:00), on iPhone and iPad also for ten minutes.

The **Notifications** section of the **Account** tab sets, for each account, which notifications you get, and has **Send a test notification**.

## Widgets

On Android, add a Vikunja widget to your home screen; on iPhone and iPad with iOS 17 or newer, to the Home Screen or the Lock Screen. A list widget shows Today, the next days, Overdue, your favorites, a project, a label or a saved filter, and you can check tasks off right there. A second widget adds a new task. Widgets show what the app saved after its last sync.

To keep task titles off the lock screen, open **App lock and privacy** on the **Account** tab.

## Languages

The app uses your device's language when it has a translation, and English otherwise. To use another language for the app alone, tap **App language** under **Appearance** on the **Account** tab (on Android 13 or newer, and on iPhone and iPad), which opens your system's setting for it. The Vikunja community translates the app on [Crowdin](https://crowdin.com/project/vikunja); a language comes into the app once at least half of it is translated.

## Known limits

- The **Gantt** view is read-only. To change a task's dates, open the task.
- The app has no time tracking yet.
- Changing your password or email address, two-factor authentication, exporting your data and deleting your account happen on your server's web pages, which the app opens.
- There are no keyboard shortcuts yet.
- A yearly repeat is every 365 days, as Vikunja has no calendar year as a repeat, so it moves by a day after each 29 February.
- Vikunja sends no push notifications, so a reminder you add on the web reaches your device with the next sync.
- Comments, reactions and a task's attachments show offline only as they were when you last opened the task online; new ones load with a connection.

## Troubleshooting

- **The app cannot reach your server:** open the address in your phone's browser. If the browser warns about the certificate, set up the server's certificate under **Connection options**. If the server answers only over unencrypted HTTP, the app asks before it uses it. If you typed the address without `https://` and the server answered only over HTTP, the app asks each time, as someone on the network may be blocking HTTPS; if your server really uses only HTTP, type the address with `http://`.
- **This server is too old:** the app needs Vikunja 2.3.0 or newer. Ask whoever runs the server to update Vikunja.
- **Reminders come late (Android):** allow exact alarms. The **Notifications** section of the **Account** tab shows **Reminders may be late** with **Allow exact alarms**.
- **No notifications:** if notifications are off for the app, the **Notifications** section says so, with **Turn on**. Then try **Send a test notification**.
- **A change does not show on the web:** look at **Pending changes** and **Sync problems** on the **Account** tab.
- **A widget shows old tasks:** open the app once; it updates the widgets after each sync.

### A server behind a sign-in proxy

If your Vikunja sits behind Authelia, Authentik, oauth2-proxy or another proxy that asks everyone to sign in first, the app's requests cannot pass it: they carry Vikunja's own token, not the proxy's cookie. Let the API through and keep the web pages behind the proxy. Vikunja checks every API request itself, and the app's sign-in runs through the web pages, where the proxy still asks first. Everything the app needs is under `/api/`.

- **Authelia:** a rule before your other rules for the domain, with `policy: bypass` and `resources: ['^/api/.*$']`.
- **Authentik** (proxy provider): add `^/api/.*` to **Unauthenticated Paths**.
- **oauth2-proxy:** `--skip-auth-route='^/api/'`.
- **Traefik with forwardAuth:** a second router for `Host(`tasks.example.com`) && PathPrefix(`/api/`)` with the same service and without the forwardAuth middleware.

The API also holds Vikunja's own password sign-in and, when it is open, registration: once `/api/` is let through, anyone who reaches your server can try a username and password there without passing the proxy. If the proxy was your only second factor, have everyone who signs in with a password turn on two-factor authentication in Vikunja's settings. If everyone signs in through OpenID Connect, you can turn off password sign-in (`auth.local.enabled: false`) and registration (`service.enableregistration: false`) in Vikunja's configuration.

A proxy that only checks a header, such as Cloudflare Access with a service token, works without this: add the header under **Connection options**.

## Delete your account

Your account lives on the Vikunja server you signed in to, not in the app. You delete it on that server, and the app takes you there:

1. On the **Account** tab, open **Account settings**.
2. At the bottom, tap **Delete account**. The app explains what happens; **Continue in the browser** opens your server's page, where you confirm. If your account has a password, the page asks for it.
3. Your server emails you a link to confirm. Three days after you confirm, the account is deleted. Until then the **Account** tab shows the date, with **Cancel deletion**.

On the web, do the same under [Delete account](/help/settings#delete-account) in the settings.

Vikunja deletes your account with all projects and tasks you own; what you shared with others passes to them. Whether the server keeps anything longer, for example in its backups, depends on whoever runs it. If the row reads **Not allowed by this server**, or no email arrives, ask whoever runs your server to delete the account. Please don't delete the shared account of the public demo.

### Removing an account only from your device

To keep the account on the server but remove it from the app, tap **Sign out** at the bottom of the **Account** tab, or **Remove…** beside an account under **Accounts**. As a guest of a shared link, tap **Remove guest access**. The app then deletes that account's data from your device. Changes not sent yet are lost, and the app warns you first.

Uninstalling the app deletes its data from your device, but not your account on the server. On iPhone and iPad the system can keep the secure storage (sign-in tokens, access headers and client certificates) after the app is deleted; the app clears it the first time it starts after being installed again.

## Report a bug

Open [a new issue](https://github.com/go-vikunja/app/issues/new/choose) on GitHub and pick the bug or the feature form. Questions are welcome in the [community forum](https://community.vikunja.io) and on [Matrix](https://matrix.to/#/#vikunja:matrix.org). Without a GitHub account, write to [hello@vikunja.io](mailto:hello@vikunja.io).

In the app, tap the version at the bottom of the **Account** tab to open **About the app**. **Support details** shows the versions and settings that help find a bug, and shares them when you tap **Share**, without your tasks, names or passwords.

Never send passwords or tokens. We will never ask for them.

## Report a security problem

Report it privately, by email to security@vikunja.io, never in a public issue. [Security](/security) has the PGP key, and the app's [security policy](https://github.com/go-vikunja/app/blob/main/SECURITY.md) has the details.

## Privacy and source code

The app has no server of its own and no ads or analytics, and it sends crash reports only if you allow them; whoever runs your server is responsible for the data on it. The [privacy policy](/privacy#mobile-app) has the details.

The app is open source under the MIT License, and its code is on [GitHub](https://github.com/go-vikunja/app). The name Vikunja and its logo are not covered by the license.
```

Notes for kolaente:
- `APP-STORE-LINK` and `TESTFLIGHT-LINK` wait for the Apple account that publishes the app; until then the iPhone and iPad line can say "Coming soon", and the beta line can name Google Play alone. The privacy section's iOS sentences wait for the same account (its notes above).
- The labels are the app's as of 2026-11-17. A later change of a label, of what works offline or of the supported versions changes this page too.
- Optional: a link to this page from `/install` or the features page, with the store badges.

## The imprint's scope sentence

In `src/pages/imprint.md`, the sentence that says which sites the imprint covers:

```markdown
This imprint is valid for vikunja.io, vikunja.cloud, console.vikunja.io and the Vikunja apps.
```

"The Vikunja apps" takes in the desktop app too; "and the Vikunja app for Android and iOS" covers only this one. This is kolaente's legal call.

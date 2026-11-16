# Beta and 1.0.0

The owner's runbook for step 37d ([D77]): from the move into go-vikunja/app through the closed test on Google Play and the TestFlight beta to 1.0.0 in both stores. Each part comes in the order it is done. [releasing.md](releasing.md) has how a release is cut and every one-time setting, and [store-listing.md](store-listing.md) every console form with its answer; this page links them and adds what neither covers. The tester-facing texts are in English and German. None of this is legal advice.

Since [D83](decisions.md#d83-successor-of-the-official-vikunja-app-in-go-vikunjaapp) the beta runs in the official Vikunja listing, after the switch of steps 38a to 38f: the app is called Vikunja, its id is the official app's `io.vikunja.app` ([D15](decisions.md#d15-app-id-iovikunjaapp-and-the-name-vikunja)), the Play app is the one in Vikunja's Play account, and its bundles are signed with Vikunja's upload key. Since step 38a the names, ids and texts on this page are the official app's. Since step 38c the parts on CI, the keys and the releases (1, 2, 7 to 9, and the release steps during the beta and before 1.0.0) describe GitHub Actions in go-vikunja/app ([D86](decisions.md#d86-ci-and-releases-on-github-actions)); parts 3 to 5, the closed test and the tester texts are still written for a beta under the owner's own accounts and are rewritten with step 38f, before 37d goes on. Since step 38d (in review; [D87]) the repository is under the MIT License, GitLab's pipeline is gone, and [the move](#the-move) comes first.

The owner's decisions of 2026-11-02 behind it ([D77]): [Q20](open-questions.md#q20-signing-keys-and-the-apk-beside-the-play-build)'s option A for the keys; a new app id, since step 38a the official app's `io.vikunja.app` ([D15](decisions.md#d15-app-id-iovikunjaapp-and-the-name-vikunja)); a "Help and bug reports" row on the About page; the closed test's testers through a Google Group and TestFlight's external testers through a public link; testers on their own Vikunja server (2.3.0 or newer) or the public demo, `try.vikunja.io`. iOS builds stay on the owner's Mac.

## The move

Step 38d ([D87]): the repository joins go-vikunja/app with its whole history, so that every commit hash the docs cite stays valid. The pull request comes from the owner's fork and has only two commits of its own: one removes the old app's files, and one merges our `main` with `--allow-unrelated-histories`. The tree it leaves is exactly our `main`. The commands below were rehearsed on 2026-11-16 against a local copy of go-vikunja/app and a local stand-in for the fork, the pushes and the merge included.

### Before you start

- 38d's own changes are on our `main`, reviewed and green, so the imported tree is the reviewed one.
- kolaente has agreed to the freeze of go-vikunja/app's `main`, from the tag of step 3 until the merge, and has changed the ruleset for the import ([what kolaente does](#what-kolaente-does)).
- The GitHub account has `coderoftime@gmail.com` as a verified email, so that GitHub links the commits to it, and "Block command line pushes that expose my email" is off, or the push fails with GH007.
- The tracked test-server users, `test_servers/seed/e2e-user.env` and `e2e-user-2.env`, hold nothing used anywhere else. The history goes public unchanged: it holds no real secret, and most of it is public on GitLab already.
- The push to the fork publishes: commits pushed there stay reachable from every repository of the network, go-vikunja/app included, even after the fork is deleted ([forks][gh-forks]). Push nothing that has not passed the checks below.

### The commands

```sh
# 1. A fresh clone beside the working repository; the working copy and its stash stay untouched
WORK=~/path/to/the/working/repository
git clone https://github.com/go-vikunja/app.git vikunja-import
cd vikunja-import
git config user.name "Benedikt Lesch"
git config user.email "coderoftime@gmail.com"

# 2. Our main from the working repository: no tags, no stash
git remote add ours "$WORK"
git fetch --no-tags ours main
test "$(git rev-parse ours/main)" = "$(git -C "$WORK" rev-parse main)" && echo "ok: ours is the reviewed main"

# 3. The freeze starts: tag the old main's last commit and push the tag alone
git rev-parse origin/main   # cdbc6e39ac9b52c58443cb353c324342dd7ce6c7, unless something was merged since 2026-11-03
git tag -a legacy-final -m "The old Vikunja app's last commit before the new app was imported" origin/main
git push origin refs/tags/legacy-final   # needs write access to go-vikunja/app; starts no workflow

# 4. The import branch: remove the old app, then merge our main
git switch -c import-new-app origin/main
git rm -r -q .
git commit -m "chore: remove the old app before importing the new one" \
  -m "The new Vikunja app replaces it; its last commit is tagged legacy-final."
git merge --allow-unrelated-histories --no-ff ours/main \
  -m "feat: import the new Vikunja app with its history" \
  -m "Joins the new app's history (formerly Rurana) to the old app's, so every commit hash of both stays valid."
```

The removal takes everything of the old app: its workflows and `.drone.yml`, the `Makefile`, the devenv files and `.envrc`, `renovate.json` and `crowdin.yml` (no Crowdin sync until step 38e), `.vscode`, `.metadata` and the old Flutter tree. The old tags and releases stay; there is no `legacy` branch.

### The checks before pushing

Each line must print `ok`, or show what its comment says:

```sh
B=import-new-app
test "$(git rev-parse "$B^{tree}")" = "$(git rev-parse 'ours/main^{tree}')" && echo "ok: the tree is exactly our main"
test -z "$(git diff --stat "$B" ours/main)" && echo "ok: nothing differs from our main"
git merge-base --is-ancestor legacy-final "$B" && echo "ok: the old main is an ancestor, so the PR has no conflicts"
git merge-base --is-ancestor ours/main "$B" && echo "ok: every hash of ours stays"
test -z "$(git status --porcelain)" && echo "ok: the working tree is clean"
git log --format='%an <%ae> | %cn <%ce>' legacy-final.."$B" | sort | uniq -c   # one line: coderoftime@gmail.com
git ls-tree --name-only "$B:.github/workflows"                                  # ci.yaml and release.yaml only
git rev-list --objects legacy-final.."$B" | git cat-file --batch-check='%(objecttype) %(objectsize) %(rest)' |
  awk '$1 == "blob"' | sort -k2 -n | tail -1                                    # far below GitHub's 50 MiB warning
git log --graph --oneline -8 "$B"
```

### The pull request

```sh
gh repo fork go-vikunja/app --clone=false --remote=false   # or "Fork" on github.com; skip it if the fork exists
git remote add fork https://github.com/<your-login>/app.git
git push fork import-new-app                               # this branch only: never --all, --tags or --mirror
gh pr create --repo go-vikunja/app --base main --head <your-login>:import-new-app \
  --title "feat: import the new Vikunja app with its history" --body-file ../pr-body.md
```

Push only from this clone and only this branch: `--mirror` from the working repository would also publish its parked stash (D59), and tags have no place in the fork. `../pr-body.md`, outside the clone:

```markdown
This imports the new Vikunja app, announced in #343, with its whole history (D83 in `docs/decisions.md`).

It has two commits of its own:
1. `chore: remove the old app before importing the new one` removes every file of the old app. Its last commit is tagged `legacy-final`; the old tags and releases stay.
2. `feat: import the new Vikunja app with its history` merges the new app's `main` (formerly Rurana) with `--allow-unrelated-histories`. The resulting tree is exactly that `main`.

**Please merge with "Create a merge commit".** Squash or rebase would rewrite or drop the imported commits, whose hashes the docs cite.

`main` stays frozen at `legacy-final` until this is merged. The "Files changed" tab cannot show a change this large; review it by commit, or locally with `git diff --stat legacy-final import-new-app`.

AI disclosure: the new app was written with Claude Code, Anthropic's AI coding tool; each commit names the model in a `Co-Authored-By` line. I reviewed every step and answer for every line.
```

The pull request runs `checks`, `editor`, `contract`, `android`, `osv` and `ios`; the old app's workflows are deleted in its merge ref and do not run. GitHub's macOS runner may need a re-run of `ios` ([releasing.md](releasing.md#when-the-publish-job-fails)).

### The merge

Before the click, `main` must still be the tagged commit, and all six checks must be green:

```sh
git ls-remote https://github.com/go-vikunja/app refs/heads/main 'refs/tags/legacy-final*'
# main's hash equals the one of the line refs/tags/legacy-final^{}
```

kolaente or another maintainer approves; the author cannot. The owner merges with **Create a merge commit**. Then, in the clone:

```sh
git fetch origin
git merge-base --is-ancestor ours/main origin/main && echo "ok: every hash of ours is on main"
test "$(git rev-parse 'origin/main^{tree}')" = "$(git rev-parse 'ours/main^{tree}')" && echo "ok: main's tree is ours"
test "$(git rev-parse 'origin/main^1')" = "$(git rev-parse 'legacy-final^{commit}')" && echo "ok: the first parent is legacy-final"
```

### Afterwards

- kolaente restores the ruleset: linear history again, squash only recommended.
- The working repository follows go-vikunja/app, and later pull requests go through the fork; its stash stays:

  ```sh
  WORK=~/path/to/the/working/repository   # the same path as in step 1
  cd "$WORK"
  git remote set-url origin https://github.com/go-vikunja/app.git
  git remote add fork https://github.com/<your-login>/app.git
  git fetch origin
  git switch main && git merge --ff-only origin/main
  git remote get-url origin   # must print https://github.com/go-vikunja/app.git
  ```

- The GitLab project gets a description that points to https://github.com/go-vikunja/app and is archived (Settings > General > Advanced > Archive project). It is not deleted before step 38f has changed the website's links to it.
- The test repository of step 38c is deleted or made private.
- The result goes into [D87], which settles D83's open point on how the two histories are joined.

### What kolaente does

A list for the owner to forward:

- **The ruleset "main protect", for the import:** allow merge commits (best: merge commits only until the import is merged, so that nobody squashes it by mistake) and turn "Require linear history" off; "Allow merge commits" must be on under Settings > General > Pull Requests too. Replace the required checks `Test / lint`, `Test / test` and `Test / build` with `checks`, `editor`, `contract`, `android`, `osv` and `ios`. After the merge, restore linear history; squash only is recommended.
- **The name-and-logo text** in `NOTICE.md`: confirm it, and say who holds the copyright of the logo.
- **Private vulnerability reporting:** turn it on, with the owner as a security manager ([releasing.md](releasing.md#once-in-go-vikunjaapp) step 12).
- **CODEOWNERS** for `.github/` and `tool/ci/release_certificates.txt`: a suggestion.
- **FUNDING.yml:** a suggestion.
- **devenv:** the import removes the old app's devenv files; add one for the new app if you want it.
- **The 8 stale branches** of the old app: keep or delete them.
- **The release secrets,** entered again as secrets of the environment `release`, with no repository or organisation copy ([releasing.md](releasing.md#once-in-go-vikunjaapp) steps 1 and 2).
- **The certificate fingerprints** in `tool/ci/release_certificates.txt` (step 3 there).
- **The written offer** for the desugar_jdk_libs source: who makes it and with which contact, settled in step 38f.

## Before beta.1

### 1. The repository and CI

The releases come from GitHub Actions in go-vikunja/app after [the move](#the-move) (step 38d; [D86](decisions.md#d86-ci-and-releases-on-github-actions)). Until then the CI scripts run on the Mac and in the owner's test repository, and nothing is published.

1. **The trial:** done on 2026-11-16 in a test repository of the owner's, with the repository variable `VIKUNJA_APP_RELEASE_DRY_RUN=true` and no secret, as [releasing.md](releasing.md#the-dry-run) describes. A test tag there ran the release with throwaway keys and published nothing. [D86](decisions.md#d86-ci-and-releases-on-github-actions) has the results.
2. **go-vikunja/app,** after the move: Vikunja's maintainers set up the environment `release`, its secrets, the committed certificates, the rulesets, the Actions settings and private vulnerability reporting ([releasing.md](releasing.md#once-in-go-vikunjaapp)). The old pipeline's upload of every push to `main` to Play stops with the import, which removes its workflow.

### 2. The keys

The keys are Vikunja's ([D83](decisions.md#d83-successor-of-the-official-vikunja-app-in-go-vikunjaapp)): the old app's upload key signs the bundles and, without a separate APK key, the APK, as in the old app, so installs of the old app's APKs keep updating. [Q20](open-questions.md#q20-signing-keys-and-the-apk-beside-the-play-build)'s option A, an app signing key of the owner's, no longer applies, and the owner creates no key.

- **The secrets:** `KEYSTORE_BASE64` and `KEY_PROPERTIES`, the Play service account and the dl.vikunja.io storage keys, entered again by Vikunja's maintainers as secrets of the environment `release`, with no repository or organisation copy ([releasing.md](releasing.md#once-in-go-vikunjaapp) steps 1 and 2). The key that signs the APK must be RSA.
- **The certificates:** the upload certificate's SHA-256 from the Play Console, committed in `tool/ci/release_certificates.txt` before the tag ([releasing.md](releasing.md#once-in-go-vikunjaapp) step 3); a real release fails without it.
- **Developer verification:** the key that signs the APK is registered in Vikunja's Play Console, so that certified devices that require a registered key install the APK ([developer verification][android-verification]).

### 3. The Play developer account

- **A personal account**, non-trader when asked at creation ([store-listing.md](store-listing.md#app-content), trader status). Play shows the developer's legal name, email and country on the listing.
- **A real Android phone verified** with the Play Console app before the first rollout to testers (Google asks it of new personal accounts before their apps are available; whether a closed test counts is not stated, so do it first): any physical phone with Android 10 or later, not rooted; an emulator does not count. The task is on the Play Console's Home page: scan its QR code, sign in to the Play Console app as the account owner and verify ([device verification][play-device]).

### 4. The Play app

- **The app** is the one in Vikunja's Play account, `io.vikunja.app` ([D83](decisions.md#d83-successor-of-the-official-vikunja-app-in-go-vikunjaapp)); whether the owner gets release rights there is open; the release workflow uploads through Vikunja's service account either way ([part 2](#2-the-keys)). (The plan before the switch, an app with Play App Signing on the owner's key, no longer applies.)
- **Every form** as [store-listing.md](store-listing.md#google-play-console) answers it: store settings and contact details, the listing in both languages with the graphics of `branding/png/`, the privacy policy, App access with the public demo, Ads, Content rating, Target audience, News, Data safety, Government, Financial features, Health, Advertising ID. After the first upload, check that App content asks for no exact-alarm or foreground-service declaration.
- **The screenshots:** the closed test needs the whole listing, screenshots included. The phone and tablet sets in both languages are in `fastlane/metadata/android/*/images/` (taken on 2026-11-03, [store-listing.md](store-listing.md#screenshots)). Since 36g is in the beta, the tablet shots 02 (Kanban) and 04 (a project) show the Projects tab without the project tree's column; retake them on the tablet emulator in landscape with the demo data before the listing goes live (the owner signs in). The App Store's sets wait for a session on the simulators before the 1.0.0 submission ([before 1.0.0](#before-100)); TestFlight needs none.

### 5. The Apple account and the app record

[releasing.md](releasing.md#once-before-the-first-upload) has each step:

- the Apple Developer Program (the enrolled name shows as the seller; renewed every year), the team id, Xcode signed in with an iPhone registered;
- the App IDs `io.vikunja.app` and `io.vikunja.app.widgets`, both with only the App Group `group.io.vikunja.app` (Xcode creates them on the first signed build, or by hand under Identifiers). Which Apple account publishes the app is open, and `io.vikunja.app` may already be taken at Apple; until both are settled, no build for a device with automatic signing ([D15](decisions.md#d15-app-id-iovikunjaapp-and-the-name-vikunja));
- the app record `Vikunja` with the bundle id `io.vikunja.app`, which reserves the name, so create it early (if the name is taken, step 38f picks the fallback);
- the App Store Connect API key, outside the repository;
- the source link, the tree at the tag of `VIKUNJA_APP_SOURCE_CODE_URL`, by default https://github.com/go-vikunja/app, which has the tag only after the move (step 38d; [releasing.md](releasing.md#once-before-the-first-upload) step 6);
- the App Store Connect forms and TestFlight's test information ([store-listing.md](store-listing.md#app-store-connect)).

### 6. The Impressum

The website has been live since 2026-11-02; only the Impressum's c/o address for service and its phone number are missing ([releasing.md](releasing.md#the-website-and-the-store-listings) step 1). They go into the website's repository and are deployed before the first rollout to testers.

### 7. The first runs

The test repository's trial ([part 1](#1-the-repository-and-ci)) ran the workflows on GitHub for the first time, and the paths that only GitHub's hosted runners take passed:
- the Flutter tarball and the macOS zip with their checksums;
- ShellCheck over `tool/ci/`, after one round of fixes;
- the contract tests on the runner's own Docker;
- the NDK install and JDK 21;
- the osv-scanner Linux binary and Gradle's memory caps;
- the macOS build with Xcode 26.6.

Still to watch in go-vikunja/app, from the import's pull request on:
- anonymous pulls from Docker Hub against its rate limits (a login is not built);
- GitHub's macOS runners, which three times had none free for `ios` ([releasing.md](releasing.md#when-the-publish-job-fails)).

Each fix is a commit on `main`; the tag waits for a green run. The environment, the real signing and the publishing first run on go-vikunja/app's first tag.

### 8. The threat model

Each beta is public: its tag publishes a GitHub release with the APK, marked as a prerelease, and the APK on dl.vikunja.io ([D86](decisions.md#d86-ci-and-releases-on-github-actions)), TestFlight's link is public, and anyone can join the Google Group. So the [threat model](threat-model.md#84-sign-off)'s review "before each store release" comes before `v1.0.0-beta.1` ([D77]):

- [ ] **Section [8.2](threat-model.md#82-manual-on-the-android-emulator) on the emulator** in full with the release build, the owner signing in the two accounts, items 5 and 10 on a Google Play image; with it the R33 check, a start of `MainActivity` from another app's activity without `FLAG_ACTIVITY_NEW_TASK` (`adb shell am start` adds that flag, so it needs a caller app), with the fix R33 describes.
- [ ] **Section 8.1** on the tree to be tagged, with its checks of the settings of go-vikunja/app.
- [ ] **The owner's sign-off** in [section 8.4](threat-model.md#84-sign-off): the residual risks of section 7 accepted or reopened, and the questions that R19, R21, R33 and R36 leave to the owner answered (R17 is accepted for the beta, owner 2026-11-12). Section 8.3 waits for the device test; the row says so.

### 9. Cutting beta.1

[releasing.md](releasing.md#cutting-a-release): `app/pubspec.yaml` already has `1.0.0-beta.1+1`; check Cronet, run both dry runs ([Android](releasing.md#the-dry-run), [iOS](releasing.md#the-ios-dry-run)), wait for the green CI run on `main`, tag `v1.0.0-beta.1` and push the tag. A second maintainer approves the job `publish` of the tag's release run, which uploads the bundle to Play's `beta` track, the APK to dl.vikunja.io and the GitHub release. Then check all three, and build and upload the iOS build from the Mac ([releasing.md](releasing.md#each-testflight-build)).

## The closed test on Google Play

A personal developer account created after 13 November 2023 can apply for production only after a closed test with at least 12 testers who stayed opted in for 14 days in a row ([testing requirements][play-testing-14]). [store-listing.md](store-listing.md#testing-and-production) has the track's settings.

1. **The testers:** a Google Group the owner creates, added as the track's tester list; a tester joins the group first and then opts in ([testing tracks][play-tracks]). Aim for 15 to 20: one opt-out drops the count below 12, and a tester who opts in again starts their 14 days from zero. Every tester needs a Google account, the one in Play on their phone.
2. **Internal testing first (optional):** an internal test can start before the listing is complete, for the owner's own devices. Its testers are not eligible for the closed test until they opt out, so none of them counts among the 12.
3. **The track:** feedback channel `coderoftime@gmail.com`, which the opt-in page shows; countries as for production; the bundle of `v1.0.0-beta.1`. Allow some days before it is available: Google may review the release first.
4. **The opt-in link,** `https://play.google.com/apps/testing/io.vikunja.app`, works only once the app's status is Published, and can take some hours after the first publication. Then send [the invitation](#the-invitation).
5. **The 14 days:** once a week, check that at least 12 testers are still opted in, and ask testers to keep the app installed and use it: the application asks how they used it, and Google may ask for more testing when engagement was low.
6. **Apply for production** from the Dashboard ("Apply for production") after the 14 days. The application has three parts ([testing requirements][play-testing-14]; the questions' wording here is from the help page, not the form):

| Part | Question | Draft answer, to complete from the beta log |
|---|---|---|
| The closed test | How easy was it to recruit testers? | Testers joined a Google Group announced to [where it was announced]; [N] opted in, [M] stayed for 14 days. |
| | Did testers use all of the app's features? | They signed in to their own Vikunja servers (2.3.0 or newer) or the public demo and used [the Overview, Upcoming, search, the List, Kanban, Table and Gantt views, Quick Add Magic, task details with reminders, comments and attachments, offline changes, notifications, widgets, the app lock, several accounts]; [features little used]. |
| | Did usage match what you expect in production? How did it differ? | Yes: the app is for people who already use Vikunja, and testers were such people; [differences, for example more demo use than in production]. |
| | Summary of the feedback, and how it was collected | Through email to coderoftime@gmail.com, Play's private feedback, [GitHub issues] and the app's "Help and bug reports" row; [N] reports, [the main themes]; Play vitals for crashes. |
| The app | Target audience | Adults who run Vikunja, the open-source task manager, on their own server or use one at work, and want it on Android. |
| | Value | An offline-first app for Vikunja servers: tasks and projects without a connection, reminders as notifications, widgets, Kanban and Gantt, several accounts; no account with the developer, no analytics or ads, open source. |
| | Installs in the first year (not shown publicly) | [the owner's estimate] |
| Production readiness | What changed because of the test? | [the fixes of beta.2 to beta.N, from the beta log] |
| | How did you decide the app is ready? | Every reported problem fixed or recorded with a reason, no open crash in Play vitals, the threat model signed off ([section 8.4](threat-model.md#84-sign-off)), the accessibility passes run. |

**Timeline**, from Google's help pages: the closed test's first review (hours to several days), 14 days with at least 12 testers, the application's review ("usually takes seven days or less"), then the production release's own review (up to 7 days). From the first closed-test rollout to 1.0.0 on Play that is about 4 to 5 weeks at best; recruiting testers comes on top, and Google can ask for more testing.

## TestFlight

[releasing.md](releasing.md#each-testflight-build) covers the build and its upload; [store-listing.md](store-listing.md#app-store-connect) the test information.

- **Internal testers** (up to 100 users of the App Store Connect team, the owner among them) install a build as soon as it is processed, without a review ([TestFlight overview][tf-overview]).
- **External testers** come through a group with a public link: set the link's criteria (iPhone and iPad, iOS 15 or later) and a tester limit, for example 100, raised when needed ([external testers][tf-external]).
- **Beta App Review** checks the first build of each version that goes to external testers; later builds of the same version might not need a full review, only one build of a version can be in review at a time, and at most six builds go to review in 24 hours. Every 1.0.0 beta has the iOS version 1.0.0, so beta.1 is the one that waits.
- **Test information** ([test information][tf-info]): the beta app description and feedback email of [store-listing.md](store-listing.md#app-store-connect); for Beta App Review the contact (name, phone, email), sign-in required with `demo` and `demo` in the sign-in fields, never in the notes, and `fastlane/metadata/review_information/notes.txt` as the notes.
- **What to Test** for each build, in the dialog that opens when the build is added to the external group, in English and German ([beta.1's](#what-to-test-for-beta1)).
- **Builds expire after 90 days;** a beta that runs longer needs a new build before then.

## Texts for testers

### The invitation

> **Test the new Vikunja app before its release**
>
> The new Vikunja app is coming to Android, iPhone and iPad: the app for Vikunja, the open-source task manager that people run on their own servers. It is open source (MIT License): https://github.com/go-vikunja/app
>
> Before version 1.0.0 I am looking for testers. You need:
>
> - an account on a Vikunja server, version 2.3.0 or newer: your own, your organisation's, or Vikunja's public demo (tap "Try the public demo" in the app; the demo account is shared and reset now and then, so keep real data out of it);
> - an Android phone or tablet with Android 7.0 or newer and a Google account, or an iPhone or iPad with iOS 15 or newer.
>
> **Android (Google Play):**
>
> 1. Join the Google Group [the group's address] with the Google account you use in Play.
> 2. Open https://play.google.com/apps/testing/io.vikunja.app with the same account, join the test, then install Vikunja from Google Play.
> 3. Please stay in the test and keep the app installed for at least 14 days. Google lets a new developer publish an app only after at least 12 testers have taken part for 14 days in a row; leaving the test early stops your count, and joining again starts it from zero.
>
> **iPhone and iPad (TestFlight):** install TestFlight from the App Store, then open [the public TestFlight link] on your device and accept.
>
> **Reporting a problem or an idea:**
>
> - in the app: Account tab, the version at the very bottom, then "Help and bug reports";
> - by email to coderoftime@gmail.com, with the app's version, your device and system version, your Vikunja server's version and the steps that show the problem; the row "Support details" after "Help and bug reports" shows these and more and shares them when you tap Share, without your tasks, names or passwords;
> - on Android as private feedback on the app's page in Google Play; on iPhone and iPad through TestFlight: take a screenshot in the app and share it as beta feedback, or send feedback from the app's page in the TestFlight app.
>
> Please leave passwords and tokens out of every report, and report a security problem privately to security@vikunja.io, not in a public issue.
>
> Thank you for helping!

### Die Einladung

> **Teste die neue Vikunja-App vor der Veröffentlichung**
>
> Die neue Vikunja-App kommt für Android, iPhone und iPad: die App für Vikunja, die Open-Source-Aufgabenverwaltung, die man auf dem eigenen Server betreibt. Sie ist Open Source (MIT-Lizenz): https://github.com/go-vikunja/app
>
> Vor Version 1.0.0 suche ich Testerinnen und Tester. Du brauchst:
>
> - ein Konto auf einem Vikunja-Server ab Version 2.3.0: deinem eigenen, dem deiner Organisation oder der öffentlichen Demo von Vikunja (in der App „Öffentliche Demo ausprobieren“; das Demokonto teilen sich alle, und es wird ab und zu zurückgesetzt, also gib dort keine echten Daten ein);
> - ein Android-Handy oder -Tablet ab Android 7.0 mit einem Google-Konto oder ein iPhone oder iPad ab iOS 15.
>
> **Android (Google Play):**
>
> 1. Tritt der Google Group [Adresse der Gruppe] mit dem Google-Konto bei, das du in Play nutzt.
> 2. Öffne mit demselben Konto https://play.google.com/apps/testing/io.vikunja.app, nimm am Test teil und installiere Vikunja dann aus Google Play.
> 3. Bleib bitte mindestens 14 Tage im Test und lass die App so lange installiert. Google lässt neue Entwicklerinnen und Entwickler eine App erst veröffentlichen, wenn mindestens 12 Personen 14 Tage am Stück mitgetestet haben; wer früher austritt, zählt nicht mehr, und wer wieder beitritt, fängt bei null an.
>
> **iPhone und iPad (TestFlight):** Installiere TestFlight aus dem App Store, öffne dann [den öffentlichen TestFlight-Link] auf deinem Gerät und nimm die Einladung an.
>
> **Fehler oder Ideen melden:**
>
> - in der App: Tippe im Tab „Konto“ ganz unten auf die Version, dann auf „Hilfe und Fehler melden“;
> - per E-Mail an coderoftime@gmail.com, mit der Version der App, deinem Gerät und seiner Systemversion, der Version deines Vikunja-Servers und den Schritten, die den Fehler zeigen; die Zeile „Support-Details“ nach „Hilfe und Fehler melden“ zeigt das und mehr und teilt es, wenn du auf „Teilen“ tippst, ohne deine Aufgaben, Namen oder Passwörter;
> - unter Android als privates Feedback auf der Seite der App in Google Play; auf iPhone und iPad über TestFlight: Mach in der App einen Screenshot und teile ihn als Beta-Feedback, oder sende Feedback von der Seite der App in der TestFlight-App.
>
> Lass Passwörter und Tokens bitte aus jeder Meldung heraus, und melde ein Sicherheitsproblem vertraulich an security@vikunja.io, nicht öffentlich.
>
> Danke, dass du hilfst!

### What to Test for beta.1

TestFlight's What to Test for the first build, with Apple's names (Home Screen, Home-Bildschirm, Mitteilungen). The Google Group can get the same text with Android's: home screen, Startbildschirm, Benachrichtigungen.

> Vikunja app 1.0.0-beta.1 is the first beta. Please use it for your tasks as you would every day, and try in particular:
>
> - signing in to your Vikunja server, or "Try the public demo", and the first sync; a second account if you have one;
> - the Overview, Upcoming and search;
> - your projects in the List, Kanban, Table and Gantt views: creating, ticking off, moving and reordering tasks;
> - "New task" with Quick Add Magic: dates, labels and the project typed into the title ("How Quick Add Magic works" explains it);
> - a task's details: dates, reminders, repeating, labels, assignees, the description with a checklist, comments and attachments;
> - offline: change something without a connection; the app sends it when you are back online;
> - reminders as notifications, also with the app closed, and the notification's Done and Snooze buttons;
> - the widgets on your Home Screen;
> - the app lock: Account tab, App lock and privacy;
> - the app in English and in German.
>
> Tell me about anything that crashes, looks wrong, is slow, is hard to use or is missing: in the app with Help and bug reports on the About page (Account tab, the version at the bottom), through TestFlight's feedback, or by email to coderoftime@gmail.com. The row Support details on the same page gives you what to add to a report.

### Was du in beta.1 testen kannst

> Vikunja-App 1.0.0-beta.1 ist die erste Beta. Nutze sie bitte für deine Aufgaben wie sonst auch, und probier vor allem aus:
>
> - die Anmeldung auf deinem Vikunja-Server oder „Öffentliche Demo ausprobieren“ und die erste Synchronisierung; ein zweites Konto, wenn du eins hast;
> - „Überblick“, „Anstehend“ und die Suche;
> - deine Projekte in den Ansichten Liste, Kanban, Tabelle und Gantt: Aufgaben erstellen, abhaken, verschieben und umsortieren;
> - „Neue Aufgabe“ mit Quick Add Magic: Datum, Labels und Projekt direkt im Titel („So funktioniert Quick Add Magic“ erklärt es);
> - die Details einer Aufgabe: Termine, Erinnerungen, Wiederholung, Labels, zugewiesene Personen, die Beschreibung mit einer Checkliste, Kommentare und Anhänge;
> - offline: Ändere etwas ohne Verbindung; die App sendet es, sobald du wieder online bist;
> - Erinnerungen als Mitteilungen, auch wenn die App geschlossen ist, und die Tasten „Erledigt“ und „… später“ in der Mitteilung;
> - die Widgets auf deinem Home-Bildschirm;
> - die App-Sperre: im Tab „Konto“ unter „App-Sperre und Privatsphäre“;
> - die App auf Deutsch und auf Englisch.
>
> Schreib mir zu allem, was abstürzt, falsch aussieht, langsam ist, schwer zu bedienen ist oder fehlt: in der App mit „Hilfe und Fehler melden“ auf der Seite „Über die App“ (im Tab „Konto“ ganz unten auf die Version tippen), über das Feedback von TestFlight oder per E-Mail an coderoftime@gmail.com. Die Zeile „Support-Details“ auf derselben Seite gibt dir, was du einer Meldung beilegen kannst.

## During the beta

- **Where reports land:** the inbox of `coderoftime@gmail.com` (also the replies to TestFlight's invitations and the address on Play's opt-in page); Play's private feedback from testers in the Play Console [uncertain: where the Console lists it]; TestFlight's feedback with screenshots and its crash reports in App Store Connect under TestFlight; the issues of go-vikunja/app, through its bug and feature forms. A security problem goes privately to security@vikunja.io or through GitHub's private vulnerability reporting, never into a public issue ([SECURITY.md](../SECURITY.md), [D87]).
- **The beta log:** for each report its date, channel, platform and version, what happened, and the fix with its beta.N, without testers' names or addresses. It answers Play's production application and goes into the 37d decision.
- **Each fix ships as the next `v1.0.0-beta.N`,** never as a moved tag ([releasing.md](releasing.md#cutting-a-release)): a commit on `main` with its green CI, then the tag, whose release run uploads the bundle to Play's `beta` track once a second maintainer approves it. The workflow gives Play no release notes, so a line on what changed goes into them in the Play Console; the iOS build goes to TestFlight with its What to Test. Google's page counts the days testers stay opted in and says nothing about new releases restarting them.
- **Crash data** comes only from Play vitals and TestFlight's crash reports: release builds log nothing, and the app has no crash reporting. A tester's report can carry the support details ([D20](decisions.md#d20-scope-cuts-and-mobile-forms-of-desktop-features)): the versions, the background state, the queue's counts and failure kinds and the last session end, never a log.
- **The privacy policy** describes the testers' list, the stores' statistics and the APK on GitLab before any of them existed: read those statements again once the beta has started (D76's open points, below).

## Before 1.0.0

### The iOS device test

The list gathers [D74]'s known gaps, section [8.3](threat-model.md#83-final-ios-phase) of the threat model and the device notes of D71 and D75. It runs on the owner's iPhone or iPad with Xcode 27.2 (27B52; D74's simulator checks used 27.1), and the results go into the 37d decision.

- [ ] The first signed build and its TestFlight upload: App Store Connect's processing passes, the real test of the privacy manifests and the required-reason APIs.
- [ ] Whether a release build needs `DEAD_CODE_STRIPPING=NO` for the lock-screen widgets.
- [ ] The sensitive clipboard (8.3 #3): a new API token and a share link copy, do not reach a Mac through Universal Clipboard, and the pasteboard is empty after two minutes.
- [ ] Widget links and notification taps (8.3 #4, #5): rows carry the key, another account's widget row and notification switch accounts, the same link from Safari or Notes does not.
- [ ] Widgets (8.3 #6): rows, titles and their VoiceOver labels redacted on the Lock Screen and in StandBy; Done from a widget asks for the unlock; the setup fields, the project picker per account, placed widgets, "+N more".
- [ ] The app lock (8.3 #7): the passcode fallback, the lockout, Done in a locked notification (`task_locked`) asks for the unlock.
- [ ] The connection settings under SecTrust (8.3 #8): handshake pinning, a PKCS#12 client certificate, CA trust under the 825-day rule, access headers through NSURLSession, ASWebAuthenticationSession's warning for a pinned server.
- [ ] A restore (8.3 #9): an encrypted backup restored to another device brings back no tokens, connection secrets, databases or widget files.
- [ ] The capture cover (8.3 #11) in a real screen recording, AirPlay or mirrored display.
- [ ] Photo locations (8.3 #12): a photo from Photos, a photo and a video taken with the camera, each without its location on the server.
- [ ] Background refresh through BGTaskScheduler (`io.vikunja.app.sync`).
- [ ] An account's online flows (the simulator checks had only an expired session).
- [ ] Increase Contrast, Bold Text, Reduce Motion and VoiceOver: [accessibility-checklist.md](accessibility-checklist.md#3-final-ios-phase) section 3.
- [ ] iPad: the wheel popups as cards, an iPad mini and an 11-inch iPad, Split View and Slide Over.
- [ ] [D75]'s iOS parts: the help button, the new-task sheet above the home indicator, the Cupertino Theme control on the Account tab, the project folder in light, dark and tinted rendering.
- [ ] [D71]'s App language row: the Language entry in Settings with one and with two preferred languages.
- [ ] The About page's "Help and bug reports" row opens the support page.
- [ ] The support details ([threat model 8.3](threat-model.md#83-final-ios-phase) #13): the Runner builds with the device channel's `backgroundState`, the page's Background App Refresh and Low Power Mode lines follow the settings, and Share opens the share sheet from its button on an iPad.
- [ ] iOS 15 to 17.3 (8.3 #10): the sign-in fallback below iOS 17.4 and the system SQLite on iOS 15, if a device is at hand. Otherwise the owner decides: accept it untested, borrow a device (Xcode 27 is reported to debug only on iOS 17 or later, so such a device may take TestFlight builds only [unverified]), or raise the minimum.

### The rest, in any order

- [ ] **TalkBack and VoiceOver:** the manual passes of [accessibility-checklist.md](accessibility-checklist.md#2-manual-on-android) ([Q19](open-questions.md#q19-device-setup-for-the-manual-talkback-pass)); TalkBack and Switch Access need the owner at the controls.
- [ ] **The threat model again** for 1.0.0 ([section 9](threat-model.md#9-review-cadence)): 8.1 on the tree to be released, 8.2 again for what changed since the beta's sign-off, 8.3 from the device test above, and a new row in [section 8.4](threat-model.md#84-sign-off).
- [ ] **The public demo:** ask the Vikunja maintainers whether the testers and the stores' reviewers may use try.vikunja.io with the demo account (the review notes ask the reviewers not to delete it) and whether there are times it should not be used ([D76]).
- [ ] **The written offer's wording** for desugar_jdk_libs, which the owner confirms ([D67] decision 6; the text is in `app/assets/legal/android.md`).
- [ ] **The privacy policy's open points** ([D76]'s known gaps): the supervisory authority, which depends on the owner's Bundesland; how long support emails and the testers' lists are kept; the statements about the stores' statistics and the testers' addresses, read again once the beta has started.
- [ ] **US export:** no annual self-classification report is due. Since BIS's rule of 29 March 2021 ([86 FR 16482][bis-rule]) the report covers only mass-market components and executable software ([15 CFR 740.17(e)(3)][cfr-740-17]), not an end-user app with standard encryption only ([releasing.md](releasing.md#export-compliance)).
- [ ] **France ([Q23](open-questions.md#q23-french-encryption-declaration-for-the-app-store), open):** Apple's [export compliance table][apple-export] asks for a French encryption declaration for an industry-standard algorithm that the operating system does not provide, and the app's `dart:io` TLS uses BoringSSL from the Flutter engine. The choices: file the declaration with the ANSSI, find an exemption that covers it, or leave France out of the App Store's availability. Settle it before the App Store submission.
- [ ] **Steps 18 and 19,** the widgets, still in review: the owner accepts them after the device test.
- [ ] **Accessibility Nutrition Labels** stay blank in App Store Connect unless the passes above confirm a feature ([store-listing.md](store-listing.md#app-store-connect)).
- [ ] **The App Store's screenshots** and `python3 -I tool/check_store_metadata.py --strict` before the submission ([store-listing.md](store-listing.md#screenshots)).

## Cutting 1.0.0

Once Play has granted production access and everything [before 1.0.0](#before-100) is done:

1. **The release** as [releasing.md](releasing.md#cutting-a-release) says: `app/pubspec.yaml` to `version: 1.0.0+1`, Cronet checked, both dry runs, a green CI run, the tag `v1.0.0` (version code and iOS build 1000099), the approval, the GitHub release and dl.vikunja.io checked.
2. **Google Play:** the release run uploads the bundle to production as a staged rollout, to the share `VIKUNJA_APP_PLAY_ROLLOUT` (0.1 when unset); raise or complete it in the Play Console as the vitals allow ([releasing.md](releasing.md#cutting-a-release) step 5). Google may review the production release first (up to 7 days).
3. **The App Store:** upload the build from the Mac ([releasing.md](releasing.md#each-testflight-build)); in App Store Connect add it to version 1.0.0 with the version's texts and screenshots, the App Review information (the sign-in information in its fields, the notes, the maintainers' answer if Apple asks for it) and France as [Q23](open-questions.md#q23-french-encryption-declaration-for-the-app-store) decides, then submit it for review. Once 1.0.0 is released it takes no more builds; fixes go into 1.0.1.
4. **Afterwards:** the store links and the GitHub release in the README and on the website's project page (the owner deploys the website), the 37d decision completed, and step 37d closed in the roadmap.

## Sources

Read on 2026-11-02.

[play-app-signing]: https://support.google.com/googleplay/android-developer/answer/9842756
[android-verification]: https://developer.android.com/developer-verification/guides
[play-device]: https://support.google.com/googleplay/android-developer/answer/14316361
[play-testing-14]: https://support.google.com/googleplay/android-developer/answer/14151465
[play-tracks]: https://support.google.com/googleplay/android-developer/answer/9845334
[tf-overview]: https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/
[tf-external]: https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers/
[tf-info]: https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/
[apple-complete-review]: https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review/
[apple-export]: https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption/
[bis-rule]: https://www.federalregister.gov/documents/2021/03/29/2021-05481/export-administration-regulations-implementation-of-wassenaar-arrangement-2019-plenary-decisions
[cfr-740-17]: https://www.law.cornell.edu/cfr/text/15/740.17
[vikunja-contact]: https://vikunja.io/contact/
[gh-forks]: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/about-permissions-and-visibility-of-forks
[gh-limits]: https://docs.github.com/en/repositories/creating-and-managing-repositories/repository-limits

- Google Play and Android: [Play App Signing][play-app-signing], [developer verification][android-verification], [device verification for new personal accounts][play-device], [testing requirements for new personal accounts][play-testing-14], [testing tracks][play-tracks]
- Apple: [TestFlight overview][tf-overview], [external testers][tf-external], [test information][tf-info], [complete review][apple-complete-review], [export compliance documentation][apple-export]
- US export: [86 FR 16482][bis-rule], [15 CFR 740.17][cfr-740-17]
- Vikunja: [contact][vikunja-contact]
- GitHub, read on 2026-11-16 for [the move](#the-move): [forks and their network][gh-forks], [repository limits][gh-limits]

[D67]: decisions.md#d67-agpl-30-or-later-with-an-app-store-permission-dco-reserved-brand-embedded-cronet
[D71]: decisions.md#d71-english-and-german-us-base-glossary-error-texts-live-language-changes
[D74]: decisions.md#d74-ios-phase-app-store-prerequisites-testflight-from-the-mac-photo-locations-capture-cover
[D75]: decisions.md#d75-owners-ui-review-no-task-identifier-coloured-folders-new-task-sheet-account-tab
[D76]: decisions.md#d76-store-listings-and-policies-the-apps-pages-photo-locations-removed-on-android
[D77]: decisions.md#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers
[D87]: decisions.md#d87-mit-vikunjas-contribution-rules-and-the-move-into-go-vikunjaapp

# Beta and 1.0.0

The owner's runbook for step 37d ([Releases]): from the move into a new go-vikunja/app through the beta on Google Play's open testing track and on TestFlight to 1.0.0 in both stores. Each part comes in the order it is done, and each step says who does it, when, and why it is needed. [releasing.md](releasing.md) has how a release is cut and every one-time setting, and [store-listing.md](store-listing.md) every console form with its answer; this page links them and adds what neither covers. The tester-facing texts are in English and German. None of this is legal advice.

The app is Vikunja's official app ([Identity and scope]): it is called Vikunja, its id is `io.vikunja.app` ([Identity and scope]), the Play app is the one in Vikunja's Play account, in production, and its bundles are signed with Vikunja's upload key. The repository is under the MIT License and moves into a new, empty go-vikunja/app with its whole history, while the old app's repository becomes go-vikunja/app-legacy, archived ([Identity and scope]); there GitHub Actions run the CI and the Android releases, each release waiting for a reviewer of the environment `release` ([Releases]). As `io.vikunja.app` is in production, Play's closed test of 12 testers for 14 days does not apply: the beta goes to Play's open testing track `beta`, and the app's pages are on vikunja.io ([Releases]). The translations come from Vikunja's Crowdin project through the workflow "Crowdin" ([Languages], [Releases]). From the owner's decisions of 2026-11-02 ([Releases]): a "Help and bug reports" row on the About page, TestFlight's external testers through a public link, testers on their own Vikunja server (2.3.0 or newer) or the public demo, `try.vikunja.io`, and iOS builds on the owner's Mac.

## Who does what on GitHub

The app moves into a new, empty go-vikunja/app (owner and kolaente, 2026-11-23): kolaente renames the old app's repository to go-vikunja/app-legacy and archives it, creates the new go-vikunja/app and is its admin; the owner gets the role Maintain there and no admin rights (owner, 2026-11-22). kolaente makes the settings that only an admin may change, and the owner does the rest. The old repository's secrets can be neither read back nor moved, so the release keys and the Crowdin token are entered again, straight into the environments `release` and `crowdin` of the new repository, and every release, beta.1 included, waits for a reviewer (owner, 2026-11-23).

### What the owner does

GitHub's [role table][gh-roles] (read on 2026-11-22) gives the role Maintain what the owner's steps need: pushing branches and tags (`v*` tags only through the tag ruleset's bypass, which names the role Maintain), running and disabling workflows, approving pull requests he did not author and their waiting workflow runs, merging approved pull requests, and creating, updating and deleting the repository's Actions secrets and variables ([secrets][gh-secrets]). Rulesets, the Actions settings, environments with their secrets, and the organization's settings take an admin or an organization owner ([environments][gh-environments]). If GitHub refuses the owner one of the steps below, kolaente does it.

1. **The move** (the owner, after kolaente's first sitting): [the move](#the-move), from committing the new repository's id to pushing `main`. **Why:** the new repository starts empty, and the push brings the app with its whole history.
2. **Upload the German to Crowdin** (the owner, after the first run of the workflow "Crowdin"): [the translations on Crowdin](#the-translations-on-crowdin). **Why:** the app's file on Crowdin starts without translations, so every Crowdin pull request would take the German out of `app_de.arb`, and a release refuses an incomplete German.
3. **Test a bot approval once** (the owner, after kolaente's second sitting): [releasing.md](releasing.md#after-the-push) step 9. **Why:** if an approval by `github-actions[bot]` meets the approval "main protect" requires, anyone with write access can merge their own pull request without a second person; the result decides how [threat model](threat-model.md) R40 is closed or accepted.
4. **Approve and merge each Crowdin pull request** (the owner, after each run of the workflow "Crowdin" that opens or updates one): in the pull request, Files changed > "Awaiting approval" > "Approve workflows to run"; once its checks are green and its diff is read, Files changed > Review changes > Approve > Submit review, then merge it. **Why:** GitHub starts no workflow of a pull request that the workflow's own token pushed, and "main protect" requires an approval, which the owner may give as he is not the author.
5. **Commit the certificates** (the owner, before beta.1's tag, once kolaente has sent the upload certificate's SHA-256, [step 21](#3-outside-github)): [releasing.md](releasing.md#after-the-push) step 10. **Why:** a real release fails while `tool/ci/release_certificates.txt` names no upload certificate.
6. **Set the crash reports' DSN** (the owner, before the first tag whose builds should send reports): [Before beta.1, part 1](#1-the-repository-and-ci), step 2. **Why:** a build without it has no crash reports.
7. **Push the release tags** (the owner, for each release): [cutting a release](releasing.md#cutting-a-release). **Why:** only a `v*` tag starts a release, and the tag ruleset lets only admins and maintainers push one; its publishing then waits for a reviewer of the environment `release`.

### What kolaente does

A list for the owner to forward: the GitHub settings that only an admin may change, in one sitting of about fifteen minutes before the owner's push and one of about five minutes after it, then the answers and accounts outside GitHub, and one question. Everything else the owner does with his own access ([what the owner does](#what-the-owner-does)).

#### 1. GitHub, before the push

One sitting, then a message to the owner that the repository is ready:

1. **The values at hand:** the release secrets of [releasing.md](releasing.md#before-the-push) step 3's table, the upload keystore and its passwords among them, and a Crowdin personal access token for step 4. **Why:** a secret's value can be neither read back nor moved, so nothing comes along from the old repository; whoever holds the keys enters them again. If the upload keystore is lost, Play can reset the upload key, but installs of the old app's APKs from dl.vikunja.io and GitHub would then no longer update, so the owner hears of it before step 2.
2. **The old repository becomes go-vikunja/app-legacy:** in go-vikunja/app, Settings > General > Repository name `app-legacy` > Rename; on the repository's front page, the gear beside "About", the description "The previous Vikunja app. The new one: https://github.com/go-vikunja/app"; then Settings > General > Danger Zone > Archive this repository. **Why:** the name `app` becomes free for the new repository; the old app's history, issues and releases stay readable, read-only, and the update test builds the old app from its last commit there. Once the new repository holds the name, GitHub no longer forwards the old repository's links ([renaming][gh-rename]).
3. **The new go-vikunja/app:** New repository with the owner go-vikunja and the name `app`, the description "The official Vikunja app for Android, iPhone and iPad", Public, and no README, no .gitignore and no license; Create repository. Then Settings > Collaborators and teams > Add people: the owner's GitHub account with the role Maintain. **Why:** a file in the new repository would make it refuse the owner's push; every release links its source, which must open signed out; and Maintain gives the owner the push, the tag ruleset's bypass and the repository's secrets and variables, without admin rights.
4. **The environments** (Settings > Environments > New environment):
   - `release`: tick "Required reviewers" and add the owner and kolaente, leave "Prevent self-review" unticked, untick "Allow administrators to bypass configured protection rules", Save protection rules; under "Deployment branches and tags", "Selected branches and tags" > Add deployment branch or tag rule > Ref type Tag, `v*`, and no branch rule; under Environment secrets, Add environment secret for each secret of [releasing.md](releasing.md#before-the-push) step 3's table.
   - `crowdin`: under "Deployment branches and tags", "Selected branches and tags" > Add deployment branch or tag rule > Ref type Branch, `main`; under Environment secrets, `CROWDIN_PERSONAL_TOKEN`, the token of step 1.

   **Why:** every release, the betas included, waits for one of the two reviewers, and either may approve a release of his own tag; without an administrator bypass nobody skips that approval; the tag rule keeps every branch's workflow, the Copilot coding agent's included, away from the keys; and the Crowdin token, whose rights reach the web's and the API's files on Crowdin too, reaches only the workflow "Crowdin" on `main` ([threat model](threat-model.md) R28, R40).
5. **Actions may open pull requests** (Settings > Actions > General > Workflow permissions): tick "Allow GitHub Actions to create and approve pull requests", then Save. If the checkbox is grayed out, tick it first in the organization's Settings > Actions > General > Workflow permissions. **Why:** the workflow "Crowdin" opens the translation pull requests with the workflow's own token, which GitHub refuses otherwise. The risk and the owner's test of it: [releasing.md](releasing.md#after-the-push) step 9.
6. **No organization copies** (the organization's Settings > Secrets and variables > Actions): no organization secret named `KEYSTORE_BASE64`, `KEY_PROPERTIES`, `APK_KEYSTORE_BASE64`, `APK_KEY_PROPERTIES`, `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON`, `S3_ACCESS_KEY` or `S3_SECRET_KEY` reaches go-vikunja/app; one with the repository access "All repositories" reaches the new repository too. `S3_ENDPOINT`, `S3_BUCKET` and `S3_REGION` hold no credential and may stay. **Why:** the job `secret-scope` fails every tag while one is left, as any workflow on any branch could read it without the reviewers ([threat model](threat-model.md) R28).

Nothing else needs changing before the push: the workflows set their own permissions and use only GitHub's own actions, pinned by full commit SHA, which the repository's tests check, and approval of workflow runs for first-time contributors from forks is GitHub's default.

#### 2. GitHub, after the push

Once the owner says that `main` is pushed and its first CI run is green ([the move](#the-move), step 5), about five minutes:

7. **"main protect"** (Settings > Rules > Rulesets > New ruleset > New branch ruleset): the name "main protect", Enforcement status "Active"; under Target branches, Add target > Include default branch; the rules "Restrict deletions", "Require a pull request before merging" with 1 required approval, "Require status checks to pass" with `checks`, `editor`, `contract`, `android`, `osv` and `ios` (Add checks, each one), and "Block force pushes"; the bypass list as [the question](#4-a-question-for-kolaente) settles it; Create. **Why:** every release is built from `main`, so a change reaches it only through a pull request whose six checks are green and which a second person approved. It comes after the push, as its rule for pull requests would refuse the push, and after the first CI run, so that the six checks have reported once.
8. **A ruleset for the release tags** (Settings > Rules > Rulesets > New ruleset > New tag ruleset): the name "release tags", Enforcement status "Active"; under Bypass list, Add bypass: "Repository admin" and "Maintain"; under Target tags, Add target > Include by pattern: `v*`; the rules "Restrict creations", "Restrict updates" and "Restrict deletions"; Create. **Why:** only admins and maintainers start a release, and a published release tag is never moved or deleted; each release still waits for a reviewer of the environment `release`. A bypass list takes roles and teams, not single people ([bypass][gh-ruleset-bypass]), so everyone who holds Maintain, directly or through a team, gets the bypass too: check who does. The role Write there would let everyone with write access start a release.

#### 3. Outside GitHub

9. **The name-and-logo text** in `NOTICE.md` (before beta.1): confirm it, and say who holds the copyright of the logo. **Why:** `NOTICE.md`, the app's notice and the About page say that the name and the logo belong to the Vikunja project and are not under the MIT License; only the project can confirm that.
10. **The owner's Play Console permissions** for `io.vikunja.app` only ([Releases]), before beta.1 (Users and permissions > the owner, or Invite new users > App permissions > Add app > `io.vikunja.app`): Manage store presence, Manage policy declarations, Release apps to testing tracks, and Manage testing tracks and edit tester lists; not the release to production. **Why:** with them the owner enters the answers of [store-listing.md](store-listing.md#google-play-console); without them kolaente enters them himself. Production goes through the release workflow's service account.
11. **The pages on vikunja.io** (before beta.1): the privacy section "Mobile app", the help page `/help/mobile` and the imprint's scope sentence, drafted in [vikunja-io-drafts.md](vikunja-io-drafts.md), which kolaente puts into go-vikunja/website himself. The headings "Mobile app" and "Delete your account" and the slug `mobile` keep their words: the app and the stores link them. **Why:** every build links these addresses, and the release scripts refuse to release until each one opens with its anchor.
12. **Vikunja Cloud's terms** or data processing agreement (before beta.1): its URL. **Why:** the privacy section links it.
13. **The address for App Review and the testers** (before beta.1), one that reaches the app's maintainers, in place of `hello@vikunja.io` in `fastlane/metadata/review_information/email_address.txt`, TestFlight's feedback email, the open test's feedback channel and the tester texts. **Why:** testers' reports and Apple's questions should reach whoever fixes the app; until the address exists they go to `hello@vikunja.io`.
14. **The store texts** (before beta.1): whether the full description keeps the sloth line's spirit, and whether it names Vikunja Cloud as a server ([store-listing.md](store-listing.md#texts)). **Why:** they speak for Vikunja in both stores from the first beta on.
15. **The Apple account** that publishes the app (before the first TestFlight build): with it the App Store name (whether "Vikunja" is still held by the former contributor's team that the old app's `ios/fastlane/Appfile` names), the bundle id and the privacy label ([store-listing.md](store-listing.md#app-store-connect)). **Why:** the app record, the signing and the privacy label depend on it, so no signed iOS build is made before.
16. **Crash reports** ([Diagnostics]), before a beta that sends reports: the new app uses the old app's Sentry project as it is, and the owner sets its DSN, so nothing needs creating. An administrator of Vikunja's Sentry organization checks:
    - in the project's settings: Security & Privacy > "Prevent Storing of IP Addresses" on, the Data Scrubber and its default scrubbers on; as a net behind the app's own scrubbing, an advanced data scrubbing rule that removes `$user`; spike protection and a rate limit per key; the data retention. These settings hold for the old app's reports as well;
    - the organization's data region (United States or EU), for the privacy section ([vikunja-io-drafts.md](vikunja-io-drafts.md), `SENTRY-REGION` and `SENTRY-RETENTION`).

    **Why:** anyone can read the DSN from either app and send events with it, which spike protection and the rate limit cap; the scrubbing catches what the app's own misses; and the privacy section has to name the region and the retention.
17. **The Crowdin token** of step 4: whose Crowdin account it belongs to, what it may do and when it expires. **Why:** the sync stops when it expires.
18. **Swiss German** (only to ship it): in the project's language mapping, map the custom language `de-swiss` to `gsw` for the placeholder `two_letters_code` only. `crowdin.yml` cannot do it: the CLI took only Crowdin's standard codes there. The mapping is project-wide, but the web's and the API's files are named by `%locale%` (go-vikunja/vikunja's `crowdin.yml`), so they keep their names. **Why:** without it Swiss German exports as `app_de.arb`, which the workflow leaves out and names in the run and the pull request, so German stays safe but `app_gsw.arb` never comes.
19. **Pre-translation from the web:** whether the app may take the web's translations through the shared translation memory. **Why:** the web is under the AGPL and the app under the MIT License; until kolaente agrees, nothing is pre-translated.
20. **The old app's `app_en.arb`** at the root of the Crowdin project, after the owner's German upload: agree that the owner, whose Developer role covers it, exports it, if anyone translated it since December 2025, and deletes it; its translations stay in the translation memory. **Why:** the app's file is `main/app_en.arb` in the version branch `main` ([the rehearsal](#the-crowdin-rehearsal)), and until the old one is deleted it counts in each language's progress.
21. **The upload certificate's SHA-256** (before beta.1's tag): from the Play Console (Test and release > App integrity > Upload key certificate), sent to the owner, who commits it ([releasing.md](releasing.md#after-the-push) step 10). **Why:** a real release fails until it is committed, so that a swapped secret cannot sign the public APK with another key.
22. **Google Play** (before beta.1), in Vikunja's Play Console: the key that signs the APK, the upload key unless an APK key is added, registered for [developer verification][android-verification]; and under Users and permissions, the release workflow's service account (the user whose address ends in `iam.gserviceaccount.com`) keeps "Release apps to testing tracks" and "Release to production, exclude devices, and use Play App Signing" for `io.vikunja.app` ([releasing.md](releasing.md#after-the-push) step 12). **Why:** certified devices that require a registered key refuse the APK from GitHub and dl.vikunja.io otherwise, in a few countries since 2026-09-30 and everywhere from 2027; and the job `publish` uploads through the service account and fails at the Play step without its rights, after the signing. The old pipeline's last uploads through it went to the `beta` track, so its right to release to production is unchecked.
23. **The written offer** for the desugar_jdk_libs source: the Vikunja project makes it, with the contact `hello@vikunja.io` ("Ask the Vikunja project at hello@vikunja.io." in `app/assets/legal/android.md`, [Releases]); confirm it. **Why:** GitHub releases carry the source itself, but Play and dl.vikunja.io rely on the offer.
24. **Optional:** CODEOWNERS for `.github/` and `tool/ci/release_certificates.txt`, FUNDING.yml, and a devenv for the new app.

#### 4. A question for kolaente

Before his second sitting, as "main protect" takes the answer: "main protect" requires one approval, and an author cannot approve his own pull request ([required reviews][gh-required-reviews]), so each of the owner's pull requests, every fix during the beta included, waits for kolaente. The pull requests of the workflow "Crowdin" the owner approves himself, as he is not their author. Is that how kolaente wants it, or another arrangement? For example:

- the role Maintain in "main protect"'s bypass list, set to "For pull requests only": the owner's changes still go through a pull request, but when he merges, the bypass skips every rule of "main protect", the six required checks included ([bypass][gh-ruleset-bypass]), and it holds for everyone with that role;
- the same bypass with the checks kept: the required approval in a ruleset of its own for `main`, with that bypass, and "main protect" keeping the pull request and the six checks, without an approval and without a bypass;
- or the six required checks without a required approval.

## The move

The app goes into the new, empty go-vikunja/app with its whole history: the owner pushes `main` from the working repository, so every commit hash the docs cite stays valid. Nothing of the old app comes along. It stays in go-vikunja/app-legacy, archived, with its tags, its releases and its last commit `cdbc6e3` (`cdbc6e39ac9b52c58443cb353c324342dd7ce6c7`), from which the update test builds it ([developer guide](development.md#update-and-smoke-tests-on-an-emulator)).

### Before you start

- **kolaente's first sitting is done** ([his steps 1 to 6](#1-github-before-the-push)), and `gh api repos/go-vikunja/app --jq .permissions.maintain` prints `true`. **Why:** the push needs the new repository and the owner's role in it; the workflow "Crowdin" runs every night from the push on, with the token of its environment; and the first tag needs the environment `release` with its reviewers and secrets.
- **`main` is reviewed and green,** and nothing on it is half done. **Why:** the push publishes it for good, as the new app's first state.
- **The GitHub account has the commits' author address** (`git log --format='%ae' -1`) as a verified email, and "Block command line pushes that expose my email" is off. **Why:** GitHub links the commits to the account only through a verified address, and the push fails with GH007 otherwise.
- **The tracked test-server users,** `test_servers/seed/e2e-user.env` and `e2e-user-2.env`, hold nothing used anywhere else. **Why:** the history goes public unchanged; it holds no real secret, and most of it is public on GitLab already.

### The steps

The owner, in the working repository:

1. **The new repository's id** on `main`:

   ```sh
   gh api repos/go-vikunja/app --jq '.id, .size'   # the new id, not 395095540; size 0
   ```

   The id replaces `OFFICIAL_REPOSITORY_ID` in `tool/ci/release_lib.sh` and `GITHUB_REPOSITORY_ID` in `tool/ci/test_release_publish.py` and `tool/ci/test_crowdin_sync.py`, in one reviewed commit with its tests green. **Why:** a real release and the workflow "Crowdin" run only in the repository with that numeric id, so that a repository renamed to go-vikunja/app later does not pass; 395095540 is the old repository's, now go-vikunja/app-legacy.
2. **The checks before pushing:** each line must print `ok`, or show what its comment says:

   ```sh
   test -z "$(git ls-remote https://github.com/go-vikunja/app.git)" && echo "ok: the new repository is empty"
   test "$(gh api repos/go-vikunja/app --jq .id)" = "$(git show main:tool/ci/release_lib.sh | sed -n 's/^OFFICIAL_REPOSITORY_ID=//p')" && echo "ok: main has the new id"
   git log --format='%an <%ae> | %cn <%ce>' main | sort | uniq -c   # one line: the owner's address
   git rev-list --objects main | git cat-file --batch-check='%(objecttype) %(objectsize) %(rest)' |
     awk '$1 == "blob"' | sort -k2 -n | tail -1    # far below GitHub's 50 MiB warning
   ```

   **Why:** the push publishes for good, so what goes out is checked first: an empty target, the id, one author address and no oversized file.
3. **Push `main`, and only `main`:**

   ```sh
   git push https://github.com/go-vikunja/app.git main:main
   ```

   Never `--all`, `--tags` or `--mirror`. **Why:** `--mirror` would also publish the parked stash of the session hardening, `--all` every other branch and `--tags` every local tag; a release tag comes only through [cutting a release](releasing.md#cutting-a-release).
4. **The working repository follows go-vikunja/app,** and the test repository stays as `test` for the dry run on GitHub ([releasing.md](releasing.md#the-dry-run)):

   ```sh
   git remote rename origin test
   git remote add origin https://github.com/go-vikunja/app.git
   git fetch origin
   git branch --set-upstream-to=origin/main main
   git status -sb | head -1   # ## main...origin/main
   ```

   **Why:** later work starts from go-vikunja/app's `main` and goes back to it.
5. **The first runs:** Actions > CI, the run of the push: `checks`, `editor`, `contract`, `android`, `osv` and `ios` green ([part 7 of Before beta.1](#7-the-first-runs) lists what to watch). Then tell kolaente, for his [second sitting](#2-github-after-the-push). **Why:** a failure is fixed on `main` while it still takes a direct push, and "main protect" names checks that have reported.
6. **The GitLab project** gets a description that points to https://github.com/go-vikunja/app and is archived (Settings > General > Advanced > Archive project). None of the app's pages links it. **Why:** whoever finds it learns where the app went, and an archived project takes no new issues or merge requests.

From kolaente's second sitting on, a change reaches `main` only through a pull request: the owner pushes a branch to go-vikunja/app and opens the pull request from it, and merges it once its checks are green and the approval "main protect" asks for is given.

## The translations on Crowdin

The app's texts go into Vikunja's Crowdin project 462614, beside the web's and the API's ([Languages]). The workflow "Crowdin" ([releasing.md](releasing.md#the-workflow-crowdin)) syncs them with Crowdin's CLI, the secret `CROWDIN_PERSONAL_TOKEN` of the environment `crowdin` and the workflow's own token: every night, or when run by hand, it uploads the English source from `main` into the version branch `main` as `main/app_en.arb`, and it opens a pull request with the approved translations. Beside it stays the root file `/app_en.arb`, into which the old app's workflow "Crowdin Sync" uploaded the old app's 188 strings until the old repository was archived. The app's file is a new file, so the old app's translations do not carry over: they stay in the old root file and in the translation memory. The old app's Polish is not uploaded.

The owner, right after the push:

1. **Check the first source upload:** Actions > Crowdin > Run workflow on `main` (or wait for the nightly run), and its step "Upload the English source" passes; then the project's Sources show `main/app_en.arb` in the version branch `main` with the app's strings. Your Developer role in project 462614 may approve translations and manage source files, but not change the project's settings (support.crowdin.com/roles). You can also export what Crowdin holds in the old root `app_en.arb`. **Why:** the German upload goes into that file; without the secret `CROWDIN_PERSONAL_TOKEN` in the environment `crowdin` the job only writes a notice and uploads nothing.
2. **The CLI and a token:** `brew install crowdin`; a new personal access token of your Crowdin account (Account Settings > API, with the earliest expiry offered, not the default Never); a clean working copy of go-vikunja/app's `main`. `crowdin.yml` holds the project and the paths but no token: the CLI reads the token from `CROWDIN_PERSONAL_TOKEN`. **Why:** the token acts with your Developer role in 462614, which also holds the web's and the API's files, so it lives only for this upload.
3. **Upload the German,** from the repository root, first as a dry run, which only lists what it would upload:

   ```sh
   read -rs CROWDIN_PERSONAL_TOKEN && export CROWDIN_PERSONAL_TOKEN   # paste the token: it stays out of the shell's history
   crowdin config lint

   # Our German, approved, also where it equals the English (Vikunja, Kanban, OK)
   crowdin upload translations -b main -l de --auto-approve-imported --import-eq-suggestions --dryrun
   crowdin upload translations -b main -l de --auto-approve-imported --import-eq-suggestions
   ```

   - `-b main` is for the source in the version branch `main`: without it the CLI writes into the old `/app_en.arb` at the root, which the workflow does not export.
   - Add `--translate-hidden` to both if the project hides duplicate strings: Crowdin otherwise skips the German of a text it hides as a duplicate, for example of the web's.
   - The CLI waits while Crowdin imports, several minutes.
   - Leave the source to the workflow: `crowdin upload sources` with another `-b` would put a second copy of it into the project. Never add `--delete-obsolete`: the project holds the web's and the API's files too.

   **Why:** the export writes whole files, so without our German on Crowdin every Crowdin pull request would take it out of `app_de.arb`, and a release refuses an incomplete German. `--import-eq-suggestions` takes the German texts that equal the English, which Crowdin skips otherwise, and `--auto-approve-imported` approves them, as only approved texts are exported.
4. **Delete the token** under Account Settings > API. **Why:** see step 2.
5. **Check German on Crowdin:** the app's file shows 100 % translated and 100 % proofread (Crowdin may show 0 % for some minutes after the upload). If it is not proofread, approve the file's German in the editor, which a Developer may, or ask kolaente. **Why:** Crowdin's docs do not say whether a Developer's upload with `--auto-approve-imported` is approved, and the export takes only approved texts.
6. **The first Crowdin pull request:** Run workflow again, or wait for the nightly run. It opens "chore(i18n): update translations via Crowdin" from the branch `crowdin`, committed by "Frederick [Bot]", which needs kolaente's [step 5](#1-github-before-the-push). Approve its runs (Files changed > "Awaiting approval" > "Approve workflows to run"); `python3 -I tool/l10n_progress.py de` on its branch prints 100.0 %; read its diff of `app_de.arb`, as the texts must stay ours; then approve and merge it ([what the owner does](#what-the-owner-does) step 4). The first one reformats every ARB file once: Crowdin copies the template's `@` metadata into each translation, orders the keys its own way and writes no final newline; later diffs stay small. A pull request the workflow opened before the German upload has almost no German and fails the tests that pin German texts: leave it unmerged until a run after the upload has updated it. **Why:** from now on German reaches `app_de.arb` only through these pull requests, so the first one has to bring back exactly ours.

From then on:

- German, like every language, changes only on Crowdin. After an English change, a maintainer re-approves or retranslates its German there: the change leaves the translations unapproved, the export drops them, and the next Crowdin pull request fails where a test pins the German text.
- Pre-translation from the web's translations through the shared translation memory waits for kolaente's agreement ([his step 19](#3-outside-github)); once he agrees, it runs without approving, so that a proofreader approves each text. Until then nothing is pre-translated, though translators may see the web's texts as suggestions in the editor.
- The old root file stays until the owner exports and deletes it, once kolaente agrees ([his step 20](#3-outside-github)); until then Crowdin's language progress counts it too.

### The Crowdin rehearsal

The owner rehearsed the sync on 2026-11-16 ([Languages]). What it showed still holds for the workflow: the source goes into a version branch `main` beside the root file, so the German upload takes `-b main`; the first export reformats every ARB file once; and an English change drops that text's translations until they are approved again.

## Before beta.1

### 1. The repository and CI

The releases come only from GitHub Actions in go-vikunja/app ([Releases]); until the push the CI scripts run on the Mac and in the owner's test repository, and nothing is published.

1. **kolaente's sittings, the move and the owner's first steps** (kolaente, then the owner; before everything else): [what kolaente does](#1-github-before-the-push) steps 1 to 6, [the move](#the-move), his [steps 7 and 8](#2-github-after-the-push), then [what the owner does](#what-the-owner-does) steps 2 to 5. **Why:** the release workflow exists in go-vikunja/app only after the push, a release refuses an incomplete German, a real release fails without the committed certificates, and R40 waits for the bot test's result ([threat model](threat-model.md)). The old pipeline's workflow, which uploaded every push to `main` to Play, stays behind in the archived go-vikunja/app-legacy.
2. **The crash reports' key** ([Diagnostics]; the owner, before the first tag whose builds should send reports): the new app sends its crash reports to the old app's Sentry project, as it is (owner, 2026-11-21); its reports are told apart from the old app's by their release, `io.vikunja.app@1.…`. Copy that project's DSN from the old app's code into the **repository variable** `VIKUNJA_APP_SENTRY_DSN` (Settings > Secrets and variables > Actions > Variables > New repository variable), with no spaces or line breaks. A variable, not a secret: every build carries the DSN, and the job `build` has no environment, so an environment's variable would not reach it ([releasing.md](releasing.md#crash-reports)). The DSN goes into no file of the repository. **Why:** a build without it has no crash reports at all.

### 2. The keys

The keys are Vikunja's ([Identity and scope]): the old app's upload key signs the bundles and, without a separate APK key, the APK, as in the old app, so installs of the old app's APKs keep updating. The owner creates no key; [Q20](open-questions.md#q20-signing-keys-and-the-apk-beside-the-play-build)'s option A, an app signing key of the owner's, no longer applies. The release secrets, `KEYSTORE_BASE64` and `KEY_PROPERTIES`, the Play service account and the dl.vikunja.io storage keys, keep the old app's names and are entered again in the environment `release` of the new repository before the push ([what kolaente does](#1-github-before-the-push) step 4), so every release, beta.1 included, waits for a reviewer ([Releases]).

1. **The certificates** (kolaente sends the upload certificate's SHA-256 from the Play Console, the owner commits it; before beta.1's tag): [releasing.md](releasing.md#after-the-push) step 10. **Why:** a real release fails without it, so that a swapped secret cannot sign the public APK with another key.
2. **Developer verification** (kolaente, in Vikunja's Play Console, before beta.1): the key that signs the APK registered ([developer verification][android-verification]). That key must be RSA: the job signs the APK twice and fails when the two files differ, as they do with an EC or DSA key. **Why:** certified devices that require a registered key refuse the APK from GitHub and dl.vikunja.io otherwise.

### 3. The Play developer account

Vikunja's account, in which `io.vikunja.app` is in production ([Identity and scope], [Releases]). Its identity, its contact details and its trader status are Vikunja's and are kolaente's to keep; the owner creates no developer account of his own. A new personal account's requirements, the closed test with 12 testers for 14 days and the verification of a real phone in the Play Console app, do not apply ([store-listing.md](store-listing.md#testing-and-production)).

1. **The owner's permissions** (kolaente, before part 4): [what kolaente does](#3-outside-github) step 10. **Why:** with them the owner fills in the listing and the forms; without them kolaente does. The release to production stays with the release workflow and Vikunja's service account ([part 2](#2-the-keys)).

### 4. The Play app

The app is the one in Vikunja's Play account, `io.vikunja.app` ([Identity and scope]); the release workflow uploads through Vikunja's service account.

1. **Every form** (the owner with part 3's permissions, or kolaente; before the first beta upload) as [store-listing.md](store-listing.md#google-play-console) answers it: store settings and contact details, the listing in both languages with the graphics of `branding/png/`, the privacy policy, App access with the public demo, Ads, Content rating, Target audience, News, Data safety (the union of the old app's declaration and the new app's, with the old app's opt-in Sentry crash reports as crash logs, diagnostics and other app performance data; encryption in transit "No"), Government, Financial features, Health, Advertising ID. **Why:** Play counts the open track like production and reviews the listing and the declarations with the first upload ([testing tracks][play-tracks]).
2. **App content after the first upload** (the owner): it asks for no exact-alarm or foreground-service declaration. **Why:** the app needs neither permission; a request means that a dependency brought one in, which then has to be declared or removed.
3. **The screenshots** (the owner): the 20 Play screenshots of 2026-11-17, phone and tablet in en-US and de-DE ([store-listing.md](store-listing.md#screenshots)), go out with the first beta; if a screen they show changes before then, its screenshots are taken again, in a session on emulators made for it, with the demo data and the owner's sign-in once per device. The App Store's sets wait for a session on the simulators before the 1.0.0 submission ([before 1.0.0](#before-100)); TestFlight needs none. **Why:** the listing goes out with the first beta, screenshots included, and shows what testers get.

### 5. The Apple account and the app record

[releasing.md](releasing.md#once-before-the-first-upload) has each step. Which Apple account publishes the app is open ([what kolaente does](#3-outside-github) step 15); the owner does these steps in it before the first TestFlight build:

1. **The Apple Developer Program,** the team id, and Xcode signed in with an iPhone registered (releasing.md steps 1 to 3); the enrolled name shows as the seller, and the membership is renewed every year. **Why:** automatic signing needs the team and a registered device, and a lapsed membership takes the app off the App Store.
2. **The App IDs** `io.vikunja.app` and `io.vikunja.app.widgets`, both with only the App Group `group.io.vikunja.app` (Xcode creates them on the first signed build, or by hand under Identifiers). `io.vikunja.app` may already be taken at Apple; until the account and the id are settled, no build for a device with automatic signing ([Identity and scope]). **Why:** the app and its widgets share their data only through that group.
3. **The app record** `Vikunja` with the bundle id `io.vikunja.app` (releasing.md step 4), created early; the old app's TestFlight record in a former contributor's team may hold the name and the bundle id, and a fallback name is picked only if App Store Connect refuses it ([Releases]). **Why:** creating the record reserves the name.
4. **The App Store Connect API key,** outside the repository (releasing.md step 5). **Why:** `ios_release.sh` uploads each build with it.
5. **The source link,** the tree at the tag of `VIKUNJA_APP_SOURCE_CODE_URL`, by default https://github.com/go-vikunja/app, which has the release tags from the first release on (releasing.md step 6). **Why:** each build links its source at its tag, and the script refuses when that tree does not open signed out.
6. **The App Store Connect forms and TestFlight's test information** ([store-listing.md](store-listing.md#app-store-connect)), with the privacy label, which is open until the account is decided: if Vikunja's account publishes, the public demo and Vikunja Cloud are the developer's own servers. **Why:** Beta App Review needs the test information before external testers get a build, and the label has to match who runs the servers.

### 6. The app's pages on vikunja.io

The About page and both listings link the app's pages on vikunja.io: the section "Mobile app" of the privacy policy, the help page `/help/mobile` with "Delete your account", and the imprint ([Releases], [store-listing.md](store-listing.md#the-website)).

1. **kolaente publishes them** from the drafts in [vikunja-io-drafts.md](vikunja-io-drafts.md) ([what kolaente does](#3-outside-github) step 11), before the first rollout to testers. **Why:** until then the URLs compiled into every build lead to a policy without the app's section and to a missing page, so no build is distributed before.
2. **Open each address** of that table signed out, each with its anchor (the owner, once they are published). **Why:** the release scripts check that each page answers with its anchor, but not that the imprint's scope sentence names the apps.

### 7. The first runs

The trial of 2026-11-16 in the owner's test repository ([Releases]) passed the paths that only GitHub's hosted runners take: the Flutter tarball and the macOS zip with their checksums, ShellCheck over `tool/ci/`, the contract tests on the runner's own Docker, the NDK install and JDK 21, the osv-scanner Linux binary and Gradle's memory caps, and the macOS build with Xcode 26.6.

1. **Watch the first runs in go-vikunja/app** (the owner, from the push to beta.1's release run):
   - anonymous pulls from Docker Hub against its rate limits (a login is not built);
   - GitHub's macOS runners, which three times had none free for `ios` ([releasing.md](releasing.md#when-the-publish-job-fails));
   - `ios` on the image `xcode-27` (Xcode 27, like the releases), booting a simulator for the XCTests after the build, and resolving sentry_flutter's Swift package, the `sentry-apple-binaries` checkout and its two binary archives, whose download stalled for about 18 minutes in a sandboxed local build ([releasing.md](releasing.md#each-testflight-build));
   - the per-ABI APKs in the release build and its artifact; the first runs of the workflow "Upstream versions" and of Dependabot;
   - Gradle's dependency verification on Linux, whose `aapt2` is trusted without a checksum, and of the Sentry artifacts ([releasing.md](releasing.md#gradle-dependency-verification));
   - the workflow "Contract matrix", whose nightly run starts with the push and which pulls six server images from Docker Hub per run ([Servers](decisions.md#servers));
   - the release build taking the repository variable `VIKUNJA_APP_SENTRY_DSN`, whose log shows the OK line of `check_sentry_dsn` or its notice, and the DSN itself in the step's environment, as GitHub masks no variable ([releasing.md](releasing.md#crash-reports));
   - the workflow "Crowdin" ([releasing.md](releasing.md#the-workflow-crowdin)): the download of the pinned CLI and its checksum, the source upload into the version branch `main`, the two downloads and what they write, and the pull request from the workflow's token with its runs waiting for approval;
   - the environments' first deployments: `crowdin`'s from the workflow "Crowdin" on `main`, `release`'s from beta.1's tag, waiting for a reviewer.

   Each fix is a commit on `main`; the tag waits for a green run. The real signing, the publishing and the environment's reviewers first run on go-vikunja/app's first tag. **Why:** none of these has run on GitHub yet, and a release tag cannot be moved, so a failure is better found on `main` than on the tag.

### 8. The threat model

Each beta is public: its tag publishes a GitHub release with the APK, marked as a prerelease, and the APK on dl.vikunja.io ([Releases]), TestFlight's link is public, and anyone can join Play's open test. So the [threat model](threat-model.md#84-sign-off)'s review "before each store release" comes before `v1.0.0-beta.1` ([Releases]). The owner, with the release candidate:

1. **Section [8.2](threat-model.md#82-manual-on-the-android-emulator) on the emulator** in full with the release build, signing in the two accounts, items 5 and 10 on a Google Play image; with it the R33 check, a start of `MainActivity` from another app's activity without `FLAG_ACTIVITY_NEW_TASK` (`adb shell am start` adds that flag, so it needs a caller app), with the fix R33 describes. **Why:** these checks need the system's surfaces, a real sign-in and a Play image, which no automated test has.
2. **Section 8.1** on the tree to be tagged, with its checks of the settings of go-vikunja/app. **Why:** it runs the automated checks on exactly what ships and covers by hand the settings no job sees.
3. **The update and smoke tests** (part of 8.2's item 13): [releasing.md](releasing.md#cutting-a-release) step 7, the old app built from its last commit `cdbc6e3` ([developer guide](development.md#update-and-smoke-tests-on-an-emulator)). **Why:** beta.1 replaces the old app on its testers' devices, and only these tests try that update.
4. **The owner's sign-off** in [section 8.4](threat-model.md#84-sign-off): the residual risks of section 7 accepted or reopened, and the questions that R19, R21, R33 and R36 leave to the owner answered (R17 is accepted for the beta, owner 2026-11-12). Section 8.3 waits for the device test; the row says so. **Why:** the beta is public, and section 9 asks for a sign-off before each store release.

### 9. Cutting beta.1

The owner, as [releasing.md](releasing.md#cutting-a-release) says; `app/pubspec.yaml` already has `1.0.0-beta.1+1`, and Play's What's new for 1000001 exists:

1. **The checks before the tag** (releasing.md steps 1 to 8): Cronet checked, German complete, as for every `x.y.0` and its betas ([Languages]), both dry runs ([Android](releasing.md#the-dry-run), [iOS](releasing.md#the-ios-dry-run)), the workflow "Contract matrix" ([Servers](decisions.md#servers)) green on `main` or each failure recorded in [Servers](decisions.md#servers) and accepted by the owner, the reminders after a force stop, the smoke and update tests, and a green CI run on `main`. **Why:** a release tag is never moved, so what would fail it is found before it; after the tag only the reviewer's approval stands between the build and the publishing.
2. **Tag `v1.0.0-beta.1` and push the tag** (releasing.md step 9). **Why:** the tag's release run uploads the bundle to Play's `beta` track, the APK to dl.vikunja.io and the GitHub release.
3. **Check all three** (releasing.md step 11). **Why:** the job checks the files it uploads, not what GitHub, dl.vikunja.io and the Play Console then show.
4. **Build and upload the iOS build** from the Mac ([releasing.md](releasing.md#each-testflight-build)). **Why:** no CI job signs for iOS; TestFlight gets the tag's build only from the Mac.

## The beta on Google Play

`io.vikunja.app` is in production in Vikunja's account, so the closed test that a new personal account needs before production, at least 12 testers opted in for 14 days in a row ([testing requirements][play-testing-14]), does not apply, and there is no production application ([Releases]). Each beta goes to the track `beta`, Play's open testing, which the release workflow uploads to ([Releases]), to all its testers at once. [store-listing.md](store-listing.md#testing-and-production) has the track's settings. The owner, with the permissions of [part 3](#3-the-play-developer-account):

1. **Before the first upload:** the listing, its screenshots and every App content form, Data safety included, as [part 4](#4-the-play-app) says. **Why:** Play counts the open track like production ([testing tracks][play-tracks]).
2. **The track** (before the first upload): anyone can join, without a list; the feedback channel is the address for the testers, `hello@vikunja.io` until kolaente has set it up, which the opt-in page shows; countries as for production. **Why:** the opt-in page shows the feedback channel to every tester, and a tester outside the track's countries cannot join.
3. **The first beta:** the bundle of `v1.0.0-beta.1` comes from the release run ([part 9](#9-cutting-beta1)). Allow some days before it is available: Google may review the release first. **Why:** the invitation waits until testers can install it.
4. **The opt-in link,** `https://play.google.com/apps/testing/io.vikunja.app`, then [the invitation](#the-invitation), once the release is available. **Why:** testers join only through that link.
5. **The old app's testers:** look in the Play Console whether the track still has testers of the old app's beta. They get beta.1 as an update over the old app. **Why:** that is the update path of [The previous app] on real devices, so their reports come first. [uncertain: whether the track has testers; the Play Console shows it]

The production release of 1.0.0 is the release run's staged rollout ([cutting 1.0.0](#cutting-100)); Google may review it first (up to 7 days).

## TestFlight

[releasing.md](releasing.md#each-testflight-build) covers the build and its upload; [store-listing.md](store-listing.md#app-store-connect) the test information.

- **Internal testers** (up to 100 users of the App Store Connect team, the owner among them) install a build as soon as it is processed, without a review ([TestFlight overview][tf-overview]).
- **External testers** come through a group with a public link: set the link's criteria (iPhone and iPad, iOS 15 or later) and a tester limit, for example 100, raised when needed ([external testers][tf-external]).
- **Beta App Review** checks the first build of each version that goes to external testers; later builds of the same version might not need a full review, only one build of a version can be in review at a time, and at most six builds go to review in 24 hours. Every 1.0.0 beta has the iOS version 1.0.0, so beta.1 is the one that waits.
- **Test information** ([test information][tf-info]): the beta app description and feedback email of [store-listing.md](store-listing.md#app-store-connect); for Beta App Review the contact (name, phone, email), sign-in required with `demo` and `demo` in the sign-in fields, never in the notes, and `fastlane/metadata/review_information/notes.txt` as the notes.
- **What to Test** for each build, in the dialog that opens when the build is added to the external group, in English and German ([beta.1's](#what-to-test-for-beta1)).
- **Builds expire after 90 days;** a beta that runs longer needs a new build before then.

## Texts for testers

The feedback address in these texts is the one kolaente sets up for the testers, which reaches the app's maintainers; until it exists, it is `hello@vikunja.io` ([Releases]).

### The invitation

> **Test the new Vikunja app before its release**
>
> The new Vikunja app is coming to Android, iPhone and iPad: the app for Vikunja, the open-source task manager that people run on their own servers. It is open source (MIT License): https://github.com/go-vikunja/app
>
> Before version 1.0.0 I am looking for testers. You need:
>
> - an account on a Vikunja server, version 2.3.0 or newer: your own, your organization's, or Vikunja's public demo (tap "Try the public demo" in the app; the demo account is shared and reset now and then, so keep real data out of it);
> - an Android phone or tablet with Android 7.0 or newer and a Google account, or an iPhone or iPad with iOS 15 or newer.
>
> **Android (Google Play):**
>
> 1. Open https://play.google.com/apps/testing/io.vikunja.app with the Google account you use in Play and join the test.
> 2. Install or update Vikunja from Google Play. If you have the earlier Vikunja app, the beta replaces it and takes over your server.
>
> **iPhone and iPad (TestFlight):** install TestFlight from the App Store, then open [the public TestFlight link] on your device and accept.
>
> **Reporting a problem or an idea:**
>
> - in the app: Account tab, the version at the very bottom, then "Help and bug reports";
> - by email to [the feedback address], with the app's version, your device and system version, your Vikunja server's version and the steps that show the problem; the row "Support details" after "Help and bug reports" shows these and more and shares them when you tap Share, without your tasks, names or passwords;
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
> - einen Account auf einem Vikunja-Server ab Version 2.3.0: deinem eigenen, dem deiner Organisation oder der öffentlichen Demo von Vikunja (in der App „Öffentliche Demo ausprobieren“; den Demo-Account teilen sich alle, und er wird ab und zu zurückgesetzt, also gib dort keine echten Daten ein);
> - ein Android-Smartphone oder -Tablet ab Android 7.0 mit einem Google-Konto oder ein iPhone oder iPad ab iOS 15.
>
> **Android (Google Play):**
>
> 1. Öffne mit dem Google-Konto, das du in Play nutzt, https://play.google.com/apps/testing/io.vikunja.app und nimm am Test teil.
> 2. Installiere oder aktualisiere Vikunja aus Google Play. Hast du die bisherige Vikunja-App, ersetzt die Beta sie und übernimmt deinen Server.
>
> **iPhone und iPad (TestFlight):** Installiere TestFlight aus dem App Store, öffne dann [den öffentlichen TestFlight-Link] auf deinem Gerät und nimm die Einladung an.
>
> **Fehler oder Ideen melden:**
>
> - in der App: Tippe im Tab „Account“ ganz unten auf die Version, dann auf „Hilfe und Fehler melden“;
> - per E-Mail an [die Feedback-Adresse], mit der Version der App, deinem Gerät und seiner Systemversion, der Version deines Vikunja-Servers und den Schritten, die den Fehler zeigen; die Zeile „Support-Details“ nach „Hilfe und Fehler melden“ zeigt das und mehr und teilt es, wenn du auf „Teilen“ tippst, ohne deine Aufgaben, Namen oder Passwörter;
> - unter Android als privates Feedback auf der Seite der App in Google Play; auf iPhone und iPad über TestFlight: Mach in der App einen Screenshot und teile ihn als Beta-Feedback, oder sende Feedback von der Seite der App in der TestFlight-App.
>
> Lass Passwörter und Tokens bitte aus jeder Meldung heraus, und melde ein Sicherheitsproblem vertraulich an security@vikunja.io, nicht öffentlich.
>
> Danke, dass du hilfst!

### What to Test for beta.1

TestFlight's What to Test for the first build, with Apple's names (Home Screen, Home-Bildschirm, Mitteilungen). A beta on Play can be announced with the same text and Android's names: home screen, Startbildschirm, Benachrichtigungen.

> Vikunja app 1.0.0-beta.1 is the first beta. Please use it for your tasks as you would every day, and try in particular:
>
> - signing in to your Vikunja server, or "Try the public demo", and the first sync; a second account if you have one;
> - the Overview, Upcoming and search;
> - your projects in the List, Kanban, Table and Gantt views: creating, checking off, moving and reordering tasks;
> - "New task" with Quick Add Magic: dates, labels and the project typed into the title ("How Quick Add Magic works" explains it);
> - a task's details: dates, reminders, repeating, labels, assignees, the description with a checklist, comments and attachments;
> - offline: change something without a connection; the app sends it when you are back online;
> - reminders as notifications, also with the app closed, and the notification's Done and Snooze buttons;
> - the widgets on your Home Screen;
> - the app lock: Account tab, App lock and privacy;
> - the app in English and in German.
>
> Tell me about anything that crashes, looks wrong, is slow, is hard to use or is missing: in the app with Help and bug reports on the About page (Account tab, the version at the bottom), through TestFlight's feedback, or by email to [the feedback address]. The row Support details on the same page gives you what to add to a report.

### Was du in beta.1 testen kannst

> Vikunja-App 1.0.0-beta.1 ist die erste Beta. Nutze sie bitte für deine Aufgaben wie sonst auch, und probier vor allem aus:
>
> - die Anmeldung auf deinem Vikunja-Server oder „Öffentliche Demo ausprobieren“ und die erste Synchronisierung; einen zweiten Account, wenn du einen hast;
> - „Überblick“, „Anstehend“ und die Suche;
> - deine Projekte in den Ansichten Liste, Kanban, Tabelle und Gantt: Aufgaben erstellen, abhaken, verschieben und umsortieren;
> - „Neue Aufgabe“ mit Quick Add Magic: Datum, Labels und Projekt direkt im Titel („So funktioniert Quick Add Magic“ erklärt es);
> - die Details einer Aufgabe: Termine, Erinnerungen, Wiederholung, Labels, zugewiesene Personen, die Beschreibung mit einer Checkliste, Kommentare und Anhänge;
> - offline: Ändere etwas ohne Verbindung; die App sendet es, sobald du wieder online bist;
> - Erinnerungen als Mitteilungen, auch wenn die App geschlossen ist, und die Tasten „Erledigt“ und „… später“ in der Mitteilung;
> - die Widgets auf deinem Home-Bildschirm;
> - die App-Sperre: im Tab „Account“ unter „App-Sperre und Privatsphäre“;
> - die App auf Deutsch und auf Englisch.
>
> Schreib mir zu allem, was abstürzt, falsch aussieht, langsam ist, schwer zu bedienen ist oder fehlt: in der App mit „Hilfe und Fehler melden“ auf der Seite „Über die App“ (im Tab „Account“ ganz unten auf die Version tippen), über das Feedback von TestFlight oder per E-Mail an [die Feedback-Adresse]. Die Zeile „Support-Details“ auf derselben Seite gibt dir, was du einer Meldung beilegen kannst.

## During the beta

- **Where reports land:** the inbox of the feedback address, `hello@vikunja.io` until kolaente has set up the testers' address (also the replies to TestFlight's invitations and the address on Play's opt-in page); Play's private feedback from testers in the Play Console [uncertain: where the Console lists it]; TestFlight's feedback with screenshots and its crash reports in App Store Connect under TestFlight; the issues of go-vikunja/app, through its bug and feature forms. A security problem goes privately by email to security@vikunja.io, with the PGP key on [vikunja.io/security](https://vikunja.io/security/), never into a public issue ([SECURITY.md](../SECURITY.md)).
- **The beta log:** for each report its date, channel, platform and version, what happened, and the fix with its beta.N, without testers' names or addresses. It goes into the 37d decision.
- **Each fix ships as the next `v1.0.0-beta.N`,** never as a moved tag ([releasing.md](releasing.md#cutting-a-release)): a commit on `main` with its green CI, then the tag, whose release run uploads the bundle to Play's `beta` track, once a reviewer of the environment `release` approves it. Its What's new on Play is the committed `fastlane/metadata/android/<language>/changelogs/<versionCode>.txt`, written in the release commit ([Releases](decisions.md#releases)); the iOS build goes to TestFlight with its What to Test.
- **Crash data** comes from Play vitals, TestFlight's crash reports and, from the testers who allow them, the app's own crash reports in Vikunja's Sentry ([Diagnostics](decisions.md#diagnostics)), in the old app's project, once the owner has set its key ([part 1](#1-the-repository-and-ci)); a build without the key has none. Release builds print nothing. A tester's report can carry the support details ([Diagnostics](decisions.md#diagnostics)): the versions, the background state, the queue's counts and failure kinds, the last session end and the app's redacted diagnostics log of the last 7 days.
- **The privacy section on vikunja.io** describes the testers, the stores' statistics and the downloads before any of them existed: read those statements again once the beta has started ([vikunja-io-drafts.md](vikunja-io-drafts.md), below).

## Before 1.0.0

In any order unless a step says otherwise, before the tag `v1.0.0`:

1. **The iOS device test** (the owner, on his iPhone or iPad, before the App Store submission): [the list below](#the-ios-device-test); the results go into the 37d decision. **Why:** the iOS checks so far ran on the simulator, so what only a device and App Store Connect show is untested until then.
2. **TalkBack, Switch Access and VoiceOver** (the owner at the controls, in the device phase): the manual passes of [accessibility-checklist.md](accessibility-checklist.md#2-manual-on-android) ([Q19](open-questions.md#q19-device-setup-for-the-manual-talkback-pass)), with VoiceOver from the device test (owner, 2026-11-20); the Accessibility Scanner is not used (owner, 2026-11-20 and 2026-11-21; [Accessibility](decisions.md#accessibility)). **Why:** no automated test hears what a screen reader says or moves through the app by switch.
3. **The threat model again** (the owner, on the tree to be released; [section 9](threat-model.md#9-review-cadence)): 8.1, 8.2 again for what changed since the beta's sign-off, 8.3 from the device test, and a new row in [section 8.4](threat-model.md#84-sign-off). **Why:** 1.0.0 reaches every user of the old app through production, and section 9 asks for the review before each store release.
4. **The public demo** (the owner asks the Vikunja maintainers): whether the testers and the stores' reviewers may use try.vikunja.io with the demo account (the review notes ask the reviewers not to delete it) and whether there are times it should not be used ([Releases]), or whether the reviewers can have an account of their own on a server that is not reset. **Why:** App Review signs in with it, and a deleted or reset account during a review fails the review.
5. **The written offer's wording** for desugar_jdk_libs (kolaente confirms it; [what kolaente does](#3-outside-github) step 23; the text is in `app/assets/legal/android.md`, [Releases]). **Why:** Play and dl.vikunja.io rely on it for the library's source.
6. **The privacy section's open points** ([vikunja-io-drafts.md](vikunja-io-drafts.md)): Vikunja Cloud's terms, the legal bases and periods that kolaente checks, what App Store Connect shows of the testers, and the statements about the stores' statistics and the testers, which the owner reads again once the beta has started. **Why:** those statements were written before any tester or download existed, and the policy must describe what actually happens.
7. **France** ([Q23](open-questions.md#q23-french-encryption-declaration-for-the-app-store), open; the owner, before the App Store submission): Apple's [export compliance table][apple-export] asks for a French encryption declaration for an industry-standard algorithm that the operating system does not provide, and the app's `dart:io` TLS uses BoringSSL from the Flutter engine. The choices: file the declaration with the ANSSI, find an exemption that covers it, or leave France out of the App Store's availability. **Why:** App Store Connect's availability includes France unless it is left out, and the declaration is Apple's condition for it.
8. **Step 19, the iOS widgets** (the owner, after the device test): accepted or reopened; it is still in review. **Why:** its device checks are part of the device test.
9. **Accessibility Nutrition Labels** (the owner, in App Store Connect): blank unless the passes of step 2 and the device test confirm a feature ([store-listing.md](store-listing.md#app-store-connect)). **Why:** a label is a public claim of support, and an unchecked one would be false.
10. **The App Store's screenshots** (the owner, on the simulators), then `python3 -I tool/check_store_metadata.py --strict`, before the submission ([store-listing.md](store-listing.md#screenshots)). **Why:** the check fails while a store's minimum set of screenshots is missing, and the submission needs them.

No US export report is due: since BIS's rule of 29 March 2021 ([86 FR 16482][bis-rule]) the annual self-classification report covers only mass-market components and executable software ([15 CFR 740.17(e)(3)][cfr-740-17]), not an end-user app with standard encryption only ([releasing.md](releasing.md#export-compliance)).

### The iOS device test

The list gathers the iOS phase's known gaps ([Releases]), section [8.3](threat-model.md#83-final-ios-phase) of the threat model and the device notes on the App language row and the owner's UI review ([Languages], [Look and layout]). It runs on the owner's iPhone or iPad with Xcode 27.2 (27B52; the iOS phase's simulator checks used 27.1), and the results go into the 37d decision.

- [ ] The first signed build and its TestFlight upload: App Store Connect's processing passes, the real test of the privacy manifests and the required-reason APIs.
- [ ] Whether a release build needs `DEAD_CODE_STRIPPING=NO` for the lock-screen widgets.
- [ ] The sensitive clipboard (8.3 #3): a new API token and a share link copy, do not reach a Mac through Universal Clipboard, and the pasteboard is empty after two minutes.
- [ ] Widget links and notification taps (8.3 #4, #5): rows carry the key, another account's widget row and notification switch accounts, the same link from Safari or Notes does not.
- [ ] Widgets (8.3 #6): rows, titles and their VoiceOver labels redacted on the Lock Screen and in StandBy; Done from a widget asks for the unlock; the setup fields, the project picker per account, placed widgets, "+N more".
- [ ] Widgets after midnight and Done (step 40t): with the app closed and no background run, after midnight the rows show dates instead of Today or Tomorrow, VoiceOver reads them, VoiceOver says Overdue for a row shown overdue, and the medium and larger widgets show "Open Vikunja to update". Done on a widget row takes away the task's pending reminder and one already shown in Notification Center at once, before the app runs (the extension reaches the app's notifications); a Snooze on another task's notification does not bring them back. If the extension cannot reach them, record it as a limit in [Notifications and widgets].
- [ ] The app lock (8.3 #7): the passcode fallback, the lockout, Done in a locked notification (`task_locked`) asks for the unlock.
- [ ] Snooze-only reminders (step 48f): a reminder of a task in a read-only or archived project (`task_snooze`) offers 10 minutes, 1 hour and Tomorrow and no Done, also while the app lock is on.
- [ ] App lock and a clock set back (step 48l): with the lock on and 1 minute, turn off Set Automatically, leave the app for 2 minutes or more, set the time back to just after leaving and return: Face ID asks; a return within the minute opens without a visible delay.
- [ ] The connection settings under SecTrust (8.3 #8): handshake pinning, a PKCS#12 client certificate, CA trust under the 825-day rule, access headers through NSURLSession, ASWebAuthenticationSession's warning for a pinned server.
- [ ] A restore (8.3 #9): an encrypted backup restored to another device brings back no tokens, connection secrets, databases or widget files.
- [ ] The capture cover (8.3 #11) in a real screen recording, AirPlay or mirrored display.
- [ ] Photo locations (8.3 #12): a photo from Photos, a photo and a video taken with the camera, each without its location on the server.
- [ ] The XCTests (8.3 #14, step 40u): `xcodebuild test -scheme RunnerTests` on a simulator passes its 13 tests, the HEIC one run.
- [ ] The held iOS plugins ([releasing.md](releasing.md#held-ios-plugins), step 40h): a build with the newest `file_selector_ios`, `image_picker_ios` and `webview_flutter_wkwebview` runs the file and photo pickers, the photo-location check above and the description editor; if they pass, one commit lifts the three pins.
- [ ] Background refresh through BGTaskScheduler (`io.vikunja.app.sync`).
- [ ] An account's online flows (the simulator checks had only an expired session).
- [ ] Increase Contrast, Bold Text, Reduce Motion and VoiceOver: [accessibility-checklist.md](accessibility-checklist.md#3-final-ios-phase) section 3.
- [ ] iPad: the wheel popups as cards, an iPad mini and an 11-inch iPad, Split View and Slide Over.
- [ ] The iOS parts of the owner's UI review ([Look and layout]): the help button, the new-task sheet above the home indicator, the Cupertino Theme control on the Account tab, the project folder in light, dark and tinted rendering.
- [ ] The App language row ([Languages]): the Language entry in Settings with one and with two preferred languages.
- [ ] The About page's "Help and bug reports" row opens the help page on vikunja.io.
- [ ] The support details ([threat model 8.3](threat-model.md#83-final-ios-phase) #13): the Runner builds with the device channel's `backgroundState`, the page's Background App Refresh and Low Power Mode lines follow the settings, and Share opens the share sheet from its button on an iPad.
- [ ] iOS 15 to 17.3 (8.3 #10): the sign-in fallback below iOS 17.4 and the system SQLite on iOS 15, if a device is at hand. Otherwise the owner decides: accept it untested, borrow a device (Xcode 27 is reported to debug only on iOS 17 or later, so such a device may take TestFlight builds only [unverified]), or raise the minimum.

## Cutting 1.0.0

Once everything [before 1.0.0](#before-100) is done (the app is in production on Play already, so no production access is applied for), the owner:

1. **The release** as [releasing.md](releasing.md#cutting-a-release) says: `app/pubspec.yaml` to `version: 1.0.0+1`, Cronet checked, both dry runs, a green CI run, the tag `v1.0.0` (version code and iOS build 1000099), the approval by a reviewer of the environment `release`, the GitHub release and dl.vikunja.io checked. **Why:** it is the first release to production, which reaches every user of the old app.
2. **Google Play:** the release run uploads the bundle to production as a staged rollout, to the share `VIKUNJA_APP_PLAY_ROLLOUT` (0.1 when unset); raise or complete it in the Play Console as [the rollout](releasing.md#the-rollout) says, with its abort thresholds. Google may review the production release first (up to 7 days). **Why:** the workflow never changes a rollout after its upload, and a halted stage keeps a regression to the users who have it.
3. **The App Store:** upload the build from the Mac ([releasing.md](releasing.md#each-testflight-build)); in App Store Connect add it to version 1.0.0 with the version's texts and screenshots, the App Review information (the sign-in information in its fields, the notes, the maintainers' answer if Apple asks for it) and France as [Q23](open-questions.md#q23-french-encryption-declaration-for-the-app-store) decides, choose the 7-day phased release ([the rollout](releasing.md#the-rollout)), then submit it for review. Once 1.0.0 is released it takes no more builds; fixes go into 1.0.1. **Why:** the App Store has no rollback, so the phased release is the only way to slow a regression.
4. **Afterwards:** the store links and the GitHub release in the README and on the help page on vikunja.io (kolaente publishes it), the 37d decision completed, and step 37d closed in the roadmap. **Why:** until then the README and the help page send people to the beta.

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
[gh-rename]: https://docs.github.com/en/repositories/creating-and-managing-repositories/renaming-a-repository
[gh-limits]: https://docs.github.com/en/repositories/creating-and-managing-repositories/repository-limits
[crowdin-cli-sources]: https://crowdin.github.io/crowdin-cli/commands/crowdin-upload-sources
[crowdin-cli-translations]: https://crowdin.github.io/crowdin-cli/commands/crowdin-upload-translations
[crowdin-config]: https://support.crowdin.com/developer/configuration-file/
[crowdin-github]: https://support.crowdin.com/github-integration/
[gh-token]: https://docs.github.com/en/actions/concepts/security/github_token
[gh-approve]: https://docs.github.com/en/actions/how-tos/manage-workflow-runs/approve-runs-from-forks
[gh-environments]: https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments
[gh-actions-settings]: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository
[crowdin-cli-release]: https://github.com/crowdin/crowdin-cli/releases/tag/5.6.0
[crowdin-cli-download]: https://crowdin.github.io/crowdin-cli/commands/crowdin-download-translations
[gh-roles]: https://docs.github.com/en/organizations/managing-user-access-to-your-organizations-repositories/managing-repository-roles/repository-roles-for-an-organization
[gh-secrets]: https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets
[gh-ruleset-bypass]: https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/creating-rulesets-for-a-repository#granting-bypass-permissions-for-your-branch-or-tag-ruleset
[gh-required-reviews]: https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/reviewing-changes-in-pull-requests/approving-a-pull-request-with-required-reviews

- Google Play and Android: [Play App Signing][play-app-signing], [developer verification][android-verification], [device verification for new personal accounts][play-device], [testing requirements for new personal accounts][play-testing-14], [testing tracks][play-tracks]
- Apple: [TestFlight overview][tf-overview], [external testers][tf-external], [test information][tf-info], [complete review][apple-complete-review], [export compliance documentation][apple-export]
- US export: [86 FR 16482][bis-rule], [15 CFR 740.17][cfr-740-17]
- Vikunja: [contact][vikunja-contact]
- GitHub, read on 2026-11-16 and 2026-11-23 for [the move](#the-move): [renaming a repository][gh-rename], [repository limits][gh-limits]
- Crowdin, read on 2026-11-16 for [the translations on Crowdin](#the-translations-on-crowdin): [the CLI's source upload][crowdin-cli-sources] and [translation upload][crowdin-cli-translations], [the configuration file][crowdin-config], [the GitHub integration][crowdin-github]
- GitHub and Crowdin, read on 2026-11-22 for the workflow "Crowdin": [the workflow's token and the pull requests it opens][gh-token], [approving workflow runs][gh-approve], [environments][gh-environments], [the Actions settings][gh-actions-settings], [Crowdin CLI 5.6.0][crowdin-cli-release], [the CLI's translation download][crowdin-cli-download]
- GitHub, read on 2026-11-22 for [who does what on GitHub](#who-does-what-on-github): [repository roles][gh-roles], [secrets and variables][gh-secrets], [bypass lists of rulesets][gh-ruleset-bypass], [required reviews][gh-required-reviews]

[Identity and scope]: decisions.md#identity-and-scope
[Notifications and widgets]: decisions.md#notifications-and-widgets
[Diagnostics]: decisions.md#diagnostics
[Look and layout]: decisions.md#look-and-layout
[Languages]: decisions.md#languages
[The previous app]: decisions.md#the-previous-app
[Releases]: decisions.md#releases

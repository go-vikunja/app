# Beta and 1.0.0

The owner's runbook for step 37d ([D77]): from the move into go-vikunja/app through the beta on Google Play's open testing track and on TestFlight to 1.0.0 in both stores. Each part comes in the order it is done. [releasing.md](releasing.md) has how a release is cut and every one-time setting, and [store-listing.md](store-listing.md) every console form with its answer; this page links them and adds what neither covers. The tester-facing texts are in English and German. None of this is legal advice.

Since [D83](decisions.md#d83-successor-of-the-official-vikunja-app-in-go-vikunjaapp) the beta runs in the official Vikunja listing, after the switch of steps 38a to 38f: the app is called Vikunja, its id is the official app's `io.vikunja.app` ([D15](decisions.md#d15-app-id-iovikunjaapp-and-the-name-vikunja)), the Play app is the one in Vikunja's Play account, and its bundles are signed with Vikunja's upload key. Since step 38a the names, ids and texts on this page are the official app's. Since step 38c the parts on CI, the keys and the releases (1, 2, 7 to 9, and the release steps during the beta and before 1.0.0) describe GitHub Actions in go-vikunja/app ([D86](decisions.md#d86-ci-and-releases-on-github-actions)); since step 38f ([D89]) parts 3 to 6, [the beta on Google Play](#the-beta-on-google-play) and the tester texts are written for Vikunja's accounts: Play's closed test of 12 testers for 14 days does not apply, as `io.vikunja.app` is in production, the beta goes to Play's open testing track `beta`, and the app's pages are on vikunja.io. Since step 38d ([D87]) the repository is under the MIT License, GitLab's pipeline is gone, and [the move](#the-move) comes first. Since step 38e ([D88]) the translations come from Vikunja's Crowdin project, set up after the move and [a rehearsal](#the-crowdin-rehearsal) ([the translations on Crowdin](#the-translations-on-crowdin)).

The owner's decisions of 2026-11-02 behind it ([D77]): [Q20](open-questions.md#q20-signing-keys-and-the-apk-beside-the-play-build)'s option A for the keys; a new app id, since step 38a the official app's `io.vikunja.app` ([D15](decisions.md#d15-app-id-iovikunjaapp-and-the-name-vikunja)); a "Help and bug reports" row on the About page; the closed test's testers through a Google Group (since step 38f Play's open test instead, [D89]) and TestFlight's external testers through a public link; testers on their own Vikunja server (2.3.0 or newer) or the public demo, `try.vikunja.io`. iOS builds stay on the owner's Mac.

## The move

Step 38d ([D87]): the repository joins go-vikunja/app with its whole history, so that every commit hash the docs cite stays valid. The pull request comes from the owner's fork and has only two commits of its own: one removes the old app's files, and one merges our `main` with `--allow-unrelated-histories`. The tree it leaves is exactly our `main`. The commands below were rehearsed on 2026-11-16 against a local copy of go-vikunja/app and a local stand-in for the fork, the pushes and the merge included.

### Before you start

- 38d's own changes are on our `main`, reviewed and green, so the imported tree is the reviewed one.
- kolaente has agreed to the freeze of go-vikunja/app's `main`, from the tag of step 3 until the merge, and has changed the ruleset for the import ([what kolaente does](#what-kolaente-does)).
- The GitHub account has the commits' author address (`git log --format='%ae' -1`) as a verified email, so that GitHub links the commits to it, and "Block command line pushes that expose my email" is off, or the push fails with GH007.
- The tracked test-server users, `test_servers/seed/e2e-user.env` and `e2e-user-2.env`, hold nothing used anywhere else. The history goes public unchanged: it holds no real secret, and most of it is public on GitLab already.
- The push to the fork publishes: commits pushed there stay reachable from every repository of the network, go-vikunja/app included, even after the fork is deleted ([forks][gh-forks]). Push nothing that has not passed the checks below.

### The commands

```sh
# 1. A fresh clone beside the working repository; the working copy and its stash stay untouched
WORK=~/path/to/the/working/repository
git clone https://github.com/go-vikunja/app.git vikunja-import
cd vikunja-import
git config user.name "<your name>"
git config user.email "<the address of the imported commits>"

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
  -m "Joins the new app's history to the old app's, so every commit hash of both stays valid."
```

The removal takes everything of the old app: its workflows and `.drone.yml`, the `Makefile`, the devenv files and `.envrc`, `renovate.json` and its `crowdin.yml` (our `main` brings step 38e's own, [D88]), `.vscode`, `.metadata` and the old Flutter tree. The old tags and releases stay; there is no `legacy` branch.

### The checks before pushing

Each line must print `ok`, or show what its comment says:

```sh
B=import-new-app
test "$(git rev-parse "$B^{tree}")" = "$(git rev-parse 'ours/main^{tree}')" && echo "ok: the tree is exactly our main"
test -z "$(git diff --stat "$B" ours/main)" && echo "ok: nothing differs from our main"
git merge-base --is-ancestor legacy-final "$B" && echo "ok: the old main is an ancestor, so the PR has no conflicts"
git merge-base --is-ancestor ours/main "$B" && echo "ok: every hash of ours stays"
test -z "$(git status --porcelain)" && echo "ok: the working tree is clean"
git log --format='%an <%ae> | %cn <%ce>' legacy-final.."$B" | sort | uniq -c   # one line: the owner's address
git ls-tree --name-only "$B:.github/workflows"                                  # ci, contract-matrix, release and upstream (.yaml)
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
2. `feat: import the new Vikunja app with its history` merges the new app's `main` with `--allow-unrelated-histories`. The resulting tree is exactly that `main`.

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

- The GitLab project gets a description that points to https://github.com/go-vikunja/app and is archived (Settings > General > Advanced > Archive project). Since step 38f none of the app's pages links it: the only ones that did, on the owner's former website, are offline.
- The test repository of step 38c is deleted or made private.
- The result goes into [D87], which settles D83's open point on how the two histories are joined.

### The Crowdin rehearsal

*Done on 2026-11-16 ([D88] has the results): the integration put the source into a version branch `main` beside the root file, so the German upload took `-b main`; its pull request had no `[ci skip]`, got new commits on later syncs instead of a force-push and was green once the German was in; the first export reformats every ARB file once; and an English change drops that text's translations until they are approved again. The run after the re-approval was green.*

### The translations on Crowdin

Step 38e ([D88]): the app's texts go into Vikunja's Crowdin project 462614, beside the web's and the API's. The rehearsal showed that the integration puts the app's file into a version branch `main` as `main/app_en.arb`, beside the root `/app_en.arb`, into which the old app's nightly workflow "Crowdin Sync" uploaded the old app's 188 strings until the import. Once kolaente has connected Crowdin's GitHub integration, it reads `crowdin.yml`, uploads the English source from `main` and opens pull requests with the approved translations. One upload comes once, by the owner, right after the source: our German as approved translations, so that German stays complete.

**Before you start:**

- [The rehearsal](#the-crowdin-rehearsal) is done (2026-11-16).
- The import is merged, which removed the old workflow, or kolaente has disabled it: otherwise its nightly runs keep writing the old app's 188 strings into the root `/app_en.arb`.
- The Crowdin items of [what kolaente does](#what-kolaente-does) are done. With your Developer role in project 462614 (since 2026-11-21), which may approve translations, connect integrations and manage source files, but not change the project's settings (support.crowdin.com/roles), you can export what Crowdin held in the old root `app_en.arb` and connect the integration yourself, once kolaente has given its bot account write access to go-vikunja/app; the export settings and the language mapping stay with kolaente.
- kolaente has told you where the integration put the source, and the project's Sources show it with the app's strings: as in the rehearsal, `main/app_en.arb` in a version branch `main`, or `app_en.arb` at the project's root, in place of the old app's file.
- The Crowdin CLI (`brew install crowdin`), a new personal access token of your Crowdin account, not the rehearsal's (Account Settings > API, with the earliest expiry offered, not the default Never), and a clean working copy of go-vikunja/app's `main`. `crowdin.yml` holds the project and the paths but no token: the CLI reads the token from `CROWDIN_PERSONAL_TOKEN`.

**The commands,** from the repository root, the upload first as a dry run, which only lists what it would upload:

```sh
read -rs CROWDIN_PERSONAL_TOKEN && export CROWDIN_PERSONAL_TOKEN   # paste the token: it stays out of the shell's history
crowdin config lint

# Our German, approved, also where it equals the English (Vikunja, Kanban, OK)
crowdin upload translations -b main -l de --auto-approve-imported --import-eq-suggestions --dryrun
crowdin upload translations -b main -l de --auto-approve-imported --import-eq-suggestions
```

- `-b main` is for the source in the version branch `main`: without it the CLI writes into the old `/app_en.arb` at the root, which the integration does not export. Drop it only if kolaente found the source at the root.
- Add `--translate-hidden` to both if the project hides duplicate strings: Crowdin otherwise skips the German of a text it hides as a duplicate, for example of the web's. The rehearsal's project had none.
- The CLI waits while Crowdin imports, several minutes. Crowdin may show German at 0 % for some minutes after it ends.
- Leave the source to the integration: `crowdin upload sources` with the wrong `-b` would put a second copy of it into the project. Never add `--delete-obsolete`: the project holds the web's and the API's files too.
- The source in the version branch is a new file, so the old app's translations do not carry over: they stay in the old root file and in the translation memory. The root file stays until kolaente removes it after his export; until then Crowdin's language progress counts it too. The old app's Polish is not uploaded.

**Afterwards:**

- Delete the Crowdin token under Account Settings > API: it acts with your Developer role in 462614, which also holds the web's and the API's files.
- Check that German shows 100 % proofread: Crowdin's docs do not say whether a Developer's upload with `--auto-approve-imported` is approved. If it is not, approve the file's German in the editor (a Developer may), or ask kolaente.
- On Crowdin, German shows the app's file as 100 % translated and 100 % proofread.
- The integration's next sync opens a pull request "chore(i18n): update translations via Crowdin" from its branch `l10n_main` in go-vikunja/app. Its checks run (no `[ci skip]`), and `python3 -I tool/l10n_progress.py de` on its branch prints 100.0 %. The first one reformats every ARB file once: Crowdin copies the template's `@` metadata into each translation, orders the keys its own way and writes no final newline. Read its diff of `app_de.arb` before you merge: the texts must stay ours. Later diffs stay small.
- A pull request the integration opened before the German upload has almost no German and fails the tests that pin German texts: leave it unmerged until a sync after the upload ("Sync Now") has updated it.
- From then on German, like every language, changes only on Crowdin. After an English change, a maintainer re-approves or retranslates its German there: the change leaves the translations unapproved, the export drops them, and the next Crowdin pull request fails where a test pins the German text.
- Pre-translation from the web's translations through the shared translation memory waits for kolaente's agreement, as the web is under the AGPL and the app under the MIT License; once he agrees, it runs without approving, so that a proofreader approves each text. Until then nothing is pre-translated, though translators may see the web's texts as suggestions in the editor.

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
- **The written offer** for the desugar_jdk_libs source: since step 38f the Vikunja project makes it, with the contact `hello@vikunja.io` ("Ask the Vikunja project at hello@vikunja.io." in `app/assets/legal/android.md`, [D89]). GitHub releases carry the source itself; Play and dl.vikunja.io rely on the offer. Confirm it.
- **The Play Console permissions** for the owner, for `io.vikunja.app` only ([D89]): Manage store presence, Manage policy declarations, Release apps to testing tracks, and Manage testing tracks and edit tester lists; not the release to production. Without them, kolaente enters the answers of [store-listing.md](store-listing.md#google-play-console) himself.
- **The pages on vikunja.io:** the privacy section "Mobile app", the help page `/help/mobile` and the imprint's scope sentence, drafted in [vikunja-io-drafts.md](vikunja-io-drafts.md), which kolaente puts into go-vikunja/website himself, before the first beta. The headings "Mobile app" and "Delete your account" and the slug `mobile` keep their words: the app and the stores link them.
- **Vikunja Cloud's terms** or data processing agreement: its URL for the privacy section.
- **The address for App Review and the testers,** one that reaches the app's maintainers, in place of `hello@vikunja.io` in `fastlane/metadata/review_information/email_address.txt`, TestFlight's feedback email, the open test's feedback channel and the tester texts.
- **The store texts:** whether the full description keeps the sloth line's spirit, and whether it names Vikunja Cloud as a server ([store-listing.md](store-listing.md#texts)).
- **The Apple account** that publishes the app: with it the App Store name (whether "Vikunja" is still held by the former contributor's team that the old app's `ios/fastlane/Appfile` names), the bundle id and the privacy label, which is open since step 38f ([store-listing.md](store-listing.md#app-store-connect)).
- **The old app's `app_en.arb`:** the integration does not replace it but puts the app's file beside it, as `main/app_en.arb` in a version branch `main` ([the rehearsal](#the-crowdin-rehearsal)). Export the old root file first if anyone translated it since December 2025, then delete it: until then it counts in each language's progress. Its translations stay in the translation memory.
- **The old workflow "Crowdin Sync":** the import removes it; if the import is delayed, disable it (Actions > Crowdin Sync > Disable workflow), as each nightly run uploads the old app's `app_en.arb` into the project's root file again.
- **The manager role** for the owner is not needed any more: since 2026-11-21 the owner is a Developer in project 462614, who may approve translations, connect the integration and export or delete the old root file. What still needs kolaente there: the bot account's write access to go-vikunja/app, the export settings and the language mapping below.
- **The project's export settings** (Settings > Export): "Skip untranslated strings" and "Export only approved translations" on, as `crowdin.yml` asks for the app's file, since Crowdin does not document whether the integration follows `crowdin.yml` there; the server's sync passes both already.
- **Crowdin's GitHub integration** in project 462614 (Integrations > GitHub), for go-vikunja/app once the import is merged ([the translations on Crowdin](#the-translations-on-crowdin)):
  - connected through a dedicated bot account, not a person's: Crowdin acts with that account's GitHub authorization, its commits name that account as author, and only the member who sets the integration up can change it. The account needs write access to go-vikunja/app and nothing else; Crowdin's staff say it lists only repositories where the account is an admin, so admin at most for the setup;
  - the branch `main` with the configuration file `crowdin.yml`, and "Push Sources", "One-time translation import after the branch is connected" and "Always import new translations from the repository" off, as the owner's upload brings the German, approved;
  - no `[ci skip]`: Crowdin adds it to its commit messages by default, and GitHub then runs none of the required checks, so its pull requests could never be merged. `crowdin.yml` sets the commit message without it (`append_commit_message: false`), which held in the rehearsal; check that the integration's own settings do not add it back;
  - "main protect" keeps requiring a maintainer's approval, so that the account cannot merge its own pull requests;
  - before the owner's German upload, check where it put the source and tell the owner: in the rehearsal a new `main/app_en.arb` in a version branch `main`, for which the upload takes `-b main`, beside the old root file; or `app_en.arb` at the project's root, in place of the old app's file;
  - after the integration has synced once, the bot account lowered to Write; then Sync Now, and check that it still pushes `l10n_main` and updates its pull request. If it needs admin to keep working, tell the owner before going on, as the threat model's R40 assumes Write. The account stays off the bypass lists of "main protect" and of the `v*` ruleset, and the admin window stays short: a tag ruleset that lets the Repository admin role bypass it lets the bot bypass it too while the bot is admin.
- **Swiss German:** in the project's language mapping, map the custom language `de-swiss` to `gsw` for the placeholder `two_letters_code` only. `crowdin.yml` cannot do it: the CLI accepts only Crowdin's standard codes there. The mapping is project-wide, but the web's and the API's files are named by `%locale%` (go-vikunja/vikunja's `crowdin.yml`), so they keep their names. Without the mapping Swiss German is exported under its own two-letter code, which must then not be `de`, or it overwrites the German.
- **Pre-translation from the web:** whether the app may take the web's translations through the shared translation memory (the web is under the AGPL, the app under the MIT License).
- **Crash reports** (step 41, [D113](decisions.md#d113-opt-in-crash-reports-through-vikunjas-sentry)): the new app uses the old app's Sentry project as it is, and the owner sets its DSN ([part 1](#1-the-repository-and-ci)), so nothing needs creating. What only an administrator of Vikunja's Sentry organisation can check, before a beta that sends reports:
  - in the project's settings: Security & Privacy > "Prevent Storing of IP Addresses" on, the Data Scrubber and its default scrubbers on; as a net behind the app's own scrubbing, an advanced data scrubbing rule that removes `$user`; spike protection and a rate limit per key, as anyone can read the DSN from either app and send events with it; the data retention. These settings hold for the old app's reports as well;
  - the organisation's data region (United States or EU), for the privacy section ([vikunja-io-drafts.md](vikunja-io-drafts.md), `SENTRY-REGION` and `SENTRY-RETENTION`).
- **The old secrets** `CROWDIN_PROJECT_ID` and `CROWDIN_PERSONAL_TOKEN` of go-vikunja/app: delete them. Nothing uses them after the import, and a workflow on any branch can read a repository secret. Then check Settings > Secrets and variables > Actions of go-vikunja/app: there should be no other repository secret, and among the organisation secrets available to the repository only `S3_ENDPOINT`, `S3_BUCKET` and `S3_REGION` (no credential, [releasing.md](releasing.md#once-in-go-vikunjaapp) step 2) may remain. Remove go-vikunja/app from the access list of any other organisation secret, or enter that secret in the environment `release` instead: a workflow on any branch, one pushed through the integration's account included, can read every repository and organisation secret the repository gets.

## Before beta.1

### 1. The repository and CI

The releases come from GitHub Actions in go-vikunja/app after [the move](#the-move) (step 38d; [D86](decisions.md#d86-ci-and-releases-on-github-actions)). Until then the CI scripts run on the Mac and in the owner's test repository, and nothing is published.

1. **The trial:** done on 2026-11-16 in a test repository of the owner's, with the repository variable `VIKUNJA_APP_RELEASE_DRY_RUN=true` and no secret, as [releasing.md](releasing.md#the-dry-run) describes. A test tag there ran the release with throwaway keys and published nothing. [D86](decisions.md#d86-ci-and-releases-on-github-actions) has the results.
2. **go-vikunja/app,** after the move: Vikunja's maintainers set up the environment `release`, its secrets, the committed certificates, the rulesets, the Actions settings and private vulnerability reporting ([releasing.md](releasing.md#once-in-go-vikunjaapp)). The old pipeline's upload of every push to `main` to Play stops with the import, which removes its workflow.
3. **The crash reports' key** (step 41, [D113](decisions.md#d113-opt-in-crash-reports-through-vikunjas-sentry)): the new app sends its crash reports to the old app's Sentry project, as it is (owner, 2026-11-21); its reports are told apart from the old app's by their release, `io.vikunja.app@1.…`. The owner, who may create variables in go-vikunja/app, copies that project's DSN from the old app's code into the **repository variable** `VIKUNJA_APP_SENTRY_DSN` (Settings > Secrets and variables > Actions > Variables), with no spaces or line breaks, before the first tag whose builds should send reports. A variable, not a secret: every build carries the DSN, and the release job has no environment, so an environment's variable would not reach it ([releasing.md](releasing.md#crash-reports)). The DSN goes into no file of the repository; a build without it has no crash reports at all.

### 2. The keys

The keys are Vikunja's ([D83](decisions.md#d83-successor-of-the-official-vikunja-app-in-go-vikunjaapp)): the old app's upload key signs the bundles and, without a separate APK key, the APK, as in the old app, so installs of the old app's APKs keep updating. [Q20](open-questions.md#q20-signing-keys-and-the-apk-beside-the-play-build)'s option A, an app signing key of the owner's, no longer applies, and the owner creates no key.

- **The secrets:** `KEYSTORE_BASE64` and `KEY_PROPERTIES`, the Play service account and the dl.vikunja.io storage keys, entered again by Vikunja's maintainers as secrets of the environment `release`, with no repository or organisation copy ([releasing.md](releasing.md#once-in-go-vikunjaapp) steps 1 and 2). The key that signs the APK must be RSA.
- **The certificates:** the upload certificate's SHA-256 from the Play Console, committed in `tool/ci/release_certificates.txt` before the tag ([releasing.md](releasing.md#once-in-go-vikunjaapp) step 3); a real release fails without it.
- **Developer verification:** the key that signs the APK is registered in Vikunja's Play Console, so that certified devices that require a registered key install the APK ([developer verification][android-verification]).

### 3. The Play developer account

- **Vikunja's account,** in which `io.vikunja.app` is in production ([D83](decisions.md#d83-successor-of-the-official-vikunja-app-in-go-vikunjaapp), [D89]). Its identity, its contact details and its trader status are Vikunja's and are kolaente's to keep; the owner creates no developer account of his own. A new personal account's requirements, the closed test with 12 testers for 14 days and the verification of a real phone in the Play Console app, do not apply ([store-listing.md](store-listing.md#testing-and-production)).
- **The owner's permissions** for `io.vikunja.app` only, granted by kolaente ([what kolaente does](#what-kolaente-does)): Manage store presence, Manage policy declarations, Release apps to testing tracks, and Manage testing tracks and edit tester lists; not the release to production, which the release workflow does through Vikunja's service account ([part 2](#2-the-keys)).

### 4. The Play app

- **The app** is the one in Vikunja's Play account, `io.vikunja.app` ([D83](decisions.md#d83-successor-of-the-official-vikunja-app-in-go-vikunjaapp)); the release workflow uploads through Vikunja's service account ([part 2](#2-the-keys)). (The plan before the switch, an app with Play App Signing on the owner's key, no longer applies.)
- **Every form** as [store-listing.md](store-listing.md#google-play-console) answers it, before the first beta upload, as the open test counts like production: store settings and contact details, the listing in both languages with the graphics of `branding/png/`, the privacy policy, App access with the public demo, Ads, Content rating, Target audience, News, Data safety (the union of the old app's declaration and the new app's, with the old app's opt-in Sentry crash reports as crash logs, diagnostics and other app performance data; encryption in transit "No"), Government, Financial features, Health, Advertising ID. After the first upload, check that App content asks for no exact-alarm or foreground-service declaration.
- **The screenshots:** the listing goes out with the first beta, screenshots included. Step 38f retook all 20 Play screenshots, phone and tablet in en-US and de-DE, on 2026-11-17 with the build of that day (owner): the sets of 2026-11-03 showed „Konto“ in German, the tablet ones lacked the project tree, and the task views predated steps 37h and 37k ([store-listing.md](store-listing.md#screenshots)). A session runs on emulators made for it, with the demo data and the owner's sign-in once per device. The App Store's sets wait for a session on the simulators before the 1.0.0 submission ([before 1.0.0](#before-100)); TestFlight needs none.

### 5. The Apple account and the app record

[releasing.md](releasing.md#once-before-the-first-upload) has each step:

- the Apple Developer Program (the enrolled name shows as the seller; renewed every year), the team id, Xcode signed in with an iPhone registered;
- the App IDs `io.vikunja.app` and `io.vikunja.app.widgets`, both with only the App Group `group.io.vikunja.app` (Xcode creates them on the first signed build, or by hand under Identifiers). Which Apple account publishes the app is open, and `io.vikunja.app` may already be taken at Apple; until both are settled, no build for a device with automatic signing ([D15](decisions.md#d15-app-id-iovikunjaapp-and-the-name-vikunja));
- the app record `Vikunja` with the bundle id `io.vikunja.app`, which reserves the name, so create it early; the old app's TestFlight record in a former contributor's team may hold the name and the bundle id, and a fallback name is picked only if App Store Connect refuses it ([D89]);
- the App Store Connect API key, outside the repository;
- the source link, the tree at the tag of `VIKUNJA_APP_SOURCE_CODE_URL`, by default https://github.com/go-vikunja/app, which has the tag only after the move (step 38d; [releasing.md](releasing.md#once-before-the-first-upload) step 6);
- the App Store Connect forms and TestFlight's test information ([store-listing.md](store-listing.md#app-store-connect)), with the privacy label, which is open until this account is decided: if Vikunja's account publishes, the public demo and Vikunja Cloud are the developer's own servers.

### 6. The app's pages on vikunja.io

Since step 38f the About page and both listings link the app's pages on vikunja.io: the section "Mobile app" of the privacy policy, the help page `/help/mobile` with "Delete your account", and the imprint ([D89], [store-listing.md](store-listing.md#the-website)). kolaente publishes them from the drafts in [vikunja-io-drafts.md](vikunja-io-drafts.md) ([what kolaente does](#what-kolaente-does)). Before the first rollout to testers, open each address of that table signed out, each with its anchor. Until then the URLs compiled into every build lead to a policy without the app's section and to a missing page, so no build is distributed before.

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
- GitHub's macOS runners, which three times had none free for `ios` ([releasing.md](releasing.md#when-the-publish-job-fails));
- since step 40h: `ios` on the image `xcode-27` (Xcode 27, like the releases) in place of `macos-26` with Xcode 26.6, which no run has tried yet; the per-ABI APKs in the release build and its artifact; the first runs of the workflow "Upstream versions" and of Dependabot; Gradle's dependency verification on Linux, whose `aapt2` is trusted without a checksum ([releasing.md](releasing.md#gradle-dependency-verification));
- since step 40u: `ios` booting a simulator for the XCTests after the build, and the workflow "Contract matrix", whose nightly run starts with the import and which pulls six server images from Docker Hub per run ([D28](decisions.md#d28-contract-tests-against-the-latest-vikunja-release-only)); neither has run on GitHub yet;
- since step 41 ([D113](decisions.md#d113-opt-in-crash-reports-through-vikunjas-sentry)): `ios` resolving sentry_flutter's Swift package, the `sentry-apple-binaries` checkout and its two binary archives, whose download stalled for about 18 minutes in a sandboxed local build ([releasing.md](releasing.md#each-testflight-build)); Gradle's verification of the Sentry artifacts on Linux; and the release build taking the repository variable `VIKUNJA_APP_SENTRY_DSN`, whose log shows the OK line of `check_sentry_dsn` or its notice, and the DSN itself in the step's environment, as GitHub masks no variable ([releasing.md](releasing.md#crash-reports)); none has run on GitHub yet.

Each fix is a commit on `main`; the tag waits for a green run. The environment, the real signing and the publishing first run on go-vikunja/app's first tag.

### 8. The threat model

Each beta is public: its tag publishes a GitHub release with the APK, marked as a prerelease, and the APK on dl.vikunja.io ([D86](decisions.md#d86-ci-and-releases-on-github-actions)), TestFlight's link is public, and anyone can join Play's open test. So the [threat model](threat-model.md#84-sign-off)'s review "before each store release" comes before `v1.0.0-beta.1` ([D77]):

- [ ] **Section [8.2](threat-model.md#82-manual-on-the-android-emulator) on the emulator** in full with the release build, the owner signing in the two accounts, items 5 and 10 on a Google Play image; with it the R33 check, a start of `MainActivity` from another app's activity without `FLAG_ACTIVITY_NEW_TASK` (`adb shell am start` adds that flag, so it needs a caller app), with the fix R33 describes.
- [ ] **Section 8.1** on the tree to be tagged, with its checks of the settings of go-vikunja/app.
- [ ] **The update and smoke tests** (step 40u, part of 8.2's item 13): `tool/e2e/smoke_test.sh` with the release candidate's APK, and `tool/e2e/update_test.sh` with the old app built from `legacy-final` (`cdbc6e3`) and the release candidate, both signed again with one throwaway key, on `Vikunja_Screens`, the owner signing in ([developer guide](development.md#update-and-smoke-tests-on-an-emulator)). Ran on 2026-11-20 with the build of step 40u: every check of the update passed, the smoke test 10 of 10 ([threat model 8.2](threat-model.md#82-manual-on-the-android-emulator), item 13); to run again with the release candidate.
- [ ] **The owner's sign-off** in [section 8.4](threat-model.md#84-sign-off): the residual risks of section 7 accepted or reopened, and the questions that R19, R21, R33 and R36 leave to the owner answered (R17 is accepted for the beta, owner 2026-11-12). Section 8.3 waits for the device test; the row says so.

### 9. Cutting beta.1

[releasing.md](releasing.md#cutting-a-release): `app/pubspec.yaml` already has `1.0.0-beta.1+1`; check Cronet, run both dry runs ([Android](releasing.md#the-dry-run), [iOS](releasing.md#the-ios-dry-run)), wait for the green CI run on `main`, tag `v1.0.0-beta.1` and push the tag. German must be complete first, as for every `x.y.0` and its betas: among the English texts it still lacks is `followInheritedFixed` of step 40u, which comes through Crowdin like every other ([D88]). The tag also starts the workflow "Contract matrix" ([D28](decisions.md#d28-contract-tests-against-the-latest-vikunja-release-only)): before the approval, every release in it is green, or each failure is recorded in D28 and the owner accepts it. A second maintainer approves the job `publish` of the tag's release run, which uploads the bundle to Play's `beta` track, the APK to dl.vikunja.io and the GitHub release. Then check all three, and build and upload the iOS build from the Mac ([releasing.md](releasing.md#each-testflight-build)).

## The beta on Google Play

`io.vikunja.app` is in production in Vikunja's account, so the closed test that a new personal account needs before production, at least 12 testers opted in for 14 days in a row ([testing requirements][play-testing-14]), does not apply, and there is no production application ([D89]). Each beta goes to the track `beta`, Play's open testing, which the release workflow uploads to ([D86](decisions.md#d86-ci-and-releases-on-github-actions)). [store-listing.md](store-listing.md#testing-and-production) has the track's settings.

1. **Before the first upload:** the listing, its screenshots and every App content form, Data safety included, as [part 4](#4-the-play-app) says: Play counts the open track like production ([testing tracks][play-tracks]).
2. **Internal testing first (optional):** an internal test can take a build before the open track, for the maintainers' own devices.
3. **The track:** anyone can join, without a list; the feedback channel is the address for the testers, `hello@vikunja.io` until kolaente has set it up, which the opt-in page shows; countries as for production. The bundle of `v1.0.0-beta.1` comes from the release run ([part 9](#9-cutting-beta1)). Allow some days before it is available: Google may review the release first.
4. **The opt-in link,** `https://play.google.com/apps/testing/io.vikunja.app`. Then send [the invitation](#the-invitation).
5. **The old app's testers:** whoever joined the old app's beta on the same track may still be opted in, and then gets beta.1 as an update over the old app, which is the update path of step 38b ([D85](decisions.md#d85-update-from-the-old-app-server-prefill-one-session-try-leftovers-cleared-widgets-kept)) on real devices. [uncertain: whether the track has testers; the Play Console shows it]
6. **The production release** of 1.0.0 is the release run's staged rollout ([cutting 1.0.0](#cutting-100)); Google may review it first (up to 7 days).

## TestFlight

[releasing.md](releasing.md#each-testflight-build) covers the build and its upload; [store-listing.md](store-listing.md#app-store-connect) the test information.

- **Internal testers** (up to 100 users of the App Store Connect team, the owner among them) install a build as soon as it is processed, without a review ([TestFlight overview][tf-overview]).
- **External testers** come through a group with a public link: set the link's criteria (iPhone and iPad, iOS 15 or later) and a tester limit, for example 100, raised when needed ([external testers][tf-external]).
- **Beta App Review** checks the first build of each version that goes to external testers; later builds of the same version might not need a full review, only one build of a version can be in review at a time, and at most six builds go to review in 24 hours. Every 1.0.0 beta has the iOS version 1.0.0, so beta.1 is the one that waits.
- **Test information** ([test information][tf-info]): the beta app description and feedback email of [store-listing.md](store-listing.md#app-store-connect); for Beta App Review the contact (name, phone, email), sign-in required with `demo` and `demo` in the sign-in fields, never in the notes, and `fastlane/metadata/review_information/notes.txt` as the notes.
- **What to Test** for each build, in the dialog that opens when the build is added to the external group, in English and German ([beta.1's](#what-to-test-for-beta1)).
- **Builds expire after 90 days;** a beta that runs longer needs a new build before then.

## Texts for testers

The feedback address in these texts is the one kolaente sets up for the testers, which reaches the app's maintainers; until it exists, it is `hello@vikunja.io` ([D89]).

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

- **Where reports land:** the inbox of the feedback address, `hello@vikunja.io` until kolaente has set up the testers' address (also the replies to TestFlight's invitations and the address on Play's opt-in page); Play's private feedback from testers in the Play Console [uncertain: where the Console lists it]; TestFlight's feedback with screenshots and its crash reports in App Store Connect under TestFlight; the issues of go-vikunja/app, through its bug and feature forms. A security problem goes privately to security@vikunja.io or through GitHub's private vulnerability reporting, never into a public issue ([SECURITY.md](../SECURITY.md), [D87]).
- **The beta log:** for each report its date, channel, platform and version, what happened, and the fix with its beta.N, without testers' names or addresses. It goes into the 37d decision.
- **Each fix ships as the next `v1.0.0-beta.N`,** never as a moved tag ([releasing.md](releasing.md#cutting-a-release)): a commit on `main` with its green CI, then the tag, whose release run uploads the bundle to Play's `beta` track once a second maintainer approves it. Its What's new on Play is the committed `fastlane/metadata/android/<language>/changelogs/<versionCode>.txt`, written in the release commit ([D90](decisions.md#d90-fixes-from-the-code-review-before-beta1)); the iOS build goes to TestFlight with its What to Test.
- **Crash data** comes from Play vitals, TestFlight's crash reports and, from the testers who allow them, the app's own crash reports in Vikunja's Sentry ([D113](decisions.md#d113-opt-in-crash-reports-through-vikunjas-sentry)), in the old app's project, once the owner has set its key ([part 1](#1-the-repository-and-ci)); a build without the key has none. Release builds print nothing. A tester's report can carry the support details ([D20](decisions.md#d20-scope-cuts-and-mobile-forms-of-desktop-features)): the versions, the background state, the queue's counts and failure kinds and the last session end, never a log.
- **The privacy section on vikunja.io** describes the testers, the stores' statistics and the downloads before any of them existed: read those statements again once the beta has started ([vikunja-io-drafts.md](vikunja-io-drafts.md), below).

## Before 1.0.0

### The iOS device test

The list gathers [D74]'s known gaps, section [8.3](threat-model.md#83-final-ios-phase) of the threat model and the device notes of D71 and D75. It runs on the owner's iPhone or iPad with Xcode 27.2 (27B52; D74's simulator checks used 27.1), and the results go into the 37d decision.

- [ ] The first signed build and its TestFlight upload: App Store Connect's processing passes, the real test of the privacy manifests and the required-reason APIs.
- [ ] Whether a release build needs `DEAD_CODE_STRIPPING=NO` for the lock-screen widgets.
- [ ] The sensitive clipboard (8.3 #3): a new API token and a share link copy, do not reach a Mac through Universal Clipboard, and the pasteboard is empty after two minutes.
- [ ] Widget links and notification taps (8.3 #4, #5): rows carry the key, another account's widget row and notification switch accounts, the same link from Safari or Notes does not.
- [ ] Widgets (8.3 #6): rows, titles and their VoiceOver labels redacted on the Lock Screen and in StandBy; Done from a widget asks for the unlock; the setup fields, the project picker per account, placed widgets, "+N more".
- [ ] Widgets after midnight and Done (step 40t): with the app closed and no background run, after midnight the rows show dates instead of Today or Tomorrow, VoiceOver reads them, VoiceOver says Overdue for a row shown overdue, and the medium and larger widgets show "Open Vikunja to update". Done on a widget row takes away the task's pending reminder and one already shown in Notification Center at once, before the app runs (the extension reaches the app's notifications); a Snooze on another task's notification does not bring them back. If the extension cannot reach them, record it as a limit in D63.
- [ ] The app lock (8.3 #7): the passcode fallback, the lockout, Done in a locked notification (`task_locked`) asks for the unlock.
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
- [ ] [D75]'s iOS parts: the help button, the new-task sheet above the home indicator, the Cupertino Theme control on the Account tab, the project folder in light, dark and tinted rendering.
- [ ] [D71]'s App language row: the Language entry in Settings with one and with two preferred languages.
- [ ] The About page's "Help and bug reports" row opens the help page on vikunja.io.
- [ ] The support details ([threat model 8.3](threat-model.md#83-final-ios-phase) #13): the Runner builds with the device channel's `backgroundState`, the page's Background App Refresh and Low Power Mode lines follow the settings, and Share opens the share sheet from its button on an iPad.
- [ ] iOS 15 to 17.3 (8.3 #10): the sign-in fallback below iOS 17.4 and the system SQLite on iOS 15, if a device is at hand. Otherwise the owner decides: accept it untested, borrow a device (Xcode 27 is reported to debug only on iOS 17 or later, so such a device may take TestFlight builds only [unverified]), or raise the minimum.

### The rest, in any order

- [ ] **TalkBack and VoiceOver:** the manual passes of [accessibility-checklist.md](accessibility-checklist.md#2-manual-on-android) ([Q19](open-questions.md#q19-device-setup-for-the-manual-talkback-pass)); TalkBack and Switch Access need the owner at the controls and run in the device phase with VoiceOver (owner, 2026-11-20); the Accessibility Scanner is not used (owner, 2026-11-20 and 2026-11-21; [D112](decisions.md#d112-accessibility-pass-on-an-emulator-a-scan-of-the-real-screens-48-dp-chips-and-widget-targets)).
- [ ] **The threat model again** for 1.0.0 ([section 9](threat-model.md#9-review-cadence)): 8.1 on the tree to be released, 8.2 again for what changed since the beta's sign-off, 8.3 from the device test above, and a new row in [section 8.4](threat-model.md#84-sign-off).
- [ ] **The public demo:** ask the Vikunja maintainers whether the testers and the stores' reviewers may use try.vikunja.io with the demo account (the review notes ask the reviewers not to delete it) and whether there are times it should not be used ([D76]), or whether the reviewers can have an account of their own on a server that is not reset (code review of 2026-11-17).
- [ ] **The written offer's wording** for desugar_jdk_libs, which kolaente confirms, as the Vikunja project makes it since step 38f ([D89]; the text is in `app/assets/legal/android.md`).
- [ ] **The privacy section's open points** ([vikunja-io-drafts.md](vikunja-io-drafts.md)): Vikunja Cloud's terms, the legal bases and periods that kolaente checks, what App Store Connect shows of the testers, and the statements about the stores' statistics and the testers, read again once the beta has started.
- [ ] **US export:** no annual self-classification report is due. Since BIS's rule of 29 March 2021 ([86 FR 16482][bis-rule]) the report covers only mass-market components and executable software ([15 CFR 740.17(e)(3)][cfr-740-17]), not an end-user app with standard encryption only ([releasing.md](releasing.md#export-compliance)).
- [ ] **France ([Q23](open-questions.md#q23-french-encryption-declaration-for-the-app-store), open):** Apple's [export compliance table][apple-export] asks for a French encryption declaration for an industry-standard algorithm that the operating system does not provide, and the app's `dart:io` TLS uses BoringSSL from the Flutter engine. The choices: file the declaration with the ANSSI, find an exemption that covers it, or leave France out of the App Store's availability. Settle it before the App Store submission.
- [ ] **Steps 18 and 19,** the widgets, still in review: the owner accepts them after the device test.
- [ ] **Accessibility Nutrition Labels** stay blank in App Store Connect unless the passes above confirm a feature ([store-listing.md](store-listing.md#app-store-connect)).
- [ ] **The App Store's screenshots** and `python3 -I tool/check_store_metadata.py --strict` before the submission ([store-listing.md](store-listing.md#screenshots)).

## Cutting 1.0.0

Once everything [before 1.0.0](#before-100) is done (the app is in production on Play already, so no production access is applied for):

1. **The release** as [releasing.md](releasing.md#cutting-a-release) says: `app/pubspec.yaml` to `version: 1.0.0+1`, Cronet checked, both dry runs, a green CI run, the tag `v1.0.0` (version code and iOS build 1000099), the approval, the GitHub release and dl.vikunja.io checked.
2. **Google Play:** the release run uploads the bundle to production as a staged rollout, to the share `VIKUNJA_APP_PLAY_ROLLOUT` (0.1 when unset); raise or complete it in the Play Console as [the rollout](releasing.md#the-rollout) says, with its abort thresholds. Google may review the production release first (up to 7 days).
3. **The App Store:** upload the build from the Mac ([releasing.md](releasing.md#each-testflight-build)); in App Store Connect add it to version 1.0.0 with the version's texts and screenshots, the App Review information (the sign-in information in its fields, the notes, the maintainers' answer if Apple asks for it) and France as [Q23](open-questions.md#q23-french-encryption-declaration-for-the-app-store) decides, choose the 7-day phased release ([the rollout](releasing.md#the-rollout)), then submit it for review. Once 1.0.0 is released it takes no more builds; fixes go into 1.0.1.
4. **Afterwards:** the store links and the GitHub release in the README and on the help page on vikunja.io (kolaente publishes it), the 37d decision completed, and step 37d closed in the roadmap.

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
[crowdin-cli-sources]: https://crowdin.github.io/crowdin-cli/commands/crowdin-upload-sources
[crowdin-cli-translations]: https://crowdin.github.io/crowdin-cli/commands/crowdin-upload-translations
[crowdin-config]: https://support.crowdin.com/developer/configuration-file/
[crowdin-github]: https://support.crowdin.com/github-integration/

- Google Play and Android: [Play App Signing][play-app-signing], [developer verification][android-verification], [device verification for new personal accounts][play-device], [testing requirements for new personal accounts][play-testing-14], [testing tracks][play-tracks]
- Apple: [TestFlight overview][tf-overview], [external testers][tf-external], [test information][tf-info], [complete review][apple-complete-review], [export compliance documentation][apple-export]
- US export: [86 FR 16482][bis-rule], [15 CFR 740.17][cfr-740-17]
- Vikunja: [contact][vikunja-contact]
- GitHub, read on 2026-11-16 for [the move](#the-move): [forks and their network][gh-forks], [repository limits][gh-limits]
- Crowdin, read on 2026-11-16 for [the translations on Crowdin](#the-translations-on-crowdin): [the CLI's source upload][crowdin-cli-sources] and [translation upload][crowdin-cli-translations], [the configuration file][crowdin-config], [the GitHub integration][crowdin-github]

[D67]: decisions.md#d67-agpl-30-or-later-with-an-app-store-permission-dco-reserved-brand-embedded-cronet
[D71]: decisions.md#d71-english-and-german-us-base-glossary-error-texts-live-language-changes
[D74]: decisions.md#d74-ios-phase-app-store-prerequisites-testflight-from-the-mac-photo-locations-capture-cover
[D75]: decisions.md#d75-owners-ui-review-no-task-identifier-coloured-folders-new-task-sheet-account-tab
[D76]: decisions.md#d76-store-listings-and-policies-the-apps-pages-photo-locations-removed-on-android
[D77]: decisions.md#d77-beta-preparation-new-app-id-own-signing-key-public-group-testers
[D87]: decisions.md#d87-mit-vikunjas-contribution-rules-and-the-move-into-go-vikunjaapp
[D88]: decisions.md#d88-translations-through-vikunjas-crowdin-project
[D89]: decisions.md#d89-store-listing-and-web-pages-of-the-official-app

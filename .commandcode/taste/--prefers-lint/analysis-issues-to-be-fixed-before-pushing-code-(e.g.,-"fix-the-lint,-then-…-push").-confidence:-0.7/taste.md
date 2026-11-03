# - Prefers lint/analysis issues to be fixed before pushing code (e.g., "fix the lint, then … push"). Confidence: 0.7
- Prefers lint/analysis issues to be fixed before pushing code (e.g., "fix the lint, then … push"). Confidence: 0.7
- Prefers using the GitHub CLI (`gh`) for GitHub interactions (e.g., PR checkout, pushing) over raw git commands. Confidence: 0.7
- Prefers supporting only the current (newest) API format; no legacy fallbacks for pre-1.0 API fields. Api versioning will be used for future changes. Confidence: 0.9
- Does not want CommandCode bot attribution (e.g., "Co-authored-by: CommandCodeBot") in git commits. Confidence: 0.7
- When the Flutter app behaves differently from the web app, prefers comparing with the web frontend source to identify discrepancies before debugging. Confidence: 0.6
- Prefers pushing changes to both Gitea (`gitea`) and GitHub (`origin`) remotes to keep mirrors in sync, including merging feature branches into `gitea/main`. Confidence: 0.85
- Prefers bumping `pubspec.yaml` version (build number, e.g., `0.1.9-beta+2` -> `+3`) when pushing fixes to trigger Gitea Actions recompilation / F-Droid deployment (`Build APK` + `Build & Deploy to F-Droid` on push to `main`). Confidence: 0.85

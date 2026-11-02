# Website

Rurana's website ([D76](../docs/decisions.md)): a language chooser and, in English and German, the home page, the privacy policy, the legal notice (Impressum), support and account deletion. The German privacy policy and Impressum are binding; the English pages translate them. GitLab Pages publishes it from the default branch (the job `pages` in `.gitlab-ci.yml`).

## The owner's values: `site.json`

One file holds what the website, the store listings and the release builds need. Nothing in the repository invents them; they stay empty until the owner fills them in.

| Key | What | Example of the form |
|---|---|---|
| `site_url` | The website's address: https, no trailing slash | `https://rurana.example` |
| `contact_email` | The public contact address (support, privacy, legal notice) | `contact@rurana.example` |
| `legal_name` | The publisher's full legal name | |
| `address_lines` | The postal address for service, one line per entry, at least two (a c/o service with authority to accept service is fine; a P.O. box is not) | `["c/o …", "Street 1", "12345 Town"]` |
| `country` | The country, shown as written on both language versions | |

`links.json` holds the optional links of the home and support pages (`source_code_url`, the GitLab project without a trailing slash, from which the releases and issues links follow; `google_play_url`; `app_store_url`). An empty one shows as "coming soon".

## Building

```sh
python3 -I tool/build_site.py --preview       # build/site-preview/, missing values marked
python3 -I tool/build_site.py --check         # builds into a temporary folder and checks; refuses while site.json lacks a value
python3 -I tool/build_site.py                 # public/, as the Pages job builds it; refuses the same way
```

Every build checks its output: each page in both languages with the same anchors, a link to the other language, the privacy policy and the legal notice on every page, internal links and anchors that resolve, no script and nothing loaded from another server. The tests are in `tool/ci/test_build_site.py`.

## Editing the pages

- `pages/<en|de>/<page>.html`: a front matter (`title`, `nav`, `description`, and `updated` for a dated text) and the page's body. `{{name}}` inserts a value: `legal_name`, `contact_email`, `contact_email_link`, `address`, `country`, `site_host`, `updated`, `downloads`, `source_code`, `issues`.
- `templates/`: the page frame and the language chooser; `strings.json`: the frame's texts in both languages; `style.css`: the one stylesheet (light and dark from the system setting).
- Change English and German together, with the same section anchors. A changed privacy policy gets a new `updated` date in both files.
- Links between pages are relative, so the site works on the custom domain and under a GitLab path alike.

## Publishing (owner)

1. Fill in `site.json`, then run `python3 -I tool/build_site.py --check`, `python3 -I tool/check_store_metadata.py --fill` and `python3 -I tool/build_android_notices.py`: the written offer in `app/assets/legal/android.md` names `contact_email`, and the `checks` job fails while that file is stale. Commit `site.json`, the filled store metadata and `android.md` together and push to the default branch; the job `pages` publishes `public/`.
2. In GitLab, Deploy › Pages: add the custom domain, create the DNS records GitLab shows (the verification TXT record and the address records) and keep "Force HTTPS" with the automatic Let's Encrypt certificate.
3. Check that the Pages access control is off or set to everyone, so the policy is public.

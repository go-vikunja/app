/// Where the app's source code is published (AGPL section 6). The release
/// job builds with `--dart-define=SOURCE_CODE_URL=$CI_PROJECT_URL`; other
/// builds have none (D73).
const String? sourceCodeUrl = _sourceCodeUrl == '' ? null : _sourceCodeUrl;
const _sourceCodeUrl = String.fromEnvironment('SOURCE_CODE_URL');

/// Rurana's website with its privacy policy and legal notice. The release
/// scripts build with `--dart-define=SITE_URL=` and the `site_url` of
/// `site/site.json`; other builds have none (D76).
const String? siteUrl = _siteUrl == '' ? null : _siteUrl;
const _siteUrl = String.fromEnvironment('SITE_URL');

enum SitePage { privacy, legal }

/// The website has only English and German pages: German for an app in
/// German, else English.
Uri sitePageUri(String site, SitePage page, {required String languageCode}) {
  final base = site.endsWith('/') ? site.substring(0, site.length - 1) : site;
  final language = languageCode == 'de' ? 'de' : 'en';
  return Uri.parse('$base/$language/${page.name}/');
}

const copyrightNotice =
    'Copyright (C) 2026 Benedikt Lesch and the Rurana contributors';

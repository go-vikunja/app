/// Where the app's source code is published (AGPL section 6). The release
/// job builds with `--dart-define=SOURCE_CODE_URL=$CI_PROJECT_URL`; other
/// builds have none (D73).
const String? sourceCodeUrl = _sourceCodeUrl == '' ? null : _sourceCodeUrl;
const _sourceCodeUrl = String.fromEnvironment('SOURCE_CODE_URL');

/// Rurana's pages on the owner's website (D76). Each holds English and
/// German; an app in German opens the German part, every other language the
/// English one.
enum WebsitePage {
  privacy(
    'https://coderoftime.dev/rurana/privacy/',
    'https://coderoftime.dev/rurana/privacy/#de',
  ),
  legalNotice(
    'https://coderoftime.dev/impressum/#en',
    'https://coderoftime.dev/impressum/#de',
  );

  new(this.english, this.german);

  final String english;
  final String german;

  Uri uri({required String languageCode}) =>
      Uri.parse(languageCode == 'de' ? german : english);
}

const copyrightNotice =
    'Copyright (C) 2026 Benedikt Lesch and the Rurana contributors';

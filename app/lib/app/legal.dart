/// Where the app's source code is published: the release build passes
/// `--dart-define=SOURCE_CODE_URL=<the repository's tree at the tag>`
/// (tool/ci/release_build.sh, D86); other builds have none.
const String? sourceCodeUrl = _sourceCodeUrl == '' ? null : _sourceCodeUrl;
const _sourceCodeUrl = String.fromEnvironment('SOURCE_CODE_URL');

/// The app's pages on the owner's website (D76, D77), each in English and
/// German; an app in German opens the German one, every other language the
/// English one.
enum WebsitePage {
  support(
    'https://coderoftime.dev/rurana/support/',
    'https://coderoftime.dev/de/rurana/support/',
  ),
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

const copyrightNotice = 'Copyright (c) Vikunja and contributors';

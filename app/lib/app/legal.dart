/// Where the app's source code is published: the release build passes
/// `--dart-define=SOURCE_CODE_URL=<the repository's tree at the tag>`
/// (tool/ci/release_build.sh); other builds have none
/// (decision log: Identity and scope).
const String? sourceCodeUrl = _sourceCodeUrl == '' ? null : _sourceCodeUrl;
const _sourceCodeUrl = String.fromEnvironment('SOURCE_CODE_URL');

/// The app's pages on vikunja.io. The site is in English only, so every
/// language opens the same page.
enum WebsitePage {
  support('https://vikunja.io/help/mobile'),
  privacy('https://vikunja.io/privacy/#mobile-app'),
  legalNotice('https://vikunja.io/imprint/');

  new(this.address);

  final String address;

  Uri get uri => Uri.parse(address);
}

const copyrightNotice = 'Copyright (c) Vikunja and contributors';

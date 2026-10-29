/// Where the app's source code is published (AGPL section 6). The release
/// job builds with `--dart-define=SOURCE_CODE_URL=$CI_PROJECT_URL`; other
/// builds have none (D73).
const String? sourceCodeUrl = _sourceCodeUrl == '' ? null : _sourceCodeUrl;
const _sourceCodeUrl = String.fromEnvironment('SOURCE_CODE_URL');

const copyrightNotice =
    'Copyright (C) 2026 Benedikt Lesch and the Rurana contributors';

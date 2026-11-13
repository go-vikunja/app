import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The shipped sources, relative to the app package, where tests run.
List<String> _dartRoots() => [
  'lib',
  ..._inEach('packages', 'lib'),
  ..._inEach('plugins', 'lib'),
];
List<String> _kotlinRoots() => [
  'android/app/src/main/kotlin',
  ..._inEach('plugins', 'android/src/main'),
];
List<String> _swiftRoots() => [
  'ios/Runner',
  'ios/VikunjaWidgets',
  ..._inEach('plugins', 'ios'),
];

List<String> _inEach(String parent, String child) => [
  for (final entity in Directory('../$parent').listSync())
    if (entity is Directory) '${entity.path}/$child',
];

const _logLevels = 'finest|finer|fine|config|info|warning|severe|shout|log';

/// Allowed findings, by rule and path suffix, each with its reason.
const _allowed = <String, Map<String, String>>{
  'console': {
    'lib/bootstrap/logging_setup.dart':
        'The debug console sink: prints only redacted records, release '
        'builds install none.',
  },
};

/// Interpolations the log-call rule flags that are allowed, by path suffix
/// and expression, each with its reason.
const _allowedInterpolations = <(String, String), String>{
  ('lib/core/realtime/realtime_connection.dart', 'code'):
      "The realtime server's error code (invalid_token and such), no "
      'secret of the app.',
};

final _consolePrint = RegExp(
  r'\bprint\(|\bdebugPrint\(|\bdebugPrintStack\(|\bstdout\.|\bstderr\.|'
  r'''import\s+['"]dart:developer['"]''',
);
// Dio's LogInterceptor logs headers and bodies; drift and go_router log
// statements and locations.
final _verboseLogging = RegExp(
  r'\bLogInterceptor\(|logStatements:\s*true|debugLogDiagnostics:\s*true',
);
final _dartLogCall = RegExp(
  r'(?:\b_?\w*[Ll]og(?:ger)?|Logger\([^)]*\)|Logger\.root)'
  '\\.(?:$_logLevels)\\(',
);
// The OAuth code, PKCE verifier and state, a TOTP passcode and access-header
// values (A4, A5) are bare values that redaction cannot recognise.
final _sensitiveName = RegExp(
  'token|jwt|refresh|password|secret|hash|bearer|authori[sz]ation|cookie|'
  'title|email|description|html|body|payload|text|link|uri|url|key|'
  'code|verifier|state|passcode|otp|header',
  caseSensitive: false,
);
// Usernames and display names (Account, User, UserProfile) and a task's
// text before it is sent (ParsedTaskText, IndentedLine).
final _personalName = RegExp(
  r'^(\w*(account|user|profile)|parsed\w*|indented\w*|lines?)$',
  caseSensitive: false,
);
// A sensitive name stays sensitive whatever its ending (authorizationCode,
// inviteCode); only these hold a number.
const _harmlessNames = {'statusCode', 'errorCode'};
final _harmlessEnding = RegExp(
  r'(\?|!)?\.(runtimeType|length|name|wireName|id|statusCode|errorCode|'
  r'host|inMilliseconds|inSeconds|isEmpty|isNotEmpty)$',
);
// A failure's code, but not the code of a sign-in response.
final _codeEnding = RegExp(r'(\?|!)?\.code$');
const _redactingCalls = ['redactSecrets(', 'describeUriForLog('];
const _secretFields =
    'token|accessToken|refreshToken|hash|password|jwt|secret|linkKey';
final _secretInToString = RegExp(
  '\\\$(?:\\{\\s*)?(?:this\\.)?($_secretFields)\\b(?!\\??\\.)',
);
final _contentInToString = RegExp(
  r'\$(?:\{\s*)?(title|name|description|fileName|text)\b(?!\.length|\.is)',
);
// Usernames are personal data, not secrets; the logs never interpolate the
// types (see the log-call rule).
const _domainTypesWithUsernames = {'Account', 'User', 'UserProfile'};
final _kotlinLogCall = RegExp(r'\bLog\.(?:v|d|i|w|e|wtf)\(');
final _kotlinPrint = RegExp(
  r'\bprintln\(|\bprint\(|System\.(?:out|err)|\.printStackTrace\(',
);
final _kotlinHarmlessTemplate = RegExp(
  r'^(?:\w+\.javaClass\.simpleName|call\.method)$',
);
final _swiftLog = RegExp(
  r'\bprint\(|\bdebugPrint\(|\bdump\(|\bNSLog\(|\bos_log\(|\bLogger\(|'
  r'\bos_signpost\(',
);

final class _Source {
  new(this.path, this.text);

  factory read(File file) =>
      _Source(file.path.replaceAll(r'\', '/'), file.readAsStringSync());

  final String path;
  final String text;

  int lineAt(int offset) =>
      '\n'.allMatches(text.substring(0, offset)).length + 1;

  String finding(int offset, String what) => '$path:${lineAt(offset)}: $what';
}

List<_Source> _sources(List<String> roots, String extension) => [
  for (final root in roots)
    if (Directory(root).existsSync())
      for (final entity in Directory(root).listSync(recursive: true))
        if (entity is File &&
            entity.path.endsWith(extension) &&
            !entity.path.contains('/.build/'))
          _Source.read(entity),
];

/// The offset just after the bracket that closes the one at [open], skipping
/// string literals, their interpolations and line comments.
int _closing(String text, int open) {
  final closers = <String>[];
  var i = open;
  while (i < text.length) {
    final char = text[i];
    switch (char) {
      case '(' || '[' || '{':
        closers.add(const {'(': ')', '[': ']', '{': '}'}[char]!);
        i++;
      case ')' || ']' || '}':
        if (closers.isNotEmpty) closers.removeLast();
        i++;
        if (closers.isEmpty) return i;
      case "'" || '"':
        i = _afterString(text, i);
      case '/' when text.startsWith('//', i):
        final end = text.indexOf('\n', i);
        i = end < 0 ? text.length : end;
      default:
        i++;
    }
  }
  return text.length;
}

int _afterString(String text, int start) {
  final raw = start > 0 && text[start - 1] == 'r';
  final quote = text[start];
  final delimiter = text.startsWith(quote * 3, start) ? quote * 3 : quote;
  var i = start + delimiter.length;
  while (i < text.length) {
    if (!raw && text[i] == r'\') {
      i += 2;
    } else if (text.startsWith(delimiter, i)) {
      return i + delimiter.length;
    } else if (!raw && text.startsWith(r'${', i)) {
      i = _closing(text, i + 1);
    } else if (delimiter.length == 1 && text[i] == '\n') {
      return i;
    } else {
      i++;
    }
  }
  return i;
}

/// What [call] interpolates: `${…}` contents and `$name`s.
List<String> _interpolations(String call) {
  final found = <String>[];
  var i = 0;
  while (i < call.length) {
    if (call.startsWith(r'${', i)) {
      final end = _closing(call, i + 1);
      found.add(call.substring(i + 2, end - 1).trim());
      i = end;
    } else if (call[i] == r'$' &&
        RegExp('[A-Za-z_]').matchAsPrefix(call, i + 1) != null) {
      final name = RegExp(r'\w+').matchAsPrefix(call, i + 1)!;
      found.add(name[0]!);
      i = name.end;
    } else {
      i++;
    }
  }
  return found;
}

bool _isComment(_Source source, int offset) {
  final lineStart = source.text.lastIndexOf('\n', offset) + 1;
  final before = source.text.substring(lineStart, offset).trimLeft();
  return before.startsWith('//') || before.startsWith('*');
}

bool _logsSafely(String expression) {
  if (_redactingCalls.any(expression.startsWith)) return true;
  final code = _codeEnding.firstMatch(expression);
  if (code != null) return _logsSafely(expression.substring(0, code.start));
  final names = [
    for (final match in RegExp(r'[A-Za-z_]\w*').allMatches(expression))
      match[0]!,
  ];
  final personal = names.any(_personalName.hasMatch);
  if (_harmlessEnding.hasMatch(expression) &&
      !(personal && expression.endsWith('name'))) {
    return true;
  }
  return !names.any(
    (name) =>
        _personalName.hasMatch(name) ||
        (_sensitiveName.hasMatch(name) && !_harmlessNames.contains(name)),
  );
}

List<String> _consoleOutput(Iterable<_Source> sources) => [
  for (final source in sources)
    for (final match in _consolePrint.allMatches(source.text))
      if (!_isComment(source, match.start))
        source.finding(match.start, match[0]!),
];

List<String> _verboseLoggers(Iterable<_Source> sources) => [
  for (final source in sources)
    for (final match in _verboseLogging.allMatches(source.text))
      if (!_isComment(source, match.start))
        source.finding(match.start, match[0]!),
];

List<String> _unsafeLogInterpolations(Iterable<_Source> sources) => [
  for (final source in sources)
    for (final match in _dartLogCall.allMatches(source.text))
      if (!_isComment(source, match.start))
        for (final expression in _interpolations(
          source.text.substring(
            match.end,
            _closing(source.text, match.end - 1),
          ),
        ))
          if (!_logsSafely(expression) &&
              !_allowedInterpolations.keys.any(
                (allowed) =>
                    source.path.endsWith(allowed.$1) &&
                    expression == allowed.$2,
              ))
            source.finding(match.start, 'logs \$$expression'),
];

/// The `toString` overrides of [source]: the class they are in, the offset
/// and the body.
Iterable<(String, int, String)> _toStrings(_Source source) sync* {
  final owners = RegExp(r'\b(?:class|enum|mixin|extension(?:\s+type)?)\s+(\w+)')
      .allMatches(source.text)
      .toList();
  for (final match in RegExp(
    r'String\s+toString\(\)\s*(=>|\{)',
  ).allMatches(source.text)) {
    final body = match[1] == '{'
        ? source.text.substring(
            match.end - 1,
            _closing(source.text, match.end - 1),
          )
        : source.text.substring(
            match.end,
            _endOfExpression(source.text, match.end),
          );
    final owner = owners.where((o) => o.start < match.start).lastOrNull;
    yield (owner?[1] ?? '?', match.start, body);
  }
}

int _endOfExpression(String text, int start) {
  var i = start;
  while (i < text.length && text[i] != ';') {
    i = switch (text[i]) {
      '(' || '[' || '{' => _closing(text, i),
      "'" || '"' => _afterString(text, i),
      _ => i + 1,
    };
  }
  return i;
}

List<String> _secretsInToString(Iterable<_Source> sources) => [
  for (final source in sources)
    for (final (owner, offset, body) in _toStrings(source))
      for (final match in _secretInToString.allMatches(body))
        source.finding(offset, '$owner.toString prints ${match[1]}'),
];

List<String> _contentInDomainToString(Iterable<_Source> sources) => [
  for (final source in sources)
    if (source.path.contains('packages/vikunja_domain/lib/'))
      for (final (owner, offset, body) in _toStrings(source))
        if (!_domainTypesWithUsernames.contains(owner))
          for (final match in _contentInToString.allMatches(body))
            source.finding(offset, '$owner.toString prints ${match[1]}'),
];

List<String> _kotlinLogs(Iterable<_Source> sources) => [
  for (final source in sources) ...[
    for (final match in _kotlinPrint.allMatches(source.text))
      if (!_isComment(source, match.start))
        source.finding(match.start, match[0]!),
    for (final match in _kotlinLogCall.allMatches(source.text))
      if (!_isComment(source, match.start))
        ..._kotlinLogFindings(
          source,
          match.start,
          source.text.substring(
            match.end,
            _closing(source.text, match.end - 1) - 1,
          ),
        ),
  ],
];

Iterable<String> _kotlinLogFindings(
  _Source source,
  int offset,
  String arguments,
) sync* {
  if (_topLevelArguments(arguments) > 2) {
    yield source.finding(offset, 'Log with a Throwable');
  }
  for (final template in _interpolations(arguments)) {
    if (!_kotlinHarmlessTemplate.hasMatch(template)) {
      yield source.finding(offset, 'Log of \$$template');
    }
  }
}

int _topLevelArguments(String arguments) {
  var count = arguments.trim().isEmpty ? 0 : 1;
  var i = 0;
  while (i < arguments.length) {
    switch (arguments[i]) {
      case '(' || '[' || '{':
        i = _closing(arguments, i);
      case "'" || '"':
        i = _afterString(arguments, i);
      case ',':
        if (arguments.substring(i + 1).trim().isNotEmpty) count++;
        i++;
      default:
        i++;
    }
  }
  return count;
}

List<String> _swiftLogs(Iterable<_Source> sources) => [
  for (final source in sources)
    for (final match in _swiftLog.allMatches(source.text))
      if (!_isComment(source, match.start))
        source.finding(match.start, match[0]!),
];

List<String> _notAllowed(String rule, List<String> findings) => [
  for (final finding in findings)
    if (!(_allowed[rule]?.keys.any(
          (path) => finding.split(':').first.endsWith(path),
        ) ??
        false))
      finding,
];

void main() {
  final dart = _sources(_dartRoots(), '.dart');
  final kotlin = _sources(_kotlinRoots(), '.kt');
  final swift = _sources(_swiftRoots(), '.swift');

  test('finds the sources and the log calls it checks', () {
    expect(
      dart.map((s) => s.path),
      contains('lib/bootstrap/logging_setup.dart'),
    );
    expect([
      for (final s in dart) ..._dartLogCall.allMatches(s.text),
    ], hasLength(greaterThan(300)));
    expect([
      for (final s in kotlin) ..._kotlinLogCall.allMatches(s.text),
    ], hasLength(greaterThanOrEqualTo(3)));
    expect(
      dart.map((s) => s.path),
      contains(endsWith('packages/vikunja_domain/lib/src/task/task.dart')),
    );
    expect(
      kotlin.map((s) => s.path),
      containsAll([
        endsWith('widgets/MarkDoneAction.kt'),
        endsWith('vikunja_widgets/VikunjaWidgetsPlugin.kt'),
      ]),
    );
    expect(
      swift.map((s) => s.path),
      containsAll([
        'ios/Runner/AppDelegate.swift',
        endsWith('VikunjaWidgets/WidgetData.swift'),
        endsWith('vikunja_widgets/VikunjaWidgetsPlugin.swift'),
      ]),
    );
  });

  test('only the debug console sink prints', () {
    expect(_notAllowed('console', _consoleOutput(dart)), isEmpty);
  });

  test("nothing turns on a library's own logging of requests, statements "
      'or locations', () {
    expect(_verboseLoggers(dart), isEmpty);
  });

  test('log calls interpolate no secret, text, link or person unless '
      'redacted', () {
    expect(_unsafeLogInterpolations(dart), isEmpty);
  });

  test('no toString prints a secret field', () {
    expect(_secretsInToString(dart), isEmpty);
  });

  test("the domain's toStrings print no titles, names, descriptions, file "
      'names or text, except the usernames of accounts and users', () {
    expect(_contentInDomainToString(dart), isEmpty);
  });

  test('Kotlin logs only failure types and method names, without a '
      'Throwable', () {
    expect(_kotlinLogs(kotlin), isEmpty);
  });

  test('Swift does not log', () {
    expect(_swiftLogs(swift), isEmpty);
  });

  group('the rules catch', () {
    _Source sample(String path, String text) => _Source(path, text);

    test('prints and verbose loggers', () {
      final source = sample('lib/x.dart', '''
void f() {
  // print('in a comment');
  print('x');
  debugPrint('y');
  dio.interceptors.add(LogInterceptor(requestBody: true));
}
''');
      expect(_consoleOutput([source]), hasLength(2));
      expect(_verboseLoggers([source]), hasLength(1));
    });

    test('sign-in secrets and header values by name, whatever their '
        'ending', () {
      const flagged = [
        'authorizationCode',
        'code',
        'codeVerifier',
        'state',
        'passcode',
        'totpPasscode',
        'otp',
        'headers',
        'headerValue',
        'inviteCode',
        'authorization.code',
      ];
      const safe = [
        'taskId',
        'statusCode',
        'response.statusCode',
        'error.code',
        'title.length',
        'uri.host',
        'redactSecrets(code)',
      ];
      expect([
        for (final name in flagged)
          if (_logsSafely(name)) name,
      ], isEmpty);
      expect([
        for (final name in safe)
          if (!_logsSafely(name)) name,
      ], isEmpty);
    });

    test('unredacted log interpolations', () {
      final findings = _unsafeLogInterpolations([
        sample('lib/x.dart', r'''
void f() {
  _log.info('Signed in ${account.username} with $refreshToken');
  _log.warning(
    'Opening ${link.uri} failed: ${error.runtimeType}',
    error,
  );
  _log.fine('Task $taskId of ${user.name} (${title.length} characters)');
  _log.info('Request ${describeUriForLog(uri)}: ${redactSecrets('$e')}');
  _log.info('Parsed $parsed for ${entry.kind.name}');
}
'''),
      ]);
      expect(findings.map((f) => f.split(': ').last), [
        r'logs $account.username',
        r'logs $refreshToken',
        r'logs $link.uri',
        r'logs $user.name',
        r'logs $parsed',
      ]);
    });

    test('secrets and content in toString', () {
      final source = sample('../packages/vikunja_domain/lib/src/x.dart', r'''
final class Share {
  @override
  String toString() => 'Share($id, $hash, ${password.length})';
}
final class Note {
  @override
  String toString() {
    return 'Note($id, ${kind.name}, $title)';
  }
}
final class User {
  @override
  String toString() => 'User($id, $name)';
}
''');
      expect(_secretsInToString([source]), [
        endsWith('Share.toString prints hash'),
      ]);
      expect(_contentInDomainToString([source]), [
        endsWith('Note.toString prints title'),
      ]);
    });

    test('Kotlin logs with a Throwable or a value, and Swift logs', () {
      final kotlin = sample('A.kt', r'''
Log.w(TAG, "Could not queue: ${error.javaClass.simpleName}")
Log.w(TAG, "${call.method} failed")
Log.w(TAG, "Could not queue", error)
Log.i(TAG, "Opened $uri")
e.printStackTrace()
''');
      final swift = sample('A.swift', '''
// print("in a comment")
NSLog("%@", url)
print(error)
''');
      expect(_kotlinLogs([kotlin]), hasLength(3));
      expect(_swiftLogs([swift]), hasLength(2));
    });
  });
}

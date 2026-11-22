import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart' show DioException;

import 'package:drift/drift.dart' show InvalidDataException;
import 'package:flutter/services.dart' show PlatformException;
import 'package:sentry/sentry.dart';
import 'package:sqlite3/common.dart' show SqliteException;
import 'package:vikunja_domain/vikunja_domain.dart'
    show NetworkFailure, ServerConnectionFailure, VikunjaFailure;
import 'package:vikunja_mobile/core/logging/redaction.dart';

/// The category of the breadcrumbs the app's warnings become; every other
/// breadcrumb is dropped (decision log: Diagnostics).
const crashReportLogCategory = 'app.log';

const serverPlaceholder = '<server>';
const addressPlaceholder = '<address>';
const pathPlaceholder = '<path>';
const idPlaceholder = '<id>';
const _maxText = 1000;

final _urlAuthority = RegExp(
  r'''\b([a-z][a-z0-9+.-]*)://((?:[^/\s?#"'<>\[\]]|\[[^\]\s]*\])+)''',
  caseSensitive: false,
);
final _hostRules = <(RegExp, String Function(Match))>[
  (
    RegExp(r'\bfile://[^\s"\x27<>]*', caseSensitive: false),
    (_) => 'file://$pathPlaceholder',
  ),
  (
    _urlAuthority,
    (m) =>
        m[1]!.toLowerCase() == 'file' ? m[0]! : '${m[1]}://$serverPlaceholder',
  ),
  // dart:io's SocketException and HttpException.
  (
    RegExp(r"(host lookup:\s*')[^']*(')", caseSensitive: false),
    (m) => '${m[1]}$serverPlaceholder${m[2]}',
  ),
  (
    RegExp(r'\b(address\s*[=:]\s*)[^\s,;)]+', caseSensitive: false),
    (m) => '${m[1]}$addressPlaceholder',
  ),
  (
    RegExp(r'\b(host(?:name)?\s*[=:]\s*)[^\s,;)]+', caseSensitive: false),
    (m) => '${m[1]}$serverPlaceholder',
  ),
  (
    RegExp(r'(?<![\w.])\d{1,3}(?:\.\d{1,3}){3}(?![\w.])'),
    (_) => addressPlaceholder,
  ),
  // IPv6: a `::` or at least five groups, so that times stay.
  (
    RegExp(
      r'(?<![\w:])(?=[0-9A-Fa-f:]*::|(?:[0-9A-Fa-f]{1,4}:){4})'
      r'(?:[0-9A-Fa-f]{0,4}:){2,7}[0-9A-Fa-f]{0,4}(?![\w:])',
    ),
    (_) => addressPlaceholder,
  ),
  // A statement's text and values, wherever an SqliteException's text is
  // quoted, as drift's own exceptions do.
  (RegExp(r'(Causing statement)\b[\s\S]*$'), (m) => '${m[1]}: <statement>'),
  // A file's name is content; the folders name the device's user on a Mac.
  (
    RegExp(r"""(path\s*[=:]\s*)(?:'[^']*'|"[^"]*")""", caseSensitive: false),
    (m) => "${m[1]}'$pathPlaceholder'",
  ),
  (
    RegExp(
      r'(?<![\w./-])/(?:data|storage|sdcard|mnt|var|private|Users|Library|'
      r'System|Applications|tmp)/[^\s"\x27,;)\]}]*',
    ),
    (_) => pathPlaceholder,
  ),
  // An account's id (`accountIdFor`, 32 hex characters), stable per account
  // and shorter than the redaction's long runs, and any UUID; also next to
  // `_` or `-`, as in support_details.dart.
  (
    RegExp(
      '(?<![0-9A-Fa-f])(?:[0-9a-f]{32}|'
      '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})'
      '(?![0-9A-Fa-f])',
      caseSensitive: false,
    ),
    (_) => idPlaceholder,
  ),
];

/// [text] through the app's redaction (`redactSecrets`), without server
/// addresses, IP addresses, file paths and ids (32 hex characters, UUIDs),
/// at most 1,000 characters. [hosts] are the registered servers' hosts,
/// replaced wherever they appear.
String scrubCrashReportText(String text, {Iterable<String> hosts = const []}) {
  var result = redactSecrets(text);
  for (final (pattern, replacement) in _hostRules) {
    result = result.replaceAllMapped(pattern, replacement);
  }
  for (final host in hosts) {
    if (host.length < 3) continue;
    result = result.replaceAll(
      RegExp(RegExp.escape(host), caseSensitive: false),
      serverPlaceholder,
    );
  }
  return result.length > _maxText
      ? '${result.substring(0, _maxText)}…'
      : result;
}

/// What a report says about [error]: a text without data for the types
/// whose text quotes some (a JSON or URL source, a statement with its
/// values, a file path, an address, the server's message), an [Error]'s
/// own text without the strings it quotes, and only the type of anything
/// else, as an exception of the app or a library may quote content that
/// redaction cannot recognise (threat model, section 10, rule 1).
String? crashReportErrorText(Object? error) => switch (error) {
  null => null,
  NetworkFailure(:final problem) => 'NetworkFailure(${problem.name})',
  VikunjaFailure(:final code) =>
    code == null ? '${error.runtimeType}' : '${error.runtimeType}(code $code)',
  ServerConnectionFailure() => '${error.runtimeType}',
  FormatException(:final message, :final offset) =>
    offset == null
        ? 'FormatException: $message'
        : 'FormatException: $message (at offset $offset)',
  FileSystemException(:final message, :final osError) =>
    '${error.runtimeType}: $message${_osError(osError)}',
  SocketException(:final message, :final osError) =>
    'SocketException: $message${_osError(osError)}',
  TlsException(:final message, :final osError) =>
    '${error.runtimeType}: $message${_osError(osError)}',
  HttpException(:final message) => 'HttpException: $message',
  TimeoutException(:final duration) =>
    duration == null ? 'TimeoutException' : 'TimeoutException after $duration',
  DioException(:final type, :final response, error: final cause) =>
    'DioException [${type.name}]'
        '${response?.statusCode == null ? '' : ' ${response!.statusCode}'}'
        '${cause == null ? '' : ': ${crashReportErrorText(cause)}'}',
  SqliteException(
    :final extendedResultCode,
    :final message,
    :final explanation,
  ) =>
    explanation == null
        ? 'SqliteException($extendedResultCode): $message'
        : 'SqliteException($extendedResultCode): $message, $explanation',
  InvalidDataException() => 'InvalidDataException',
  PlatformException(:final code) => 'PlatformException($code)',
  Error() => withoutQuotedText(_textOf(error)),
  _ => '${error.runtimeType}',
};

String _osError(OSError? error) => error == null ? '' : ' ($error)';

String _textOf(Object error) {
  try {
    return '$error';
  } on Object {
    return '${error.runtimeType}';
  }
}

final _quotedText = RegExp(r'"(?:[^"\\\n]|\\.)*"');

/// [text] without the strings in double quotes, as Dart's errors quote
/// a value (`Invalid argument (name): "…"`); the single-quoted type names
/// stay.
String withoutQuotedText(String text) => text.replaceAll(_quotedText, '"…"');

/// The report as it leaves the device: every text through
/// [scrubCrashReportText]; no user, request or server name; of the contexts
/// only the device's model and system, the app's version and the runtimes'
/// versions; only the app's own breadcrumbs; frames and debug images
/// without the folders that differ per install; tagged with the part of
/// the app that sent it.
SentryEvent scrubCrashReport(
  SentryEvent event, {
  required String part,
  Iterable<String> hosts = const [],
}) {
  String scrub(String text) => scrubCrashReportText(text, hosts: hosts);
  event
    ..user = null
    ..request = null
    ..serverName = null
    ..transaction = null
    ..culprit = _scrubbed(event.culprit, scrub);
  if (event.message case final message?) {
    event.message = SentryMessage(scrub(message.formatted));
  }
  for (final exception in event.exceptions ?? const <SentryException>[]) {
    _scrubException(exception, scrub);
  }
  for (final thread in event.threads ?? const <SentryThread>[]) {
    thread.name = _scrubbed(thread.name, scrub);
    _scrubFrames(thread.stacktrace);
  }
  event
    ..breadcrumbs = [
      for (final breadcrumb in event.breadcrumbs ?? const <Breadcrumb>[])
        ?scrubCrashReportBreadcrumb(breadcrumb, hosts: hosts),
    ]
    ..tags = {
      for (final MapEntry(:key, :value) in (event.tags ?? const {}).entries)
        key: scrub(value),
      'app.part': part,
    };
  // Deprecated by Sentry, though an integration may still fill it.
  // ignore: deprecated_member_use
  if (event.extra case final extra?) {
    // As above.
    // ignore: deprecated_member_use
    event.extra = _scrubMap(extra, scrub);
  }
  _scrubContexts(event.contexts, scrub);
  for (final image in event.debugMeta?.images ?? const <DebugImage>[]) {
    image
      ..codeFile = _withoutInstallFolder(image.codeFile)
      ..debugFile = _withoutInstallFolder(image.debugFile);
  }
  return event;
}

// The folders Android and iOS name at each install and update, which would
// link one install's reports; the rest of a path and the debug and code
// ids, which symbolication goes by, stay. The same rule as
// NativeCrashReports.kt's for Android.
final _installFolders = <(RegExp, String Function(Match))>[
  (
    RegExp(
      '(?:/data|/mnt/expand/[^/]+)/app/(?:~~[A-Za-z0-9_=-]+/)?'
      '([A-Za-z][A-Za-z0-9_.]*)-[A-Za-z0-9_=-]+/',
    ),
    (m) => '/data/app/${m[1]}/',
  ),
  (
    RegExp(
      '((?:/private)?/var/(?:containers/Bundle|mobile/Containers/Data)'
      '/Application/)[0-9A-Fa-f]{8}(?:-[0-9A-Fa-f]{4}){3}-[0-9A-Fa-f]{12}/',
    ),
    (m) => '${m[1]}app/',
  ),
];

String? _withoutInstallFolder(String? path) => path == null
    ? null
    : _installFolders.fold<String>(
        path,
        (result, rule) => result.replaceAllMapped(rule.$1, rule.$2),
      );

/// Null for any breadcrumb but the app's own ([crashReportLogCategory]).
Breadcrumb? scrubCrashReportBreadcrumb(
  Breadcrumb breadcrumb, {
  Iterable<String> hosts = const [],
}) {
  if (breadcrumb.category != crashReportLogCategory) return null;
  String scrub(String text) => scrubCrashReportText(text, hosts: hosts);
  final data = breadcrumb.data;
  return breadcrumb
    ..message = _scrubbed(breadcrumb.message, scrub)
    ..data = data == null ? null : _scrubMap(data, scrub);
}

String? _scrubbed(String? text, String Function(String) scrub) =>
    text == null ? null : scrub(text);

// One without its throwable came as text, like the Java exceptions that
// sentry_flutter parses from a PlatformException's details: only its type
// and module go, as a Java message may quote a file or content.
void _scrubException(SentryException exception, String Function(String) scrub) {
  final throwable = exception.throwable;
  exception.value = throwable == null
      ? null
      : _scrubbed(crashReportErrorText(throwable), scrub);
  if (exception.mechanism case final mechanism?) {
    final data = mechanism.data;
    mechanism
      ..description = _scrubbed(mechanism.description, scrub)
      ..helpLink = null
      ..data = _scrubMap({
        for (final key in _mechanismData)
          if (data.containsKey(key)) key: data[key],
      }, scrub);
  }
  _scrubFrames(exception.stackTrace);
}

// A PlatformException's code and a FlutterError's library; its message and
// anything an SDK adds stay out.
const _mechanismData = ['code', 'library'];

// Frames are code locations; a source line is the one thing beside them
// that one may carry (Dart's own frames have none).
void _scrubFrames(SentryStackTrace? stackTrace) {
  for (final frame in stackTrace?.frames ?? const <SentryStackFrame>[]) {
    frame
      ..contextLine = null
      ..absPath = _withoutInstallFolder(frame.absPath)
      ..fileName = _withoutInstallFolder(frame.fileName)
      ..package = _withoutInstallFolder(frame.package);
  }
}

// The same allowlist as NativeCrashReports.kt's scrubContexts: the
// device's model and system, the app's version, the runtimes' versions.
const _appFields = {
  'app_identifier',
  'app_name',
  'app_version',
  'app_build',
  'build_type',
};
const _osFields = {'name', 'version', 'build'};
final _pathSeparator = RegExp(r'[/\\]');
const _deviceFields = {
  'family',
  'model',
  'model_id',
  'manufacturer',
  'brand',
  'arch',
  'archs',
  'simulator',
};

void _scrubContexts(Contexts contexts, String Function(String) scrub) {
  final app = contexts.app;
  final os = contexts.operatingSystem;
  final device = contexts.device;
  final runtimes = contexts.runtimes;
  contexts
    ..clear()
    ..app = app == null
        ? null
        : SentryApp.fromJson(_only(app.toJson(), _appFields, scrub))
    ..operatingSystem = os == null
        ? null
        : SentryOperatingSystem.fromJson(_only(os.toJson(), _osFields, scrub))
    ..device = device == null
        ? null
        : SentryDevice.fromJson(_only(device.toJson(), _deviceFields, scrub))
    ..runtimes = [
      for (final runtime in runtimes)
        SentryRuntime(
          key: runtime.key,
          name: _scrubbed(runtime.name, scrub),
          version: _scrubbed(runtime.version, scrub),
          rawDescription: switch (runtime.rawDescription) {
            final String text when !text.contains(_pathSeparator) => scrub(
              text,
            ),
            _ => null,
          },
        ),
    ];
}

Map<String, dynamic> _only(
  Map<String, dynamic> json,
  Set<String> fields,
  String Function(String) scrub,
) => _scrubMap({
  for (final MapEntry(:key, :value) in json.entries)
    if (fields.contains(key)) key: value,
}, scrub);

Map<String, dynamic> _scrubMap(
  Map<Object?, Object?> map,
  String Function(String) scrub,
) => {
  for (final MapEntry(:key, :value) in map.entries)
    '$key': _scrubValue(value, scrub),
};

Object? _scrubValue(Object? value, String Function(String) scrub) =>
    switch (value) {
      final String text => scrub(text),
      final Map<Object?, Object?> map => _scrubMap(map, scrub),
      final List<Object?> list => [
        for (final item in list) _scrubValue(item, scrub),
      ],
      _ => value,
    };

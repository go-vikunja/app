import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/logging/redaction.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';

part 'diagnostics_log.g.dart';

/// What the uncaught-error hooks log: the debug console prints [text], the
/// diagnostics log keeps only [type] and [library], as an error's text may
/// quote content that redaction cannot recognise.
final class UncaughtErrorReport {
  const new({required this.type, required this.text, this.library});

  final Type type;

  /// Already redacted.
  final String text;

  /// Flutter's name for where it was caught, such as "widgets library".
  final String? library;

  @override
  String toString() => text;
}

/// A log record from WARNING up as the diagnostics log keeps it: redacted
/// when it is made, its error by type and its stack by the app's own frames.
@immutable
final class DiagnosticsEntry {
  const new({
    required this.at,
    required this.part,
    required this.level,
    required this.logger,
    required this.message,
    this.error,
    this.frames = const [],
    this.count = 1,
  });

  factory capture(LogRecord record, {required String part, DateTime? at}) {
    final report = record.object;
    final String message;
    final Object? errorType;
    if (report is UncaughtErrorReport) {
      final library = _only(report.library ?? '', _notALibraryName, 40);
      message = library.isEmpty
          ? 'Uncaught error'
          : 'Uncaught error ($library)';
      errorType = report.type;
    } else {
      message = _line(redactSecrets(record.message), _maxMessage);
      errorType = record.error?.runtimeType;
    }
    return DiagnosticsEntry(
      at: (at ?? record.time).toUtc(),
      part: part,
      level: record.level.name,
      logger: _only(record.loggerName, _notALoggerName, 60),
      message: message,
      error: errorType == null
          ? null
          : _only('$errorType', _notATypeName, _maxTypeName),
      frames: appFramesOf(record.stackTrace),
    );
  }

  /// Null for anything this version did not write.
  static DiagnosticsEntry? fromJson(Object? json) {
    if (json case {
      'at': final String at,
      'part': final String part,
      'level': final String level,
      'logger': final String logger,
      'message': final String message,
    }) {
      final time = DateTime.tryParse(at)?.toUtc();
      if (time == null || !_levels.contains(level)) return null;
      final error = json['error'];
      final frames = json['frames'];
      final count = json['count'];
      return DiagnosticsEntry(
        at: time,
        part: _only(part, _notALoggerName, 40),
        level: level,
        logger: _only(logger, _notALoggerName, 60),
        message: _line(message, _maxMessage),
        error: error is String
            ? _only(error, _notATypeName, _maxTypeName)
            : null,
        frames: frames is List
            ? [
                for (final frame in frames.take(_maxFrames))
                  if (frame is String) _line(frame, _maxFrame),
              ]
            : const [],
        count: count is int && count > 0 ? count : 1,
      );
    }
    return null;
  }

  /// UTC.
  final DateTime at;

  /// The [AppPart] that logged it, by name.
  final String part;

  /// The [Level]'s name: WARNING, SEVERE or SHOUT.
  final String level;
  final String logger;
  final String message;

  /// The error's type, never its text.
  final String? error;

  /// The frames of the app's own packages, at most eight.
  final List<String> frames;

  /// How many times in a row it was logged; [at] is the last.
  final int count;

  Map<String, Object> toJson() => {
    'at': at.toIso8601String(),
    'part': part,
    'level': level,
    'logger': logger,
    'message': message,
    'error': ?error,
    if (frames.isNotEmpty) 'frames': frames,
    if (count > 1) 'count': count,
  };

  bool _repeats(DiagnosticsEntry other) =>
      other.part == part &&
      other.level == level &&
      other.logger == logger &&
      other.message == message &&
      other.error == error &&
      listEquals(other.frames, frames);

  DiagnosticsEntry _again(DateTime at) => DiagnosticsEntry(
    at: at,
    part: part,
    level: level,
    logger: logger,
    message: message,
    error: error,
    frames: frames,
    count: count + 1,
  );

  int get _size => utf8.encode(jsonEncode(toJson())).length + 1;

  @override
  bool operator ==(Object other) =>
      other is DiagnosticsEntry &&
      other.at == at &&
      other.count == count &&
      _repeats(other);

  @override
  int get hashCode =>
      Object.hash(at, part, level, logger, message, error, count);

  @override
  String toString() => 'DiagnosticsEntry($level $logger, $at)';
}

const _levels = {'WARNING', 'SEVERE', 'SHOUT'};
const _maxMessage = 300;
const _maxTypeName = 80;
const _maxFrames = 8;
const _maxFrame = 200;
final _whitespace = RegExp(r'\s+');
final _notALoggerName = RegExp('[^A-Za-z0-9_.]');
final _notATypeName = RegExp('[^A-Za-z0-9_<>,.? ]');
final _notALibraryName = RegExp('[^A-Za-z ]');

String _line(String text, int max) =>
    _cut(text.replaceAll(_whitespace, ' ').trim(), max);

String _only(String text, RegExp drop, int max) =>
    _cut(text.replaceAll(drop, '').trim(), max);

String _cut(String text, int max) =>
    text.length > max ? '${text.substring(0, max)}…' : text;

const _appPackages = 'package:vikunja_(?:mobile|api|domain|logic|widgets)/';
// `#3      Foo.bar (package:…/foo.dart:12:5)`, as the VM prints a frame.
final _vmFrame = RegExp('^#\\d+\\s+(.+?)\\s+\\(($_appPackages[^)]*)\\)\$');
// `package:…/foo.dart 12:5  Foo.bar`, as package:stack_trace prints one.
final _terseFrame = RegExp(
  '^($_appPackages\\S*)(?:\\s+(\\d+(?::\\d+)?))?\\s+(\\S.*)\$',
);

/// The frames of [stack] in the app's own packages, as `location function`,
/// at most eight: never another package's, which only repeat Flutter's.
List<String> appFramesOf(StackTrace? stack) {
  if (stack == null) return const [];
  final frames = <String>[];
  for (final line in LineSplitter.split('$stack')) {
    final trimmed = line.trim();
    final String frame;
    if (_vmFrame.firstMatch(trimmed) case final match?) {
      frame = '${match[2]} ${match[1]}';
    } else if (_terseFrame.firstMatch(trimmed) case final match?) {
      final position = match[2] == null ? '' : ':${match[2]}';
      frame = '${match[1]}$position ${match[3]}';
    } else {
      continue;
    }
    frames.add(_line(redactSecrets(frame), _maxFrame));
    if (frames.length == _maxFrames) break;
  }
  return frames;
}

/// The diagnostics folder in the app's cache, which backups and device
/// transfers leave out on both platforms (threat model, section 10).
Future<Directory?> defaultDiagnosticsDirectory() async => Directory(
  p.join((await getApplicationCacheDirectory()).path, 'diagnostics'),
);

/// The last warnings and errors of this isolate, in memory and in a file of
/// its own in the diagnostics folder, so that a crash keeps them for the
/// next start; [readAll] adds those of the other isolates and of earlier
/// processes. Each file and the whole read are bounded by [maxEntries] and
/// [maxBytes]; files go after [retention], and of each part's earlier
/// processes [filesPerPart] files stay. It never throws and never logs,
/// being the log's own sink.
final class DiagnosticsLog {
  new({
    required this.part,
    Future<Directory?> Function()? directory,
    DateTime Function()? now,
    Random? random,
    this.maxEntries = 200,
    this.maxBytes = 64 * 1024,
    this.retention = const Duration(days: 7),
    this.filesPerPart = 3,
  }) : _resolveDirectory = directory ?? defaultDiagnosticsDirectory,
       _now = now ?? DateTime.now,
       _random = random ?? Random();

  final AppPart part;
  final int maxEntries;
  final int maxBytes;
  final Duration retention;
  final int filesPerPart;
  final Future<Directory?> Function() _resolveDirectory;
  final DateTime Function() _now;
  final Random _random;

  final _kept = ListQueue<(DiagnosticsEntry, int)>();
  var _bytes = 0;
  Directory? _directory;
  File? _file;
  Future<void>? _starting;
  Future<void>? _writing;
  var _dirty = false;
  var _closed = false;

  /// This isolate's entries, oldest first.
  List<DiagnosticsEntry> get entries => [for (final (e, _) in _kept) e];

  /// The file this isolate writes, once [start] has found the folder.
  @visibleForTesting
  File? get file => _file;

  void add(LogRecord record) {
    if (_closed || record.level < Level.WARNING) return;
    try {
      _keep(DiagnosticsEntry.capture(record, part: part.name, at: _now()));
      _scheduleWrite();
    } on Object {
      // A record that cannot be kept is dropped; logging it would loop.
    }
  }

  void _keep(DiagnosticsEntry entry) {
    if (_kept.isNotEmpty && _kept.last.$1._repeats(entry)) {
      final (last, size) = _kept.removeLast();
      _bytes -= size;
      _push(last._again(entry.at));
    } else {
      _push(entry);
    }
    while (_kept.length > maxEntries ||
        (_bytes > maxBytes && _kept.length > 1)) {
      _bytes -= _kept.removeFirst().$2;
    }
  }

  void _push(DiagnosticsEntry entry) {
    final size = entry._size;
    _kept.addLast((entry, size));
    _bytes += size;
  }

  /// Finds the folder, removes what is past [retention] or beyond
  /// [filesPerPart], and writes what was logged meanwhile. Once.
  Future<void> start() => _starting ??= _start();

  Future<void> _start() async {
    try {
      final directory = await _resolveDirectory();
      if (directory == null || _closed) return;
      await directory.create(recursive: true);
      await _prune(directory);
      final started = _now().toUtc().microsecondsSinceEpoch;
      final suffix = _random.nextInt(1 << 32).toRadixString(16);
      _directory = directory;
      _file = File(
        p.join(directory.path, '${part.name}-$started-$suffix.json'),
      );
      if (_kept.isNotEmpty) _scheduleWrite();
    } on Object {
      // Without the folder the entries stay in memory only.
    }
  }

  Future<void> _prune(Directory directory) async {
    final cutoff = _now().subtract(retention);
    final byPart = <String, List<(int, File)>>{};
    await for (final entity in directory.list(followLinks: false)) {
      if (entity is! File) continue;
      try {
        final name = _fileName.firstMatch(p.basename(entity.path));
        if (entity.lastModifiedSync().isBefore(cutoff)) {
          await entity.delete();
        } else if (name != null) {
          (byPart[name[1]!] ??= []).add((int.parse(name[2]!), entity));
        }
      } on Object {
        // Gone already or being written: looked at again next start.
      }
    }
    for (final files in byPart.values) {
      files.sort((a, b) => b.$1.compareTo(a.$1));
      for (final (_, file) in files.skip(filesPerPart)) {
        try {
          await file.delete();
        } on Object {
          // As above.
        }
      }
    }
  }

  static final _fileName = RegExp(r'^([A-Za-z]+)-(\d+)-[0-9a-f]+\.json$');

  void _scheduleWrite() {
    if (_file == null || _closed) return;
    _dirty = true;
    if (_writing != null) return;
    final writing = _writing = _writeWhileDirty();
    unawaited(
      writing.whenComplete(() {
        if (identical(_writing, writing)) _writing = null;
      }),
    );
  }

  Future<void> _writeWhileDirty() async {
    try {
      while (_dirty && !_closed) {
        _dirty = false;
        final file = _file!;
        final temporary = File('${file.path}.tmp');
        await temporary.writeAsString(
          jsonEncode({
            'version': 1,
            'part': part.name,
            'entries': [for (final (entry, _) in _kept) entry.toJson()],
          }),
        );
        await temporary.rename(file.path);
      }
    } on Object {
      // Kept in memory; the next record tries again.
    }
  }

  /// Completes once what was logged so far is written, as far as it can be.
  @visibleForTesting
  Future<void> get idle async {
    await start();
    for (var writing = _writing; writing != null; writing = _writing) {
      await writing;
    }
  }

  /// This isolate's entries and those of the other files in the folder,
  /// oldest first, within [retention], [maxEntries] and [maxBytes].
  Future<List<DiagnosticsEntry>> readAll() async {
    final all = entries;
    try {
      await start();
      final directory = _directory;
      if (directory != null) {
        await for (final entity in directory.list(followLinks: false)) {
          if (entity is File &&
              entity.path != _file?.path &&
              _fileName.hasMatch(p.basename(entity.path))) {
            all.addAll(await _read(entity));
          }
        }
      }
    } on Object {
      // What could be read.
    }
    final cutoff = _now().toUtc().subtract(retention);
    final recent = all.where((entry) => !entry.at.isBefore(cutoff)).toList()
      ..sort((a, b) => a.at.compareTo(b.at));
    final kept = <DiagnosticsEntry>[];
    var bytes = 0;
    for (final entry in recent.reversed) {
      bytes += entry._size;
      if (kept.length == maxEntries || (bytes > maxBytes && kept.isNotEmpty)) {
        break;
      }
      kept.add(entry);
    }
    return kept.reversed.toList();
  }

  static Future<List<DiagnosticsEntry>> _read(File file) async {
    try {
      // Four times what a file of the default bounds can hold.
      if (await file.length() > 256 * 1024) return const [];
      if (jsonDecode(await file.readAsString()) case {
        'version': 1,
        'entries': final List<Object?> entries,
      }) {
        return [for (final json in entries) ?DiagnosticsEntry.fromJson(json)];
      }
    } on Object {
      // Unreadable or being replaced: left out.
    }
    return const [];
  }

  void close() => _closed = true;
}

DiagnosticsLog? _current;

/// This isolate's diagnostics log, which `configureLogging` sets up.
DiagnosticsLog? get currentDiagnosticsLog => _current;

/// For `configureLogging` and its test reset only.
void useDiagnosticsLog(DiagnosticsLog? log) {
  _current?.close();
  _current = log;
}

/// This isolate's diagnostics log; null before `configureLogging`.
@Riverpod(keepAlive: true)
DiagnosticsLog? diagnosticsLog(Ref ref) => currentDiagnosticsLog;

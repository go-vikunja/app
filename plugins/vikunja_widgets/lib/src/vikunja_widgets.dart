import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:vikunja_widgets/src/widget_models.dart';

/// The app's side of the home-screen widgets (D63). Dart does all file
/// work with `dart:io` (temp file + rename, never a lock); the natives only
/// report directories, list placed widgets and ask the OS to refresh them.
/// Every engine with registered plugins can use it, headless ones included.
class VikunjaWidgets {
  new({
    this._channel = const MethodChannel(channelName),
    this._appGroupId = appGroupId,
  });

  static const channelName = 'io.vikunja.vikunja_widgets';

  static const _actionsQueue = 'widget_actions.jsonl';
  static const _claimedPrefix = 'widget_actions.';
  static const _claimedSuffix = '.claimed';

  static final _accountIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
  static final _random = Random();

  final MethodChannel _channel;
  final String _appGroupId;
  Future<_Directories?>? _directories;

  Future<Directory?> widgetsDirectory() async =>
      (await _resolveDirectories())?.widgets;

  Future<Directory?> appGroupDirectory() async =>
      (await _resolveDirectories())?.appGroup;

  Future<bool> writeSnapshot(String key, String json) async {
    final file = await _snapshotFile(key);
    return file != null && await _writeIfChanged(file, json);
  }

  Future<String?> readSnapshot(String key) async {
    final file = await _snapshotFile(key);
    return file == null ? null : await _readOrNull(file);
  }

  Future<void> deleteSnapshot(String key) async {
    final file = await _snapshotFile(key);
    if (file != null) await _deleteIfExists(file);
  }

  Future<List<String>> snapshotKeys({String? accountId}) async {
    final root = await widgetsDirectory();
    if (root == null) return const [];
    final keys = [
      for (final name in await _fileNames(_directory(root, 'snapshots')))
        if (name.endsWith('.json'))
          name.substring(0, name.length - '.json'.length),
    ];
    return [
      for (final key in keys)
        if (snapshotKeyPattern.hasMatch(key) &&
            (accountId == null || isSnapshotKeyOf(key, accountId)))
          key,
    ]..sort();
  }

  Future<bool> writeCatalog(String accountId, String json) async {
    final file = await _catalogFile(accountId);
    return file != null && await _writeIfChanged(file, json);
  }

  Future<String?> readCatalog(String accountId) async {
    final file = await _catalogFile(accountId);
    return file == null ? null : await _readOrNull(file);
  }

  /// [linkKey] goes into the links the native widgets build themselves.
  Future<bool> writeHost({
    required String? activeAccountId,
    required bool dynamicColor,
    String? linkKey,
  }) async {
    final root = await widgetsDirectory();
    if (root == null) return false;
    return await _writeIfChanged(
      File('${root.path}/host.json'),
      jsonEncode({
        'version': 1,
        'activeAccountId': activeAccountId,
        'dynamicColor': dynamicColor,
        'linkKey': ?linkKey,
      }),
    );
  }

  /// Leaves Android configs and iOS request markers in place, so the
  /// caller can write a tombstone for the keys still on screen.
  Future<void> deleteForAccount(String accountId) async {
    final catalog = await _catalogFile(accountId);
    if (catalog == null) return;
    await _deleteIfExists(catalog);
    for (final key in await snapshotKeys(accountId: accountId)) {
      await deleteSnapshot(key);
    }
    await _removeActions((action) => action.accountId == accountId);
  }

  /// Android: every placed widget of the app's receivers with its config,
  /// null when it has none yet. Elsewhere empty.
  Future<List<WidgetInstance>> configs() async {
    final rows = await _invoke<List<Object?>>('configs') ?? const [];
    return [
      for (final row in rows)
        if (row case {
          'appWidgetId': final int appWidgetId,
          'provider': final Object? provider,
        })
          _instance(
            appWidgetId,
            WidgetProviderKind.fromName(provider),
            switch (row) {
              {'config': final String raw} => raw,
              _ => null,
            },
            followsActiveAccount: row['followsActiveAccount'] != false,
          ),
    ];
  }

  Future<void> saveConfig(
    int appWidgetId, {
    required String? snapshotKey,
    required Map<String, Object?> config,
  }) async {
    final content = _configFile(snapshotKey, config);
    final root = await widgetsDirectory();
    if (root == null) return;
    await _writeIfChanged(
      File('${root.path}/configs/$appWidgetId.json'),
      content,
    );
  }

  Future<Set<String>> displayedSnapshotKeys() async {
    final keys = <String>{};
    final instances = await configs();
    for (final instance in instances) {
      if (instance.snapshotKey case final key?) keys.add(key);
    }
    final unconfiguredList = instances.any(
      (instance) =>
          instance.provider == WidgetProviderKind.list &&
          !instance.isConfigured,
    );
    final root = await widgetsDirectory();
    if (root == null) return keys;
    if (unconfiguredList) {
      if (await _activeAccountId(root) case final accountId?) {
        keys.add(defaultSnapshotKey(accountId));
      }
    }
    for (final name in await _fileNames(_directory(root, 'requests'))) {
      if (snapshotKeyPattern.hasMatch(name)) keys.add(name);
    }
    return keys;
  }

  Future<void> update(Iterable<String> keys) async {
    final list = keys.toSet().toList();
    if (list.isEmpty) return;
    await _invoke<void>('update', {'keys': list});
  }

  Future<void> updateAll() => _invoke<void>('updateAll');

  Future<bool> canRequestPin() async =>
      await _invoke<bool>('canRequestPin') ?? false;

  /// With [config], the widget the launcher places gets it as its config
  /// (Android writes it when the launcher reports the new widget's id).
  Future<bool> requestPin(
    WidgetProviderKind provider, {
    String? snapshotKey,
    Map<String, Object?>? config,
  }) async {
    if (provider == WidgetProviderKind.unknown) {
      throw ArgumentError.value(provider, 'provider');
    }
    return await _invoke<bool>('requestPin', {
          'provider': provider.name,
          'config': config == null ? null : _configFile(snapshotKey, config),
        }) ??
        false;
  }

  /// The spec's `takeIosOutbox`, on both platforms. Nothing is removed
  /// before [ackActions], so a caller that dies keeps its entries, and two
  /// callers may see the same entry: dedupe by [WidgetAction.id].
  Future<List<WidgetAction>> takeActions() async {
    final directories = await _resolveDirectories();
    if (directories == null) return const [];
    if (directories.files case final files?) await _claimQueue(files);
    final sources = await _actionSources(directories);
    for (final source in sources) {
      if (source.hasMalformed) await _rewrite(source, source.actions);
    }
    final actions = [for (final source in sources) ...source.actions];
    final seen = <String>{};
    return actions.where((action) => seen.add(action.id)).toList()..sort(
      (a, b) => a.createdAt != b.createdAt
          ? a.createdAt.compareTo(b.createdAt)
          : a.id.compareTo(b.id),
    );
  }

  Future<void> ackActions(Iterable<String> ids) async {
    final acked = ids.toSet();
    if (acked.isEmpty) return;
    await _removeActions((action) => acked.contains(action.id));
  }

  Future<void> _claimQueue(Directory files) async {
    try {
      await File('${files.path}/$_actionsQueue').rename(
        '${files.path}/$_claimedPrefix${_uniqueSuffix()}$_claimedSuffix',
      );
    } on FileSystemException {
      // Nothing queued since the last claim.
    }
  }

  Future<void> _removeActions(bool Function(WidgetAction) remove) async {
    final directories = await _resolveDirectories();
    if (directories == null) return;
    if (directories.files case final files?) await _claimQueue(files);
    for (final source in await _actionSources(directories)) {
      final kept = source.actions.where((action) => !remove(action)).toList();
      if (kept.length != source.actions.length || source.hasMalformed) {
        await _rewrite(source, kept);
      }
    }
  }

  Future<void> _rewrite(_ActionSource source, List<WidgetAction> kept) async {
    if (kept.isEmpty || !source.isQueue) {
      await _deleteIfExists(source.file);
    } else {
      await _writeAtomically(
        source.file,
        '${kept.map((action) => jsonEncode(action.toJson())).join('\n')}\n',
      );
    }
  }

  Future<List<_ActionSource>> _actionSources(_Directories directories) async {
    final sources = <_ActionSource>[];
    if (directories.files case final files?) {
      for (final name in await _fileNames(files)) {
        if (!name.startsWith(_claimedPrefix) ||
            !name.endsWith(_claimedSuffix)) {
          continue;
        }
        final file = _child(files, name);
        final text = await _readOrNull(file);
        if (text == null) continue;
        final lines = const LineSplitter()
            .convert(text)
            .where((line) => line.trim().isNotEmpty)
            .toList();
        final actions = [for (final line in lines) ?_parseAction(line)];
        sources.add(
          _ActionSource(
            file,
            actions,
            isQueue: true,
            hasMalformed: actions.length != lines.length,
          ),
        );
      }
    }
    final outbox = _directory(directories.widgets, 'outbox');
    for (final name in await _fileNames(outbox)) {
      if (!name.endsWith('.json')) continue;
      final file = _child(outbox, name);
      final text = await _readOrNull(file);
      if (text == null) continue;
      final action = _parseAction(text);
      sources.add(
        _ActionSource(
          file,
          [?action],
          isQueue: false,
          hasMalformed: action == null,
        ),
      );
    }
    return sources;
  }

  WidgetAction? _parseAction(String text) {
    try {
      if (jsonDecode(text) case final Map<String, Object?> json) {
        return WidgetAction.fromJson(json);
      }
    } on FormatException {
      // Dropped below like any other malformed entry.
    }
    return null;
  }

  WidgetInstance _instance(
    int appWidgetId,
    WidgetProviderKind provider,
    String? raw, {
    required bool followsActiveAccount,
  }) {
    Map<String, Object?>? file;
    if (raw != null) {
      try {
        if (jsonDecode(raw) case final Map<String, Object?> json) file = json;
      } on FormatException {
        // A broken config counts as none: the widget offers "Set up".
      }
    }
    if (file == null) {
      return WidgetInstance(
        appWidgetId: appWidgetId,
        provider: provider,
        followsActiveAccount: followsActiveAccount,
      );
    }
    return WidgetInstance(
      appWidgetId: appWidgetId,
      provider: provider,
      followsActiveAccount: followsActiveAccount,
      snapshotKey: switch (file['key']) {
        final String key when snapshotKeyPattern.hasMatch(key) => key,
        _ => null,
      },
      config: Map.of(file)
        ..remove('version')
        ..remove('key'),
    );
  }

  Future<String?> _activeAccountId(Directory root) async {
    final text = await _readOrNull(File('${root.path}/host.json'));
    if (text == null) return null;
    try {
      if (jsonDecode(text) case {'activeAccountId': final String accountId}
          when _accountIdPattern.hasMatch(accountId)) {
        return accountId;
      }
    } on FormatException {
      // Treated like a missing host file.
    }
    return null;
  }

  Future<File?> _snapshotFile(String key) async {
    _checkKey(key);
    final root = await widgetsDirectory();
    return root == null ? null : File('${root.path}/snapshots/$key.json');
  }

  Future<File?> _catalogFile(String accountId) async {
    if (!_accountIdPattern.hasMatch(accountId)) {
      throw ArgumentError.value(accountId, 'accountId');
    }
    final root = await widgetsDirectory();
    return root == null ? null : File('${root.path}/catalogs/$accountId.json');
  }

  String _configFile(String? snapshotKey, Map<String, Object?> config) {
    if (config.containsKey('version') || config.containsKey('key')) {
      throw ArgumentError.value(config, 'config', 'uses a reserved field');
    }
    if (snapshotKey != null) _checkKey(snapshotKey);
    return jsonEncode({'version': 1, 'key': snapshotKey, ...config});
  }

  void _checkKey(String key) {
    if (!snapshotKeyPattern.hasMatch(key)) {
      throw ArgumentError.value(key, 'key', 'not a snapshot key');
    }
  }

  Future<_Directories?> _resolveDirectories() async {
    try {
      return await (_directories ??= _loadDirectories());
    } on Object {
      _directories = null;
      rethrow;
    }
  }

  Future<_Directories?> _loadDirectories() async {
    final reply = await _invoke<Map<Object?, Object?>>('directory', {
      'appGroup': _appGroupId,
    });
    if (reply case {'widgets': final String widgets}) {
      return _Directories(
        widgets: Directory(widgets),
        files: switch (reply['files']) {
          final String path => Directory(path),
          _ => null,
        },
        appGroup: switch (reply['appGroup']) {
          final String path => Directory(path),
          _ => null,
        },
      );
    }
    return null;
  }

  Future<T?> _invoke<T>(String method, [Object? arguments]) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      return null;
    }
  }

  static Future<bool> _writeIfChanged(File file, String content) async {
    if (await _readOrNull(file) == content) return false;
    await _writeAtomically(file, content);
    return true;
  }

  static Future<void> _writeAtomically(File file, String content) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.${_uniqueSuffix()}.tmp');
    try {
      await temp.writeAsString(content, flush: true);
      await temp.rename(file.path);
    } on Object {
      await _deleteIfExists(temp);
      rethrow;
    }
  }

  static Future<String?> _readOrNull(File file) async {
    try {
      return await file.readAsString();
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  static Future<void> _deleteIfExists(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  static Future<List<String>> _fileNames(Directory directory) async {
    try {
      return [
        await for (final entity in directory.list(followLinks: false))
          if (entity is File) entity.uri.pathSegments.last,
      ];
    } on FileSystemException {
      return const [];
    }
  }

  static File _child(Directory directory, String name) =>
      File('${directory.path}/$name');

  static Directory _directory(Directory parent, String name) =>
      Directory('${parent.path}/$name');

  static String _uniqueSuffix() =>
      '$pid-${DateTime.now().microsecondsSinceEpoch}-'
      '${_random.nextInt(1 << 32)}';
}

final class _Directories {
  const new({
    required this.widgets,
    required this.files,
    required this.appGroup,
  });

  final Directory widgets;

  /// Android's files directory, which holds the native action queue.
  final Directory? files;
  final Directory? appGroup;
}

final class _ActionSource {
  const new(
    this.file,
    this.actions, {
    required this.isQueue,
    required this.hasMalformed,
  });

  final File file;
  final List<WidgetAction> actions;
  final bool isQueue;
  final bool hasMalformed;
}

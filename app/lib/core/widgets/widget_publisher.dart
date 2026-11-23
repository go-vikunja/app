import 'dart:async';

import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/time/timers.dart';
import 'package:vikunja_mobile/core/widgets/widget_config.dart';
import 'package:vikunja_mobile/core/widgets/widget_host.dart';
import 'package:vikunja_mobile/core/widgets/widget_snapshot.dart';
import 'package:vikunja_mobile/core/widgets/widget_snapshot_builder.dart';

final _log = Logger('Widgets');

typedef BuildWidgets = Future<WidgetBuild> Function(
  WidgetAccount account,
  Set<WidgetKind> kinds, {
  required bool withCatalog,
});

/// Keeps one account's home-screen widgets in step with its database.
/// Headless: the database, the host, the build, a clock and a timer
/// factory are injected, so background runs publish like the app does.
///
/// [publishNow] builds the snapshots of the widgets showing this account
/// (what the host says they show, and [alwaysKinds]) and
/// the catalog, writes what changed since this publisher last wrote it and
/// asks the OS to redraw the widgets of those keys. While task titles are
/// hidden it deletes the account's other snapshots, which may still list
/// them (a widget removed meanwhile, a list an iOS widget picks next). A
/// change to what a widget reads in the database publishes after
/// [debounce] of quiet, and at the latest [maxWait] after the first change,
/// so a change reaches the widget within seconds even while changes keep
/// coming.
final class WidgetPublisher {
  new({
    required this.accountId,
    required this._db,
    required this._host,
    required this._account,
    required this._build,
    this.alwaysKinds = const {},
    this.refreshesAtValidity = false,
    DateTime Function()? now,
    this.debounce = const Duration(seconds: 1),
    this.maxWait = const Duration(seconds: 3),
    this._createTimer = Timer.new,
  }) : _now = now ?? DateTime.now {
    _tableUpdates = _db
        .tableUpdates(
          TableUpdateQuery.onAllTables([
            _db.tasks,
            _db.taskLabels,
            _db.labels,
            _db.projects,
            _db.projectViews,
            _db.listSnapshots,
            _db.listSnapshotTasks,
            _db.listPreferenceEntries,
          ]),
        )
        .listen((_) => publishSoon());
    // A sync writes its lease and checkpoints to the same table before and
    // after every page, so only a change of the keys a build reads
    // publishes (decision log: Sync). Not a drift query stream: one
    // cancelled just before the database closes breaks its close.
    var settings = _readSettings();
    _settingsUpdates = _db
        .tableUpdates(TableUpdateQuery.onTable(_db.syncState))
        .listen((_) {
          final before = settings;
          unawaited(_publishIfChanged(before, settings = _readSettings()));
        });
  }

  final String accountId;
  final AppDatabase _db;
  final WidgetHost _host;

  /// Null once the account is gone.
  final WidgetAccount? Function() _account;
  final BuildWidgets _build;

  /// Published whether or not a widget shows them: iOS's smart lists, so a
  /// widget placed while the app is not running finds them.
  final Set<WidgetKind> alwaysKinds;

  /// Publishes again when the snapshots go stale (midnight), while this
  /// isolate lives: the app's, not a headless one.
  final bool refreshesAtValidity;
  final Duration debounce;
  final Duration maxWait;
  final DateTime Function() _now;
  final CreateTimer _createTimer;
  late final StreamSubscription<Object?> _tableUpdates;
  late final StreamSubscription<Object?> _settingsUpdates;

  /// What this publisher last wrote, by key, without `generatedAt`.
  final _written = <String, String>{};
  String? _writtenCatalog;
  final _alsoKinds = <WidgetKind>{};
  Future<void>? _running;
  var _requested = false;
  var _disposed = false;
  Timer? _debounceTimer;
  DateTime? _firstChangeAt;
  Timer? _validityTimer;
  WidgetPublishers? _registeredIn;

  /// The keys this publisher wrote, for the tombstones of a sign-out.
  Set<String> get writtenKeys => Set.of(_written.keys);

  /// Completes once no run is under way; a run's error is left to its
  /// caller.
  Future<void> get idle async {
    try {
      await _running;
    } on Object {
      // Reported by publishNow.
    }
  }

  /// Builds and writes what changed; a call during a run makes that run go
  /// once more before the returned future completes. [also] joins the
  /// kinds of that run though no widget shows them yet (one about to be
  /// placed). Nothing after [dispose]. Host and database errors propagate.
  Future<void> publishNow({Set<WidgetKind> also = const {}}) {
    if (_disposed) return Future.value();
    _alsoKinds.addAll(also);
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _firstChangeAt = null;
    _requested = true;
    return _running ??= _loop().whenComplete(() => _running = null);
  }

  /// [publishNow] for the triggers, which have nobody to report to.
  void publishQuietly() => unawaited(
    publishNow().then<void>(
      (_) {},
      onError: (Object error) => _log.warning(
        'Could not publish the widgets of account $accountId: '
        '${error.runtimeType}',
      ),
    ),
  );

  /// [publishQuietly] after [debounce] of quiet, at most [maxWait] after
  /// the first call since the last publish.
  void publishSoon() {
    if (_disposed) return;
    final now = _now();
    final firstChangeAt = _firstChangeAt ??= now;
    final untilMaxWait = firstChangeAt.add(maxWait).difference(now);
    final wait = untilMaxWait < debounce
        ? (untilMaxWait.isNegative ? Duration.zero : untilMaxWait)
        : debounce;
    _debounceTimer?.cancel();
    _debounceTimer = _createTimer(wait, () {
      _debounceTimer = null;
      _firstChangeAt = null;
      publishQuietly();
    });
  }

  /// What a widget showing [kind] would show now; nothing is written.
  /// Null once the account is gone.
  Future<WidgetSnapshot?> preview(WidgetKind kind) async {
    final account = _account();
    if (account == null) return null;
    final build = await _build(account, {kind}, withCatalog: false);
    return build.snapshots.values.single;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _debounceTimer?.cancel();
    _validityTimer?.cancel();
    await _tableUpdates.cancel();
    await _settingsUpdates.cancel();
  }

  /// Null when the database could not be read, closed meanwhile.
  Future<(String?, String?)?> _readSettings() async {
    try {
      final state = await _db.syncStateDao.readAll();
      return (
        state[SyncStateKeys.userSettings],
        state[SyncStateKeys.savedFilters],
      );
    } on Object {
      return null;
    }
  }

  Future<void> _publishIfChanged(
    Future<(String?, String?)?> before,
    Future<(String?, String?)?> after,
  ) async {
    final (was, now) = (await before, await after);
    if (was != null && now != null && was != now) publishSoon();
  }

  Future<void> _loop() async {
    while (_requested && !_disposed) {
      _requested = false;
      await _run();
    }
  }

  Future<void> _run() async {
    final account = _account();
    if (account == null) return;
    final kinds = {
      for (final config in await _host.displayedConfigs())
        if (config.accountId == accountId) config.kind,
      ...alwaysKinds,
      ..._alsoKinds,
    };
    _alsoKinds.clear();
    final build = await _build(account, kinds, withCatalog: true);
    if (_disposed) return;
    var wipedAgain = false;
    try {
      await _write(build);
    } finally {
      // Also after a write that failed: one before it may have landed
      // after the app's wipe.
      wipedAgain = await _registeredIn?._wipeAgainIfSignedOut(this) ?? false;
    }
    if (!wipedAgain) _refreshAtValidity(build.snapshots.values);
  }

  Future<void> _write(WidgetBuild build) async {
    final changed = <String>{};
    for (final MapEntry(:key, value: snapshot) in build.snapshots.entries) {
      final content = snapshot.contentFingerprint();
      if (_disposed) return;
      if (_written[key] == content) continue;
      await _host.writeSnapshot(key, snapshot.encode());
      _written[key] = content;
      changed.add(key);
    }
    if (!build.showsTaskTitles) {
      await _host.deleteSnapshotsExcept(
        accountId,
        build.snapshots.keys.toSet(),
      );
      _written.removeWhere((key, _) => !build.snapshots.containsKey(key));
    }
    if (build.catalog case final catalog?) {
      final content = catalog.contentFingerprint();
      if (_writtenCatalog != content) {
        await _host.writeCatalog(accountId, catalog.encode());
        _writtenCatalog = content;
      }
    }
    if (changed.isNotEmpty) await _host.update(changed);
    _log.fine(
      'Published ${changed.length} of ${build.snapshots.length} widget '
      'snapshots of account $accountId',
    );
  }

  void _refreshAtValidity(Iterable<WidgetSnapshot> snapshots) {
    if (!refreshesAtValidity || _disposed || snapshots.isEmpty) return;
    final staleAt = snapshots
        .map((snapshot) => snapshot.validUntil)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final wait = staleAt.difference(_now());
    _validityTimer?.cancel();
    _validityTimer = _createTimer(
      wait.isNegative ? Duration.zero : wait + const Duration(seconds: 1),
      publishQuietly,
    );
  }
}

/// The publishers this isolate has built, one per account. An account's
/// publisher stays registered after its provider disposed it, until
/// sign-out has replaced the account's widgets: by then the registry
/// change has already rebuilt the providers and closed the database.
final class WidgetPublishers {
  new({
    required this._host,
    required this._removedSnapshot,
    this._signedOutMeanwhile,
  });

  final WidgetHost _host;
  final WidgetSnapshot Function(String key, String accountId) _removedSnapshot;

  /// In a headless isolate: whether the app has signed the account out
  /// since this isolate read the registry, which nothing tells it.
  final Future<bool> Function(String accountId)? _signedOutMeanwhile;
  final _publishers = <String, WidgetPublisher>{};

  WidgetPublisher? find(String accountId) => _publishers[accountId];

  /// Replaces the account's earlier publisher, which is disposed.
  void register(WidgetPublisher publisher) {
    final previous = _publishers[publisher.accountId];
    if (previous != null && !identical(previous, publisher)) {
      unawaited(previous.dispose());
    }
    publisher._registeredIn = this;
    _publishers[publisher.accountId] = publisher;
  }

  /// Always false in the app, whose registry is current.
  Future<bool> signedOutMeanwhile(String accountId) async =>
      await _signedOutMeanwhile?.call(accountId) ?? false;

  /// Sign-out and removal: deletes the account's snapshots, catalog and
  /// queued widget actions, and its widgets say "Account removed" until
  /// they are set up again.
  Future<void> wipe(String accountId) async {
    final publisher = _publishers.remove(accountId);
    await publisher?.dispose();
    // A run already writing must not land after the tombstones.
    await publisher?.idle;
    await _replaceWithTombstones(accountId, {...?publisher?.writtenKeys});
  }

  /// After a headless run of [publisher] wrote: the app's [wipe] may have
  /// come before those writes, so its tombstones are written again.
  Future<bool> _wipeAgainIfSignedOut(WidgetPublisher publisher) async {
    final accountId = publisher.accountId;
    if (!await signedOutMeanwhile(accountId)) return false;
    if (identical(_publishers[accountId], publisher)) {
      _publishers.remove(accountId);
    }
    await publisher.dispose();
    await _replaceWithTombstones(accountId, publisher.writtenKeys);
    _log.info('Account $accountId was signed out meanwhile: widgets wiped');
    return true;
  }

  Future<void> _replaceWithTombstones(
    String accountId,
    Set<String> written,
  ) async {
    final keys = {
      ...written,
      for (final config in await _host.displayedConfigs())
        if (config.accountId == accountId) config.key,
    };
    await _host.deleteForAccount(accountId);
    for (final key in keys) {
      await _host.writeSnapshot(key, _removedSnapshot(key, accountId).encode());
    }
    if (keys.isNotEmpty) await _host.update(keys);
  }
}

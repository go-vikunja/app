import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/db/mappers/project_mappers.dart';
import 'package:vikunja_mobile/core/filters/local_filters.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/text/title_order.dart';

final _log = Logger('SyncEngine');

/// The snapshot key of the Overview's saved filter.
String overviewSnapshotKey(int pseudoProjectId) =>
    '$overviewSnapshotPrefix$pseudoProjectId';

const overviewSnapshotPrefix = 'overview:';

/// The snapshot key of a saved filter opened as a list of its own.
String savedFilterSnapshotKey(int pseudoProjectId) =>
    '$savedFilterSnapshotPrefix$pseudoProjectId';

const savedFilterSnapshotPrefix = 'filter:';

/// The saved filters among the pseudo projects of a project list, by id,
/// without their definitions (the list does not carry them).
List<SavedFilterRef> savedFiltersIn(Iterable<Project> projects) {
  final byId = <int, SavedFilterRef>{
    for (final project in projects)
      if (project.savedFilterId != null)
        project.id: SavedFilterRef(
          projectId: project.id,
          title: project.title,
          isFavorite: project.isFavorite,
          description: project.description,
          updated: project.updated,
        ),
  };
  return [for (final id in byId.keys.toList()..sort()) byId[id]!];
}

/// The stored entry for [filter] as the server answered it: its definition,
/// and the title, description and favourite the answer has.
SavedFilterRef savedFilterRefOf(SavedFilter filter) => SavedFilterRef(
  projectId: filter.pseudoProjectId,
  title: filter.title,
  isFavorite: filter.isFavorite,
  description: filter.description,
  updated: filter.updated,
  definition: SavedFilterDefinition(
    filter: filter.filter,
    timezone: filter.timezone,
    updated: filter.updated,
  ),
);

/// Whether the stored definition of [filter] is missing or older than the
/// saved filter the project list named. The server's `updated` has second
/// precision in the list but not in a write's answer.
bool needsDefinition(SavedFilterRef filter) {
  final definition = filter.definition;
  if (definition == null) return true;
  return !_sameSecond(definition.updated, filter.updated);
}

bool _sameSecond(DateTime? a, DateTime? b) => switch ((a, b)) {
  (null, null) => true,
  (final a?, final b?) =>
    a.millisecondsSinceEpoch ~/ 1000 == b.millisecondsSinceEpoch ~/ 1000,
  _ => false,
};

String encodeSavedFilters(List<SavedFilterRef> filters) => jsonEncode([
  for (final filter in filters)
    {
      'project_id': filter.projectId,
      'title': filter.title,
      'is_favorite': filter.isFavorite,
      if (filter.description.isNotEmpty) 'description': filter.description,
      if (filter.updated case final updated?)
        'updated': updated.toUtc().toIso8601String(),
      if (filter.definition case final definition?)
        'definition': {
          'filter': jsonDecode(encodeViewFilter(definition.filter)!),
          if (definition.timezone.isNotEmpty) 'timezone': definition.timezone,
          if (definition.updated case final updated?)
            'updated': updated.toUtc().toIso8601String(),
        },
    },
]);

/// Never fails; an entry this version cannot read is left out, and a
/// definition it cannot read (or one stored before definitions were) reads
/// as unknown.
List<SavedFilterRef> decodeSavedFilters(String? stored) {
  if (stored == null) return const [];
  final Object? json;
  try {
    json = jsonDecode(stored);
  } on FormatException {
    return const [];
  }
  if (json is! List<Object?>) return const [];
  return [
    for (final entry in json)
      if (entry
          case {'project_id': final int projectId, 'title': final String title}
          when projectId < Project.favoritesId)
        SavedFilterRef(
          projectId: projectId,
          title: title,
          isFavorite: entry['is_favorite'] == true,
          description: switch (entry['description']) {
            final String description => description,
            _ => '',
          },
          updated: _dateOf(entry['updated']),
          definition: _definitionOf(entry['definition']),
        ),
  ];
}

SavedFilterDefinition? _definitionOf(Object? json) {
  if (json case {'filter': final Map<String, Object?> filter}) {
    final ViewFilter? decoded;
    try {
      decoded = decodeViewFilter(jsonEncode(filter));
    } on Object {
      return null;
    }
    if (decoded == null) return null;
    return SavedFilterDefinition(
      filter: decoded,
      timezone: switch (json['timezone']) {
        final String zone => zone,
        _ => '',
      },
      updated: _dateOf(json['updated']),
    );
  }
  return null;
}

DateTime? _dateOf(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toUtc() : null;

/// Inside the transaction of the project phase; written only when changed,
/// so the Overview is not reloaded needlessly. No saved filters is no key.
/// Each listed filter keeps its stored definition, until
/// [fetchSavedFilterDefinitions] replaces an outdated one. The downloads of
/// saved filters the list no longer names go, also when it did not change
/// (a download can finish after the run that dropped its filter), and so do
/// those of filters the device evaluates itself.
Future<void> storeSavedFilters(
  AppDatabase db,
  List<SavedFilterRef> listed,
) async {
  final state = await db.syncStateDao.readAll();
  final known = {
    for (final filter in decodeSavedFilters(state[SyncStateKeys.savedFilters]))
      filter.projectId: filter.definition,
  };
  final filters = [
    for (final filter in listed)
      if (filter.definition == null && known[filter.projectId] != null)
        _withDefinition(filter, known[filter.projectId])
      else
        filter,
  ];
  await db.listSnapshotsDao.removeAll(
    savedFilterSnapshotPrefix,
    keep: {
      for (final filter in filters)
        if (!evaluatesLocally(filter.definition))
          savedFilterSnapshotKey(filter.projectId),
    },
  );
  await _writeSavedFilters(db, filters, state);
}

/// [filters] as the stored list, written only when it changed.
Future<void> _writeSavedFilters(
  AppDatabase db,
  List<SavedFilterRef> filters, [
  Map<String, String>? state,
]) async {
  final encoded = filters.isEmpty ? null : encodeSavedFilters(filters);
  final stored =
      (state ?? await db.syncStateDao.readAll())[SyncStateKeys.savedFilters];
  if (stored == encoded) return;
  await db.syncStateDao.write({SyncStateKeys.savedFilters: encoded});
}

SavedFilterRef _withDefinition(
  SavedFilterRef filter,
  SavedFilterDefinition? definition,
) => SavedFilterRef(
  projectId: filter.projectId,
  title: filter.title,
  isFavorite: filter.isFavorite,
  description: filter.description,
  updated: filter.updated,
  definition: definition,
);

typedef SavedFilterRequest = Future<SavedFilter> Function(
  Future<SavedFilter> Function() send,
);

Future<SavedFilter> _directly(Future<SavedFilter> Function() send) => send();

/// Reads `GET /filters/{id}` for every stored saved filter whose definition
/// is missing or older than the project list says, one request each, and
/// stores what comes back. A failed read is logged and keeps the previous
/// definition; a filter gone meanwhile is left to the next project list.
/// Every request goes through [request].
Future<void> fetchSavedFilterDefinitions({
  required AppDatabase db,
  required VikunjaReadClient client,
  required String runId,
  SavedFilterRequest request = _directly,
}) async {
  final stale = [
    for (final filter in decodeSavedFilters(
      (await db.syncStateDao.readAll())[SyncStateKeys.savedFilters],
    ))
      if (needsDefinition(filter)) filter,
  ];
  if (stale.isEmpty) return;
  var read = 0;
  for (final filter in stale) {
    final SavedFilter answer;
    try {
      answer = await request(() => client.savedFilters.read(filter.filterId));
    } on VikunjaFailure catch (failure) {
      _log.warning(
        'Sync run $runId: saved filter ${filter.filterId} was not read: '
        '${failure.runtimeType}',
      );
      continue;
    }
    await storeSavedFilterAnswer(db, answer, onlyIfListed: true);
    read++;
  }
  _log.fine('Sync run $runId: $read saved filter definitions read');
}

/// Puts [answer] into the stored list: replaces the entry of the same
/// saved filter, else adds it. With [onlyIfListed] (a read by the sync) only
/// a listed entry takes it, and only its definition: the project list stays
/// the source of the title, description, favourite and `updated`, so the
/// next one compares as it should.
Future<void> storeSavedFilterAnswer(
  AppDatabase db,
  SavedFilter answer, {
  bool onlyIfListed = false,
}) => db.transaction(() async {
  final state = await db.syncStateDao.readAll();
  final stored = decodeSavedFilters(state[SyncStateKeys.savedFilters]);
  final fresh = savedFilterRefOf(answer);
  final listed = stored.any((filter) => filter.projectId == fresh.projectId);
  if (!listed && onlyIfListed) return;
  final filters = [
    for (final filter in stored)
      if (filter.projectId != fresh.projectId)
        filter
      else if (onlyIfListed)
        _withDefinition(filter, fresh.definition)
      else
        fresh,
    if (!listed) fresh,
  ]..sort((a, b) => a.projectId.compareTo(b.projectId));
  await _writeSavedFilters(db, filters, state);
});

/// Takes the saved filter out of the stored list, with its list download.
Future<void> forgetSavedFilter(AppDatabase db, int pseudoProjectId) =>
    db.transaction(() async {
      final state = await db.syncStateDao.readAll();
      await _writeSavedFilters(db, [
        for (final filter in decodeSavedFilters(
          state[SyncStateKeys.savedFilters],
        ))
          if (filter.projectId != pseudoProjectId) filter,
      ], state);
      await db.listSnapshotsDao.remove(savedFilterSnapshotKey(pseudoProjectId));
      await db.listSnapshotsDao.remove(overviewSnapshotKey(pseudoProjectId));
    });

/// By title, ignoring case and accents, as the web's sidebar lists them.
List<SavedFilterRef> sortedByTitle(Iterable<SavedFilterRef> filters) =>
    [...filters]..sort((a, b) {
      final byTitle = compareTitles(a.title, b.title);
      return byTitle != 0 ? byTitle : a.projectId.compareTo(b.projectId);
    });

/// The saved filter the user picked for the Overview on the web, while the
/// last project list still named it.
SavedFilterRef? overviewFilterIn(Map<String, String> state) {
  final id = decodeUserSettings(state[SyncStateKeys.userSettings])
      .filterIdUsedOnOverview;
  if (id == null) return null;
  for (final filter in decodeSavedFilters(state[SyncStateKeys.savedFilters])) {
    if (filter.projectId == id) return filter;
  }
  return null;
}

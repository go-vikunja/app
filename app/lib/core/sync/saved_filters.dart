import 'dart:convert';

import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';
import 'package:vikunja_mobile/core/text/title_order.dart';

/// The snapshot key of the Overview's saved filter.
String overviewSnapshotKey(int pseudoProjectId) =>
    '$overviewSnapshotPrefix$pseudoProjectId';

const overviewSnapshotPrefix = 'overview:';

/// The snapshot key of a saved filter opened as a list of its own.
String savedFilterSnapshotKey(int pseudoProjectId) =>
    '$savedFilterSnapshotPrefix$pseudoProjectId';

const savedFilterSnapshotPrefix = 'filter:';

/// The saved filters among the pseudo projects of a project list, by id.
List<SavedFilterRef> savedFiltersIn(Iterable<Project> projects) {
  final byId = <int, SavedFilterRef>{
    for (final project in projects)
      if (project.savedFilterId != null)
        project.id: SavedFilterRef(
          projectId: project.id,
          title: project.title,
          isFavorite: project.isFavorite,
        ),
  };
  return [for (final id in byId.keys.toList()..sort()) byId[id]!];
}

String encodeSavedFilters(List<SavedFilterRef> filters) => jsonEncode([
  for (final filter in filters)
    {
      'project_id': filter.projectId,
      'title': filter.title,
      'is_favorite': filter.isFavorite,
    },
]);

/// Never fails; an entry this version cannot read is left out.
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
        ),
  ];
}

/// Inside the transaction of the project phase; written only when changed,
/// so the Overview is not reloaded needlessly. No saved filters is no key.
/// The downloads of saved filters the list no longer names go, also when
/// it did not change: a download can finish after the run that dropped its
/// filter.
Future<void> storeSavedFilters(
  AppDatabase db,
  List<SavedFilterRef> filters,
) async {
  await db.listSnapshotsDao.removeAll(
    savedFilterSnapshotPrefix,
    keep: {
      for (final filter in filters) savedFilterSnapshotKey(filter.projectId),
    },
  );
  final encoded = filters.isEmpty ? null : encodeSavedFilters(filters);
  final state = await db.syncStateDao.readAll();
  if (state[SyncStateKeys.savedFilters] == encoded) return;
  await db.syncStateDao.write({SyncStateKeys.savedFilters: encoded});
}

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

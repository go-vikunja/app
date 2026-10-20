import 'dart:async';

import 'package:logging/logging.dart';
import 'package:vikunja_api/vikunja_api.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/db/app_database.dart';
import 'package:vikunja_mobile/core/repositories/saved_filter_repository.dart';
import 'package:vikunja_mobile/core/sync/saved_filters.dart';
import 'package:vikunja_mobile/core/sync/sync_engine.dart';

final _log = Logger('AccountData');

/// Saved filter changes straight to the server, written into the stored
/// saved filters once answered, definition included, so the smart list and
/// the Overview evaluate the new filter at once; a sync then runs quietly.
final class LocalSavedFilterRepository implements SavedFilterRepository {
  new(this._db, this._sync, this._write);

  final AppDatabase _db;
  final SyncEngine _sync;
  final VikunjaWriteClient _write;

  @override
  Future<int> create(SavedFilterDraft draft) async {
    final created = await _write.savedFilters.create(_checked(draft));
    await storeSavedFilterAnswer(_db, created);
    _settle('Created saved filter ${created.id}');
    return created.pseudoProjectId;
  }

  @override
  Future<void> update(int pseudoProjectId, SavedFilterDraft draft) async {
    final updated = await _write.savedFilters.update(
      _filterId(pseudoProjectId),
      _checked(draft),
    );
    await storeSavedFilterAnswer(_db, updated);
    _settle('Updated saved filter ${updated.id}');
  }

  @override
  Future<void> delete(int pseudoProjectId) async {
    final id = _filterId(pseudoProjectId);
    await _write.savedFilters.delete(id);
    await forgetSavedFilter(_db, pseudoProjectId);
    _settle('Deleted saved filter $id');
  }

  @override
  Future<void> setFavorite(
    int pseudoProjectId, {
    required bool favorite,
  }) async {
    final changed = await _write.savedFilters.setFavorite(
      _filterId(pseudoProjectId),
      favorite: favorite,
    );
    await storeSavedFilterAnswer(_db, changed);
    _settle('Saved filter ${changed.id} favourite: $favorite');
  }

  @override
  Future<SavedFilter> read(int pseudoProjectId) async {
    final filter = await _write.savedFilters.read(_filterId(pseudoProjectId));
    await storeSavedFilterAnswer(_db, filter, onlyIfListed: true);
    return filter;
  }

  static int _filterId(int pseudoProjectId) =>
      SavedFilter.idOfPseudoProject(pseudoProjectId) ??
      (throw ArgumentError.value(pseudoProjectId, 'pseudoProjectId'));

  static SavedFilterDraft _checked(SavedFilterDraft draft) {
    final title = draft.title.trim();
    if (title.isEmpty) throw ArgumentError.value(draft.title, 'title');
    return SavedFilterDraft(
      title: title,
      description: draft.description,
      filter: draft.filter,
      isFavorite: draft.isFavorite,
    );
  }

  void _settle(String done) {
    _log.fine(done);
    unawaited(_afterWrite());
  }

  Future<void> _afterWrite() async {
    try {
      await _sync.refreshAfterWrite();
    } on Object catch (error) {
      _log.fine(
        'Sync after a saved filter change failed: ${error.runtimeType}',
      );
    }
  }
}

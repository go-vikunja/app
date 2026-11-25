import 'package:meta/meta.dart';
import 'package:vikunja_domain/src/project/project.dart';
import 'package:vikunja_domain/src/project/project_view.dart';

/// A saved filter as `GET /filters/{id}` answers it. The project list
/// names it as the pseudo project [pseudoProjectId], without [filter].
@immutable
final class SavedFilter {
  const new({
    required this.id,
    required this.title,
    required this.filter,
    this.description = '',
    this.isFavorite = false,
    this.timezone = '',
    this.created,
    this.updated,
  });

  final int id;
  final String title;
  final String description;

  /// The filter text, include-nulls flag, search and sort. The server
  /// never applies the stored search to the filter's tasks.
  final ViewFilter filter;
  final bool isFavorite;

  /// The zone relative dates in [filter] are rounded in; empty for the
  /// owner's timezone setting. 2.7.0 cannot store one (v1 drops it, v2
  /// refuses it), so it is only read.
  final String timezone;
  final DateTime? created;
  final DateTime? updated;

  int get pseudoProjectId => pseudoProjectIdOf(id);

  /// Saved filter `n` is listed as project `-n - 1`.
  static int pseudoProjectIdOf(int filterId) => -filterId - 1;

  /// The saved filter's id for its pseudo project id; null for an id that
  /// is not one ([Project.favoritesId] and up).
  static int? idOfPseudoProject(int projectId) =>
      projectId < Project.favoritesId ? -projectId - 1 : null;

  @override
  bool operator ==(Object other) =>
      other is SavedFilter &&
      other.id == id &&
      other.title == title &&
      other.description == description &&
      other.filter == filter &&
      other.isFavorite == isFavorite &&
      other.timezone == timezone &&
      other.updated == updated;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    filter,
    isFavorite,
    timezone,
    updated,
  );

  @override
  String toString() => 'SavedFilter($id)';
}

/// What the app sends to create a saved filter or to change one. A create
/// sends every field; an update leaves every field in [unchanged] as the
/// server has it.
@immutable
final class SavedFilterDraft {
  const new({
    required this.title,
    required this.filter,
    this.description = '',
    this.isFavorite = false,
    this.unchanged = const {},
  });

  /// 1 to 250 characters.
  final String title;

  /// The web's rich text (HTML); the server stores it as it is sent.
  final String description;

  /// The server refuses a filter that has neither filter text, search,
  /// sort nor include-nulls set (code 2002), and a filter it cannot parse
  /// (4016, 4019, 4024).
  final ViewFilter filter;
  final bool isFavorite;

  /// Ignored by a create.
  final Set<SavedFilterDraftField> unchanged;

  /// This draft as an update of [start], what the edit began with: what it
  /// left as it was stays as the server has it, so that a change made
  /// elsewhere since survives.
  SavedFilterDraft changedFrom(SavedFilterDraft start) => SavedFilterDraft(
    title: title,
    description: description,
    filter: filter,
    isFavorite: isFavorite,
    unchanged: {
      if (title.trim() == start.title.trim()) SavedFilterDraftField.title,
      if (description == start.description) SavedFilterDraftField.description,
      if (filter.filter.trim() == start.filter.filter.trim())
        SavedFilterDraftField.filterText,
      if (filter.search == start.filter.search) SavedFilterDraftField.search,
      if (_sameStrings(filter.sortBy, start.filter.sortBy) &&
          _sameStrings(filter.orderBy, start.filter.orderBy))
        SavedFilterDraftField.sort,
      if (filter.includeNulls == start.filter.includeNulls)
        SavedFilterDraftField.includeNulls,
      if (isFavorite == start.isFavorite) SavedFilterDraftField.isFavorite,
    },
  );

  @override
  bool operator ==(Object other) =>
      other is SavedFilterDraft &&
      other.title == title &&
      other.description == description &&
      other.filter == filter &&
      other.isFavorite == isFavorite &&
      other.unchanged.length == unchanged.length &&
      other.unchanged.containsAll(unchanged);

  @override
  int get hashCode => Object.hash(
    title,
    description,
    filter,
    isFavorite,
    Object.hashAllUnordered(unchanged),
  );

  /// Without the title, the description and the filter, which are user
  /// text.
  @override
  String toString() {
    final fields = [
      'favorite: $isFavorite',
      if (unchanged.isNotEmpty)
        'unchanged: ${unchanged.map((field) => field.name).join('/')}',
    ];
    return 'SavedFilterDraft(${fields.join(', ')})';
  }
}

bool _sameStrings(List<String> a, List<String> b) =>
    a.length == b.length &&
    Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);

/// The parts of a saved filter an update can leave as they are; the
/// search, sort and include-nulls flag are keys of its filter.
enum SavedFilterDraftField {
  title,
  description,
  filterText,
  search,
  sort,
  includeNulls,
  isFavorite,
}

import 'dart:async';

import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/core/repositories/label_repository.dart';
import 'package:vikunja_mobile/core/repositories/user_repository.dart';

/// Labels in memory; [createFailure] makes the next creates throw, like an
/// offline device, and [beforeCreate] holds a create until it completes.
/// [serverOnly] are labels the server has that this device has not synced.
///
/// [update] and [delete] apply to the labels at once, as the real one does
/// once the server answered, and are recorded in [updates] and [deletes]
/// first; [beforeChange] holds one, and [changeFailure] is thrown instead
/// while set, with nothing changed. A label the fake does not have is a
/// `NotFound` code 8002 for [update] and nothing for [delete]; a label in
/// [othersLabels] is `Forbidden` for both; a blank or too long title is an
/// `ArgumentError`.
final class FakeLabelRepository implements LabelRepository {
  new({List<Label> labels = const [], this.serverOnly = const []})
    : _labels = [...labels];

  final List<Label> _labels;
  final List<Label> serverOnly;
  final List<String> lookups = [];
  final _changes = StreamController<List<Label>>.broadcast();
  final List<NewLabel> created = [];
  VikunjaFailure? createFailure;
  Future<void> Function()? beforeCreate;
  int nextId = 500;

  final List<(int, LabelChanges)> updates = [];
  final List<int> deletes = [];
  final Set<int> othersLabels = {};
  Exception? changeFailure;
  Future<void> Function()? beforeChange;

  List<Label> get labels => List.unmodifiable(_labels);

  @override
  Stream<List<Label>> watchAll() async* {
    yield _sorted();
    yield* _changes.stream;
  }

  @override
  Future<Label> create(NewLabel label) async {
    await beforeCreate?.call();
    if (createFailure case final failure?) throw failure;
    created.add(label);
    final stored = Label(
      id: nextId++,
      title: label.title,
      description: label.description,
      hexColor: label.hexColor,
    );
    _labels.add(stored);
    _changes.add(_sorted());
    return stored;
  }

  @override
  Future<Label> findOrCreate(NewLabel label) async {
    lookups.add(label.title);
    final lower = label.title.toLowerCase();
    final found = [
      ..._labels,
      ...serverOnly,
    ].where((known) => known.title.toLowerCase() == lower).firstOrNull;
    if (found == null) return await create(label);
    if (!_labels.contains(found)) {
      _labels.add(found);
      _changes.add(_sorted());
    }
    return found;
  }

  @override
  Future<Label> update(int id, LabelChanges changes) async {
    updates.add((id, changes));
    await beforeChange?.call();
    if (changeFailure case final failure?) throw failure;
    if (changes.title case final title? when labelTitleProblem(title) != null) {
      throw ArgumentError.value(changes, 'changes');
    }
    if (othersLabels.contains(id)) throw const Forbidden();
    final index = _labels.indexWhere((label) => label.id == id);
    if (index < 0) throw const NotFound(code: 8002);
    final current = _labels[index];
    final changed = Label(
      id: id,
      title: changes.title ?? current.title,
      description: changes.description ?? current.description,
      hexColor: changes.hexColor ?? current.hexColor,
      createdBy: current.createdBy,
      created: current.created,
      updated: current.updated,
    );
    _labels[index] = changed;
    _changes.add(_sorted());
    return changed;
  }

  @override
  Future<void> delete(int id) async {
    deletes.add(id);
    await beforeChange?.call();
    if (changeFailure case final failure?) throw failure;
    if (othersLabels.contains(id)) throw const Forbidden();
    _labels.removeWhere((label) => label.id == id);
    _changes.add(_sorted());
  }

  List<Label> _sorted() => [..._labels]
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

  @override
  void dispose() => unawaited(_changes.close());
}

/// Assignable users per project in memory; [searchFailure] makes searches
/// throw, like an offline device, and [beforeAnswer] holds the answer to a
/// query until it completes. [everyone] are the server's users for the
/// global [search], which matches the exact username in any case or a part
/// of the name, and records its queries in [globalSearches].
final class FakeUserRepository implements UserRepository {
  new({
    Map<int, List<User>> projectUsers = const {},
    List<User> known = const [],
    List<User> everyone = const [],
  }) : _projectUsers = {...projectUsers},
       _known = [...known],
       everyone = [...everyone];

  final Map<int, List<User>> _projectUsers;
  final List<User> _known;
  final _knownChanges = StreamController<List<User>>.broadcast();
  final List<(int, String)> searches = [];
  final List<String> globalSearches = [];
  List<User> everyone;
  VikunjaFailure? searchFailure;
  Future<void> Function(String query)? beforeAnswer;

  @override
  Future<List<User>> searchAssignees(int projectId, String query) async {
    searches.add((projectId, query));
    await beforeAnswer?.call(query);
    if (searchFailure case final failure?) throw failure;
    final needle = query.trim().toLowerCase();
    final found = [
      for (final user in _projectUsers[projectId] ?? const <User>[])
        if (user.username.toLowerCase().contains(needle) ||
            user.name.toLowerCase().contains(needle))
          user,
    ];
    _remember(found);
    return found;
  }

  @override
  Future<List<User>> search(String query) async {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return const [];
    globalSearches.add(query);
    await beforeAnswer?.call(query);
    if (searchFailure case final failure?) throw failure;
    final found = [
      for (final user in everyone)
        if (user.username.toLowerCase() == needle ||
            user.name.toLowerCase().contains(needle))
          user,
    ];
    _remember(found);
    return found;
  }

  void _remember(List<User> found) {
    final before = _known.length;
    for (final user in found) {
      if (!_known.any((known) => known.id == user.id)) _known.add(user);
    }
    if (_known.length != before && !_knownChanges.isClosed) {
      _knownChanges.add(List.unmodifiable(_known));
    }
  }

  @override
  Future<List<User>> knownUsers() async => List.unmodifiable(_known);

  @override
  Stream<List<User>> watchKnownUsers() async* {
    yield List.unmodifiable(_known);
    yield* _knownChanges.stream;
  }

  @override
  void dispose() => unawaited(_knownChanges.close());
}

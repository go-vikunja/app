import 'dart:async';

import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/label_repository.dart';
import 'package:vikunja_mobile/core/repositories/user_repository.dart';

/// Labels in memory; [createFailure] makes the next creates throw, like an
/// offline device, and [beforeCreate] holds a create until it completes.
/// [serverOnly] are labels the server has that this device has not synced.
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

  List<Label> _sorted() => [..._labels]
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

  @override
  void dispose() => unawaited(_changes.close());
}

/// Assignable users per project in memory; [searchFailure] makes searches
/// throw, like an offline device, and [beforeAnswer] holds the answer to a
/// query until it completes.
final class FakeUserRepository implements UserRepository {
  new({
    Map<int, List<User>> projectUsers = const {},
    List<User> known = const [],
  }) : _projectUsers = {...projectUsers},
       _known = [...known];

  final Map<int, List<User>> _projectUsers;
  final List<User> _known;
  final _knownChanges = StreamController<List<User>>.broadcast();
  final List<(int, String)> searches = [];
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
    final before = _known.length;
    for (final user in found) {
      if (!_known.any((known) => known.id == user.id)) _known.add(user);
    }
    if (_known.length != before && !_knownChanges.isClosed) {
      _knownChanges.add(List.unmodifiable(_known));
    }
    return found;
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

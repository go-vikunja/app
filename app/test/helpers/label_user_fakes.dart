import 'dart:async';

import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/label_repository.dart';
import 'package:vikunja_mobile/core/repositories/user_repository.dart';

/// Labels in memory; [createFailure] makes the next creates throw, like an
/// offline device, and [beforeCreate] holds a create until it completes.
final class FakeLabelRepository implements LabelRepository {
  new({List<Label> labels = const []}) : _labels = [...labels];

  final List<Label> _labels;
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
    for (final user in found) {
      if (!_known.any((known) => known.id == user.id)) _known.add(user);
    }
    return found;
  }

  @override
  Future<List<User>> knownUsers() async => List.unmodifiable(_known);

  @override
  void dispose() {}
}

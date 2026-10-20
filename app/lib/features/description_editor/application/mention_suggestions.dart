import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/tasks/application/people_search.dart';

/// The people offered for the `@` being typed; inactive while none is.
@immutable
final class MentionSuggestions {
  const new({
    this.active = false,
    this.query = '',
    this.people = const [],
    this.searching = false,
    this.fromDevice = false,
  });

  final bool active;
  final String query;
  final List<User> people;
  final bool searching;

  /// The server could not be asked, so [people] are those this device
  /// knows.
  final bool fromDevice;
}

/// Asks [search] (the project's users on the server) 300 ms after the
/// query last changed, as the web does, and falls back to filtering
/// [known] when that fails. Like the web it offers at most 10 people, 5
/// for an empty query, and only people with a username, which is what a
/// mention stores.
final class MentionController extends ValueNotifier<MentionSuggestions> {
  new({required this.search, required this.known})
    : super(const MentionSuggestions());

  static const debounce = Duration(milliseconds: 300);

  final Future<List<User>> Function(String query) search;
  final Future<List<User>> Function() known;
  Timer? _timer;
  int _latest = 0;

  void query(String query) {
    _timer?.cancel();
    final previous = value;
    value = MentionSuggestions(
      active: true,
      query: query,
      people: previous.active ? previous.people : const [],
      searching: true,
      fromDevice: previous.active && previous.fromDevice,
    );
    _timer = Timer(debounce, () => unawaited(_run(query)));
  }

  void end() {
    _timer?.cancel();
    _latest++;
    value = const MentionSuggestions();
  }

  Future<void> _run(String query) async {
    final run = ++_latest;
    List<User> people;
    var fromDevice = false;
    try {
      people = await search(query);
    } on Object {
      fromDevice = true;
      try {
        people = filterUsers(await known(), query);
      } on Object {
        people = const [];
      }
    }
    // A slower answer to an earlier query must not replace a newer one.
    if (run != _latest || !value.active) return;
    value = MentionSuggestions(
      active: true,
      query: query,
      people: mentionable(people, query: query),
      fromDevice: fromDevice,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

@visibleForTesting
List<User> mentionable(List<User> people, {required String query}) {
  final seen = <String>{};
  return [
    for (final user in people)
      if (user.username.isNotEmpty && seen.add(user.username)) user,
  ].take(query.isEmpty ? 5 : 10).toList();
}

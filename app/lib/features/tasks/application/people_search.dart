import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/filters/search_index.dart';

/// [users] whose username or name contains the trimmed [query], ignoring
/// case and accents; how the offline fallback filters the people this
/// device knows.
List<User> filterUsers(List<User> users, String query) {
  final needle = foldForSearch(query.trim());
  if (needle.isEmpty) return users;
  return [
    for (final user in users)
      if (foldForSearch(user.username).contains(needle) ||
          foldForSearch(user.name).contains(needle))
        user,
  ];
}

/// The rows of the people picker: [assigned] (the task's assignees when it
/// opened) first, whatever the query, then everyone [selected] meanwhile
/// that [found] does not show, so a checked person never disappears; then
/// [found] without those.
List<User> peoplePickerRows({
  required List<User> assigned,
  required List<User> selected,
  required List<User> found,
}) {
  final foundIds = {for (final user in found) user.id};
  final pinned = <User>[
    ...assigned,
    for (final user in selected)
      if (!foundIds.contains(user.id)) user,
  ];
  final rows = <User>[];
  final seen = <int>{};
  for (final user in [...pinned, ...found]) {
    if (seen.add(user.id)) rows.add(user);
  }
  return rows;
}

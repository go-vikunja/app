import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/repositories/task_search.dart';
import 'package:vikunja_mobile/core/repositories/task_search_providers.dart';

part 'search_providers.g.dart';

/// What [query] finds on this device; stays loading while no account is
/// signed in.
@riverpod
Stream<SearchResults> searchResults(Ref ref, String query) =>
    ref.watch(taskSearchProvider)?.watch(query) ?? const Stream.empty();

/// The search page's last query, which it shows again when it opens: a
/// project or saved filter opens in the Projects tab, which leaves it.
/// Another account starts empty.
@Riverpod(keepAlive: true)
class LastSearchQuery extends _$LastSearchQuery {
  @override
  String build() {
    ref.watch(activeAccountIdProvider);
    return '';
  }

  String get query => state;

  set query(String query) => state = query;
}

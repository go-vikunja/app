import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/repositories/list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/local/local_list_preferences.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';

part 'list_preferences_providers.g.dart';

@riverpod
ListPreferences accountListPreferences(Ref ref, String accountId) =>
    LocalListPreferences(ref.watch(appDatabaseProvider(accountId)));

/// The active account's; null while nobody is signed in.
@Riverpod(keepAlive: true)
ListPreferences? listPreferences(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return null;
  return ref.watch(accountListPreferencesProvider(accountId));
}

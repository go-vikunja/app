import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/settings/user_settings_json.dart';
import 'package:vikunja_mobile/core/sync/sync_checkpoint.dart';

part 'user_settings_providers.g.dart';

/// The active account's settings as the last sync stored them; the
/// server's defaults until then and while nobody is signed in.
@riverpod
Stream<UserSettings> userSettings(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  if (accountId == null) return Stream.value(const UserSettings());
  return ref
      .watch(appDatabaseProvider(accountId))
      .syncStateDao
      .watchValue(SyncStateKeys.userSettings)
      .map(decodeUserSettings)
      .distinct();
}

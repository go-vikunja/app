import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/security/privacy_settings.dart';
import 'package:vikunja_mobile/core/security/privacy_settings_store.dart';

part 'privacy_providers.g.dart';

final _log = Logger('PrivacySettings');

/// [unreadable] when the stored value could not be read: [settings] are
/// then the defaults, which the settings page shows, and nothing is
/// written back until the user saves.
@immutable
final class StoredPrivacySettings {
  const new(this.settings, {this.unreadable = false});

  final PrivacySettings settings;
  final bool unreadable;

  /// What the app follows: while unreadable, the most private choice of
  /// every switch, since the user may have made any of them.
  PrivacySettings get effective => unreadable
      ? settings.copyWith(
          appLock: true,
          blockScreenshots: true,
          notificationContent: NotificationContent.noTitles,
          widgetTitles: false,
        )
      : settings;

  @override
  bool operator ==(Object other) =>
      other is StoredPrivacySettings &&
      other.settings == settings &&
      other.unreadable == unreadable;

  @override
  int get hashCode => Object.hash(settings, unreadable);
}

@Riverpod(keepAlive: true)
PrivacySettingsStore privacySettingsStore(Ref ref) =>
    PrivacySettingsStore(ref.watch(preferencesStoreProvider));

/// The writable side of the device's privacy settings. The app lock is
/// turned on and off through the app lock controller, which asks for the
/// device's screen lock first.
@Riverpod(keepAlive: true)
class PrivacySettingsController extends _$PrivacySettingsController {
  @override
  Future<StoredPrivacySettings> build() async {
    try {
      return StoredPrivacySettings(
        await ref.watch(privacySettingsStoreProvider).read(),
      );
    } on PrivacySettingsUnreadable catch (error) {
      _log.warning('Unreadable privacy settings: ${error.cause}');
      return const StoredPrivacySettings(PrivacySettings(), unreadable: true);
    }
  }

  /// Throws when the settings could not be stored; they stay as they were.
  Future<void> save(PrivacySettings settings) async {
    await ref.read(privacySettingsStoreProvider).write(settings);
    state = AsyncData(StoredPrivacySettings(settings));
  }

  /// [edit] applied to the current settings, the defaults while they
  /// load or could not be read.
  Future<void> change(PrivacySettings Function(PrivacySettings) edit) async {
    final current = await future;
    await save(edit(current.settings));
  }
}

/// The settings everything else follows ([StoredPrivacySettings.effective]);
/// for the background containers too, which read them fresh on every run.
@Riverpod(keepAlive: true)
Future<PrivacySettings> privacySettings(Ref ref) async =>
    (await ref.watch(privacySettingsControllerProvider.future)).effective;

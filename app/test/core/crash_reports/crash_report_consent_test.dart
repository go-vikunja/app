import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/crash_reports/crash_report_consent.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';

import '../../helpers/auth_fakes.dart';

final class _UnwritablePreferences implements PreferencesStore {
  @override
  Future<String?> getString(String key) async => null;

  @override
  Future<void> setString(String key, String value) async =>
      throw Exception('Preferences unwritable');

  @override
  Future<void> remove(String key) async {}
}

void main() {
  test('three states on the device: not asked until an answer is '
      'stored, and back to not asked when it is removed', () async {
    final preferences = MemoryPreferencesStore();
    final store = CrashReportConsentStore(preferences);

    expect(await store.read(), CrashReportConsent.notAsked);
    await store.write(CrashReportConsent.allowed);
    expect(preferences.values, {'crash_reports.consent': 'allowed'});
    expect(await store.read(), CrashReportConsent.allowed);
    await store.write(CrashReportConsent.declined);
    expect(await store.read(), CrashReportConsent.declined);
    await store.write(CrashReportConsent.notAsked);
    expect(preferences.values, isEmpty);

    preferences.values[CrashReportConsentStore.key] = 'yes';
    expect(await store.read(), CrashReportConsent.notAsked);
  });

  test('a choice that cannot be read counts as declined, so that nothing '
      'is sent and nothing asked', () async {
    final preferences = MemoryPreferencesStore()
      ..values[CrashReportConsentStore.key] = 'allowed'
      ..failNextRead.add(CrashReportConsentStore.key);
    final container = ProviderContainer(
      overrides: [preferencesStoreProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(crashReportConsentControllerProvider.future),
      CrashReportConsent.declined,
    );
  });

  test('a change takes effect at once, also when it cannot be stored, '
      'and says so by throwing', () async {
    final preferences = _UnwritablePreferences();
    final container = ProviderContainer(
      overrides: [preferencesStoreProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);
    await container.read(crashReportConsentControllerProvider.future);

    await expectLater(
      container
          .read(crashReportConsentControllerProvider.notifier)
          .set(CrashReportConsent.allowed),
      throwsException,
    );
    expect(
      container.read(crashReportConsentControllerProvider).value,
      CrashReportConsent.allowed,
    );
  });
}

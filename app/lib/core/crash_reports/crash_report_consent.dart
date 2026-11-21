import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/storage/preferences_store.dart';

part 'crash_report_consent.g.dart';

final _log = Logger('CrashReports');

enum CrashReportConsent { notAsked, allowed, declined }

/// `crash_reports.consent` in the preferences: a device setting like the
/// theme, the same for every account and kept on sign-out (D113).
final class CrashReportConsentStore {
  new(this._preferences);

  static const key = 'crash_reports.consent';

  final PreferencesStore _preferences;

  /// Anything but a stored answer is [CrashReportConsent.notAsked].
  Future<CrashReportConsent> read() async =>
      switch (await _preferences.getString(key)) {
        'allowed' => CrashReportConsent.allowed,
        'declined' => CrashReportConsent.declined,
        _ => CrashReportConsent.notAsked,
      };

  Future<void> write(CrashReportConsent consent) =>
      consent == CrashReportConsent.notAsked
      ? _preferences.remove(key)
      : _preferences.setString(key, consent.name);
}

@Riverpod(keepAlive: true)
CrashReportConsentStore crashReportConsentStore(Ref ref) =>
    CrashReportConsentStore(ref.watch(preferencesStoreProvider));

/// The device's answer. One that cannot be read counts as declined, so
/// nothing is sent and nothing asked until it can be read again.
@Riverpod(keepAlive: true)
class CrashReportConsentController extends _$CrashReportConsentController {
  @override
  Future<CrashReportConsent> build() async {
    try {
      return await ref.watch(crashReportConsentStoreProvider).read();
    } on Object catch (error) {
      _log.warning(
        'Could not read the crash report choice: ${error.runtimeType}',
      );
      return CrashReportConsent.declined;
    }
  }

  /// Takes effect at once, also when it cannot be stored, which throws.
  Future<void> set(CrashReportConsent consent) async {
    state = AsyncData(consent);
    await ref.read(crashReportConsentStoreProvider).write(consent);
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/theme/theme_providers.dart';
import 'package:vikunja_mobile/bootstrap/appearance_start.dart';
import 'package:vikunja_mobile/bootstrap/previous_app_start.dart';
import 'package:vikunja_mobile/core/auth/auth_providers.dart';
import 'package:vikunja_mobile/core/settings/user_settings_providers.dart';
import 'package:vikunja_mobile/features/onboarding/application/previous_app.dart';

import '../helpers/auth_fakes.dart';
import '../helpers/previous_app_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AuthFakes auth;

  setUp(() => auth = AuthFakes());

  ProviderContainer container() {
    final container = ProviderContainer(
      overrides: [
        ...auth.overrides,
        previousAppPlatformProvider.overrideWithValue(
          FakePreviousAppPlatform(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  for (final (stored, mode) in [
    ('dark', ThemeMode.dark),
    ('light', ThemeMode.light),
    ('system', ThemeMode.system),
    (null, ThemeMode.system),
    ('purple', ThemeMode.system),
  ]) {
    test('the theme stored on this device, $stored, is there for the first '
        'frame', () async {
      if (stored != null) auth.preferences.values[themeModeKey] = stored;
      final app = container();

      await loadAppearance(app);

      expect(app.read(themeModeProvider), mode);
    });
  }

  test("after the update the previous app's dark theme is the first "
      "frame's, whoever signs in later", () async {
    auth.secureStore.values.addAll(previousAppValues(theme: 'dark'));
    final app = container();

    await importPreviousApp(app);
    await app.read(accountsProvider.future);
    await loadAppearance(app);

    expect(app.read(themeModeProvider), ThemeMode.dark);
  });

  test("the active account's settings stay loaded after the wait", () async {
    final app = container();

    await loadAppearance(app);
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(app.read(userSettingsProvider).hasValue, isTrue);
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/core/background/background_entry_point.dart';
import 'package:vikunja_mobile/core/notifications/notification_action_handler.dart';
import 'package:vikunja_mobile/core/platform/app_part.dart';
import 'package:vikunja_mobile/core/repositories/repository_providers.dart';
import 'package:vikunja_mobile/core/widgets/widget_entry_points.dart';

void main() {
  test('a container is the app unless it says otherwise', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(appPartProvider), AppPart.app);
  });

  test('each container the OS starts without the app names its part', () {
    for (final (overrides, part) in [
      (backgroundRunOverrides, AppPart.backgroundRun),
      (notificationActionOverrides, AppPart.notificationAction),
      (widgetActionOverrides, AppPart.widgetAction),
    ]) {
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);

      expect(container.read(appPartProvider), part);
      expect(container.read(runsHeadlessProvider), isTrue, reason: '$part');
    }
  });
}

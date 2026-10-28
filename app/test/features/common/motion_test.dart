import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/features/common/presentation/motion.dart';

void main() {
  for (final (name, features, expected) in [
    (
      'nothing set',
      const FakeAccessibilityFeatures(supportsAnnounce: true),
      false,
    ),
    (
      "iOS's Reduce Motion",
      const FakeAccessibilityFeatures(
        reduceMotion: true,
        supportsAnnounce: true,
      ),
      true,
    ),
    (
      "Android's Remove animations",
      const FakeAccessibilityFeatures(
        disableAnimations: true,
        supportsAnnounce: true,
      ),
      true,
    ),
  ]) {
    testWidgets('with $name the app ${expected ? 'jumps' : 'animates'}', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = features;
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      late bool reduced;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              reduced = reduceMotionOf(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(reduced, expected);
    });
  }
}

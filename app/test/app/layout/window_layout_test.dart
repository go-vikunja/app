import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/layout/window_layout.dart';

import '../../helpers/large_screens.dart';

void main() {
  test('the width classes, the height classes and two panes follow M3', () {
    expect(
      const WindowLayout(Size(599, 800)).sizeClass,
      WindowSizeClass.compact,
    );
    expect(
      const WindowLayout(Size(600, 800)).sizeClass,
      WindowSizeClass.medium,
    );
    expect(
      const WindowLayout(Size(839, 800)).sizeClass,
      WindowSizeClass.medium,
    );
    expect(
      const WindowLayout(Size(840, 800)).sizeClass,
      WindowSizeClass.expanded,
    );
    expect(const WindowLayout(Size(952, 479)).compactHeight, isTrue);
    expect(const WindowLayout(Size(952, 480)).compactHeight, isFalse);
    expect(const WindowLayout(Size(800, 899)).expandedHeight, isFalse);
    expect(const WindowLayout(Size(800, 900)).expandedHeight, isTrue);
    expect(const WindowLayout(androidLandscape).twoPane, isFalse);
    expect(const WindowLayout(Size(840, 480)).twoPane, isTrue);
    expect(const WindowLayout(androidTabletPortrait).twoPane, isFalse);
  });

  test('widths are capped on tablet-sized windows only: never on a phone in '
      'either orientation, the 800×600 test surface or a split screen', () {
    const off = [
      androidPhone,
      iPhone,
      androidSmallLandscape,
      androidLandscape,
      iPhoneLandscape,
      defaultSurface,
      androidSplit,
    ];
    const on = [
      androidTabletPortrait,
      iPad11Portrait,
      iPad11Landscape,
      iPad13Portrait,
      androidTabletLandscape,
      // A tall surface of some tests: on, but narrower than any cap.
      Size(360, 1800),
    ];
    for (final size in off) {
      expect(WindowLayout(size).capsWidths, isFalse, reason: sizeName(size));
    }
    for (final size in on) {
      expect(WindowLayout(size).capsWidths, isTrue, reason: sizeName(size));
    }
  });

  test('the insets of every window, beside the Android rail and without', () {
    const rail = 80.0;
    // (window, beside the rail, list inset, form inset)
    const rows = [
      (androidPhone, false, 0.0, 0.0),
      (iPhone, false, 0.0, 0.0),
      (androidSmallLandscape, true, 0.0, 0.0),
      (androidLandscape, true, 0.0, 0.0),
      (androidLandscape, false, 0.0, 0.0),
      (iPhoneLandscape, false, 0.0, 0.0),
      (defaultSurface, true, 0.0, 0.0),
      (defaultSurface, false, 0.0, 0.0),
      (androidSplit, true, 0.0, 0.0),
      (androidTabletPortrait, true, 0.0, 40.0),
      (androidTabletPortrait, false, 0.0, 80.0),
      (iPad11Portrait, false, 0.0, 97.0),
      (iPad11Landscape, false, 177.0, 277.0),
      (iPad13Portrait, false, 92.0, 192.0),
      (androidTabletLandscape, true, 180.0, 280.0),
      (androidTabletLandscape, false, 220.0, 320.0),
      (Size(360, 1800), false, 0.0, 0.0),
    ];
    for (final (window, besideRail, list, form) in rows) {
      final available = window.width - (besideRail ? rail : 0);
      final caps = WindowLayout(window).capsWidths;
      final name = '${sizeName(window)}${besideRail ? ' beside the rail' : ''}';
      expect(
        ReadableWidth.insetFor(
          available: available,
          max: ReadableWidth.list,
          caps: caps,
        ),
        list,
        reason: '$name list',
      );
      expect(
        ReadableWidth.insetFor(
          available: available,
          max: ReadableWidth.form,
          caps: caps,
        ),
        form,
        reason: '$name form',
      );
    }
  });

  test('the iOS sheet card lies at the centre of the iPad, as wide as a '
      'form', () {
    for (final (window, left, right) in [
      (iPad11Portrait, 97.0, 737.0),
      (iPad11Landscape, 277.0, 917.0),
      (iPad13Portrait, 192.0, 832.0),
    ]) {
      final inset = ReadableWidth.insetFor(
        available: window.width,
        max: ReadableWidth.sheet,
        caps: WindowLayout(window).capsWidths,
      );
      expect((inset, window.width - inset), (left, right));
    }
  });

  test('no inset without a bounded width', () {
    expect(
      ReadableWidth.insetFor(
        available: double.infinity,
        max: ReadableWidth.list,
        caps: true,
      ),
      0,
    );
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/layout/readable_sheet.dart';
import 'package:vikunja_mobile/app/layout/readable_width.dart';
import 'package:vikunja_mobile/app/layout/window_layout.dart';

const androidPhone = Size(360, 740);
const androidSmallLandscape = Size(740, 360);
const androidLandscape = Size(952, 427);
const iPhone = Size(375, 667);

/// With the notch and home indicator padding of an iPhone in landscape.
const iPhoneLandscape = Size(844, 390);
const defaultSurface = Size(800, 600);

/// The Pixel Tablet's 50/50 split screen.
const androidSplit = Size(640, 800);
const androidTabletPortrait = Size(800, 1280);
const androidTabletLandscape = Size(1280, 800);
const iPad11Portrait = Size(834, 1194);
const iPad11Landscape = Size(1194, 834);
const iPad13Portrait = Size(1024, 1366);

const List<Size> androidSizes = [
  androidPhone,
  androidSmallLandscape,
  androidLandscape,
  androidSplit,
  androidTabletPortrait,
  androidTabletLandscape,
];
const List<Size> iOSSizes = [
  iPhone,
  iPhoneLandscape,
  iPad11Portrait,
  iPad11Landscape,
  iPad13Portrait,
];
const List<Size> androidTablets = [
  androidTabletLandscape,
  androidTabletPortrait,
];
const List<Size> iOSTablets = [iPad11Landscape, iPad11Portrait];

String sizeName(Size size) =>
    '${size.width.toStringAsFixed(0)}×${size.height.toStringAsFixed(0)}';

/// Phones at 3 device pixels per logical pixel, as `usePhoneSurface`,
/// windows of tablet size at 2; [iPhoneLandscape] with its side insets.
void useWindow(WidgetTester tester, Size logicalSize) {
  final ratio = WindowLayout(logicalSize).capsWidths ? 2.0 : 3.0;
  tester.view
    ..devicePixelRatio = ratio
    ..physicalSize = logicalSize * ratio;
  addTearDown(tester.view.reset);
  if (logicalSize == iPhoneLandscape) {
    tester.view.padding = const FakeViewPadding(
      left: 47 * 3,
      right: 47 * 3,
      bottom: 21 * 3,
    );
    addTearDown(tester.view.resetPadding);
  }
}

Size windowSize(WidgetTester tester) =>
    tester.view.physicalSize / tester.view.devicePixelRatio;

/// The right edge of the Android navigation rail, or 0 without one (on iOS,
/// on a phone in portrait, under a page pushed over the shell).
double railRight(WidgetTester tester) {
  final rail = find.byType(NavigationRail);
  return rail.evaluate().isEmpty ? 0 : tester.getRect(rail).right;
}

typedef Band = ({double left, double right});

/// Where content of at most [maxWidth] lies across the window: beside the
/// rail (or from [left]), inset as the app insets it.
Band readableBand(WidgetTester tester, double maxWidth, {double? left}) {
  final window = windowSize(tester);
  final start = left ?? railRight(tester);
  final inset = ReadableWidth.insetFor(
    available: window.width - start,
    max: maxWidth,
    caps: WindowLayout(window).capsWidths,
  );
  return (left: start + inset, right: window.width - inset);
}

const layoutTolerance = 0.5;

/// Material 3's own cap on a bottom sheet, which the app keeps.
const materialSheetMaxWidth = 640.0;

void expectInBand(Rect rect, Band band, {String? reason}) {
  expect(
    rect.left,
    greaterThanOrEqualTo(band.left - layoutTolerance),
    reason: reason,
  );
  expect(
    rect.right,
    lessThanOrEqualTo(band.right + layoutTolerance),
    reason: reason,
  );
}

/// [rect] fills [band] exactly, within the tolerance.
void expectFillsBand(Rect rect, Band band, {String? reason}) {
  expect(
    rect.left,
    moreOrLessEquals(band.left, epsilon: layoutTolerance),
    reason: reason,
  );
  expect(
    rect.right,
    moreOrLessEquals(band.right, epsilon: layoutTolerance),
    reason: reason,
  );
}

/// The visible box of an overlay: the first [Material] below [overlay].
/// `Dialog` and `BottomSheet` themselves span their whole route.
Rect overlayMaterialRect(WidgetTester tester, Finder overlay) => tester.getRect(
  find.descendant(of: overlay, matching: find.byType(Material)).first,
);

Rect dialogRect(WidgetTester tester) =>
    overlayMaterialRect(tester, find.byType(Dialog).last);

Rect bottomSheetRect(WidgetTester tester) =>
    overlayMaterialRect(tester, find.byType(BottomSheet).last);

/// The card of the front iOS sheet or bottom popup.
Rect iOSSheetContentRect(WidgetTester tester) => tester.getRect(
  find
      .descendant(
        of: find.byType(ReadableSheetWidth).last,
        matching: find.byType(ClipRSuperellipse),
      )
      .first,
);

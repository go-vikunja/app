import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/app/layout/pane_split.dart';

// The rail of a device; tests pump a wider one (D69).
const _rail = 80.0;

DisplayFeature _fold(
  double left, {
  double width = 0,
  double height = 701,
  DisplayFeatureState state = DisplayFeatureState.postureHalfOpened,
  DisplayFeatureType type = DisplayFeatureType.fold,
}) => DisplayFeature(
  bounds: Rect.fromLTWH(left, 0, width, height),
  type: type,
  state: state,
);

PaneSplit _split(
  Size window, {
  double rail = _rail,
  List<DisplayFeature> features = const [],
  TextDirection direction = TextDirection.ltr,
}) => paneSplitFor(
  windowWidth: window.width,
  contentWidth: window.width - rail,
  textDirection: direction,
  displayFeatures: features,
);

void main() {
  test('the pane takes 40 % of the content within 360..480, the list the '
      'rest less the divider', () {
    expect(_split(const Size(1280, 800)), (
      listWidth: 719.0,
      gap: 1.0,
      paneWidth: 480.0,
      divider: true,
    ));
    expect(_split(const Size(841, 701)), (
      listWidth: 400.0,
      gap: 1.0,
      paneWidth: 360.0,
      divider: true,
    ));
    final iPad = _split(const Size(1194, 834), rail: 0);
    expect(iPad.paneWidth, moreOrLessEquals(477.6));
    expect(iPad.listWidth, moreOrLessEquals(1194 - 1 - 477.6));
    expect(iPad.divider, isTrue);
  });

  test('a half-opened vertical fold inside the content splits on it', () {
    expect(_split(const Size(841, 701), features: [_fold(420.5)]), (
      listWidth: 340.5,
      gap: 0.0,
      paneWidth: 420.5,
      divider: false,
    ));
  });

  test('a hinge with a width lies between the list and the pane', () {
    expect(
      _split(
        const Size(1280, 800),
        features: [
          _fold(
            630,
            width: 20,
            height: 800,
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.postureFlat,
          ),
        ],
      ),
      (listWidth: 550.0, gap: 20.0, paneWidth: 630.0, divider: false),
    );
  });

  test('a fold leaving a side under 320 gives the normal split', () {
    final normal = _split(const Size(841, 701));
    expect(_split(const Size(841, 701), features: [_fold(380)]), normal);
    expect(_split(const Size(841, 701), features: [_fold(530)]), normal);
  });

  test('a flat fold of no width, a cutout and a fold outside the content are '
      'ignored', () {
    final normal = _split(const Size(1280, 800));
    for (final feature in [
      _fold(640, height: 800, state: DisplayFeatureState.postureFlat),
      _fold(640, height: 800, state: DisplayFeatureState.unknown),
      _fold(
        600,
        width: 80,
        height: 40,
        type: DisplayFeatureType.cutout,
        state: DisplayFeatureState.unknown,
      ),
      _fold(40, height: 800),
    ]) {
      expect(
        _split(const Size(1280, 800), features: [feature]),
        normal,
        reason: '$feature',
      );
    }
  });

  test('right to left, the rail is on the right and the pane on the left of '
      'the fold', () {
    expect(
      _split(
        const Size(1280, 800),
        direction: TextDirection.rtl,
        features: [_fold(700, height: 800)],
      ),
      (listWidth: 500.0, gap: 0.0, paneWidth: 700.0, divider: false),
    );
    expect(
      _split(const Size(1280, 800), direction: TextDirection.rtl),
      _split(const Size(1280, 800)),
    );
  });

  test('a vertical fold is a half-opened one or a hinge with a width, not '
      'a flat fold of no width, a horizontal fold or a cutout', () {
    expect(hasVerticalFold([_fold(640, height: 800)]), isTrue);
    expect(
      hasVerticalFold([
        _fold(
          630,
          width: 20,
          height: 800,
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureFlat,
        ),
      ]),
      isTrue,
    );
    expect(
      hasVerticalFold([
        _fold(640, height: 800, state: DisplayFeatureState.postureFlat),
      ]),
      isFalse,
    );
    expect(
      hasVerticalFold([
        const DisplayFeature(
          bounds: Rect.fromLTWH(0, 400, 1280, 0),
          type: DisplayFeatureType.fold,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      ]),
      isFalse,
    );
    expect(
      hasVerticalFold([
        _fold(
          600,
          width: 30,
          height: 80,
          type: DisplayFeatureType.cutout,
          state: DisplayFeatureState.unknown,
        ),
      ]),
      isFalse,
    );
    expect(hasVerticalFold(const []), isFalse);
  });

  test('tabletop is a half-opened horizontal fold or hinge', () {
    DisplayFeature horizontal(DisplayFeatureState state) => DisplayFeature(
      bounds: const Rect.fromLTWH(0, 400, 1280, 0),
      type: DisplayFeatureType.fold,
      state: state,
    );
    expect(
      isTabletop([horizontal(DisplayFeatureState.postureHalfOpened)]),
      isTrue,
    );
    expect(
      isTabletop([
        const DisplayFeature(
          bounds: Rect.fromLTWH(0, 390, 1280, 20),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.postureHalfOpened,
        ),
      ]),
      isTrue,
    );
    expect(isTabletop([horizontal(DisplayFeatureState.postureFlat)]), isFalse);
    expect(isTabletop([_fold(640, height: 800)]), isFalse);
    expect(isTabletop(const []), isFalse);
  });
}

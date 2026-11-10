import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/widgets.dart';

/// How the content right of the rail (left of it in RTL) is shared between
/// the list and the task detail pane on its end side; the gap between them
/// is a divider, or else a fold or hinge.
typedef PaneSplit = ({
  double listWidth,
  double gap,
  double paneWidth,
  bool divider,
});

const _minPaneWidth = 360.0;
const _maxPaneWidth = 480.0;
const _minSideOnFeature = 320.0;

bool _isFoldOrHinge(DisplayFeature feature) =>
    feature.type == DisplayFeatureType.fold ||
    feature.type == DisplayFeatureType.hinge;

bool _dividesSideBySide(DisplayFeature feature) {
  final bounds = feature.bounds;
  // A flat fold of no width divides nothing on the screen.
  return _isFoldOrHinge(feature) &&
      bounds.height > bounds.width &&
      (bounds.width > 0 ||
          feature.state == DisplayFeatureState.postureHalfOpened);
}

/// A vertical fold or hinge that divides the window into a left and a
/// right screen, wherever it lies.
bool hasVerticalFold(List<DisplayFeature> displayFeatures) =>
    displayFeatures.any(_dividesSideBySide);

/// A device half opened like a laptop: a horizontal fold or hinge, so the
/// window is two screens one above the other, too low for a pane.
bool isTabletop(List<DisplayFeature> displayFeatures) => displayFeatures.any(
  (feature) =>
      _isFoldOrHinge(feature) &&
      feature.bounds.width > feature.bounds.height &&
      feature.state == DisplayFeatureState.postureHalfOpened,
);

/// The list beside the pane, split on a vertical fold or hinge inside the
/// content when both sides keep at least 320 dp, else the pane takes 40 %
/// of the content within 360..480 dp and a 1 dp divider sits before it.
/// [windowWidth] and the features' bounds are in logical pixels; the rail
/// lies on the start side, outside [contentWidth].
PaneSplit paneSplitFor({
  required double windowWidth,
  required double contentWidth,
  required TextDirection textDirection,
  required List<DisplayFeature> displayFeatures,
}) {
  final ltr = textDirection == TextDirection.ltr;
  final contentLeft = ltr ? windowWidth - contentWidth : 0.0;
  final contentRight = contentLeft + contentWidth;
  for (final feature in displayFeatures) {
    final bounds = feature.bounds;
    if (!_dividesSideBySide(feature)) continue;
    if (bounds.left <= contentLeft || bounds.right >= contentRight) continue;
    final leftSide = bounds.left - contentLeft;
    final rightSide = contentRight - bounds.right;
    if (leftSide < _minSideOnFeature || rightSide < _minSideOnFeature) {
      continue;
    }
    return (
      listWidth: ltr ? leftSide : rightSide,
      gap: bounds.width,
      paneWidth: ltr ? rightSide : leftSide,
      divider: false,
    );
  }
  final paneWidth = (contentWidth * 0.4).clamp(_minPaneWidth, _maxPaneWidth);
  return (
    listWidth: contentWidth - 1 - paneWidth,
    gap: 1,
    paneWidth: paneWidth,
    divider: true,
  );
}

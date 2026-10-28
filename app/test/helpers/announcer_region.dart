import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// No platform announcements, as on Android: the app speaks through the
/// announcer's live region instead.
void useLiveRegionAnnouncements(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures();
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

/// The announcer's live region as a screen reader finds it in the
/// semantics tree; null while it is not part of the tree, e.g. under the
/// app lock.
SemanticsNode? announcerRegion(WidgetTester tester) {
  SemanticsNode? region;
  bool visit(SemanticsNode node) {
    final flags = node.getSemanticsData().flagsCollection;
    if (flags.isLiveRegion && flags.isAccessibilityFocusBlocked) {
      region = node;
    } else {
      node.visitChildren(visit);
    }
    return region == null;
  }

  for (final view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root);
  }
  return region;
}

/// How often a screen reader is told [text] over the frames [frames]
/// pumps, by each carrier: a platform announcement, the announcer's live
/// region, or another live region showing it, such as a field's error. A
/// live region counts each time it starts to say the text after a frame
/// in which no live region of its kind said it.
final class SpokenCount {
  new(this._tester, this.text) {
    _was = _saying();
  }

  final WidgetTester _tester;
  final String text;

  /// Whether the announcer's region and other live regions said it in the
  /// last frame.
  late ({bool region, bool others}) _was;
  var _announced = 0;
  var _byRegion = 0;
  var _byOthers = 0;

  int get times => _announced + _byRegion + _byOthers;

  int get announced => _announced;

  /// By the announcer's live region.
  int get byAnnouncerRegion => _byRegion;

  /// By the app's other live regions.
  int get byOtherLiveRegions => _byOthers;

  /// One frame every 16 ms for [duration], past a route's or an error's
  /// transition.
  Future<void> frames([
    Duration duration = const Duration(milliseconds: 800),
  ]) async {
    const frame = Duration(milliseconds: 16);
    for (var elapsed = Duration.zero; elapsed < duration; elapsed += frame) {
      await _tester.pump(frame);
      final now = _saying();
      if (now.region && !_was.region) _byRegion++;
      if (now.others && !_was.others) _byOthers++;
      _was = now;
      _announced += _tester
          .takeAnnouncements()
          .where((announcement) => announcement.message == text)
          .length;
    }
  }

  ({bool region, bool others}) _saying() {
    var region = false;
    var others = false;
    bool visit(SemanticsNode node) {
      final data = node.getSemanticsData();
      final flags = data.flagsCollection;
      if (flags.isLiveRegion && data.label == text) {
        if (flags.isAccessibilityFocusBlocked) {
          region = true;
        } else {
          others = true;
        }
      }
      node.visitChildren(visit);
      return true;
    }

    for (final view in _tester.binding.renderViews) {
      final root = view.owner?.semanticsOwner?.rootSemanticsNode;
      if (root != null) visit(root);
    }
    return (region: region, others: others);
  }
}

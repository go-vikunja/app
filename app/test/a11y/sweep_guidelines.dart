import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vikunja_mobile/features/home/presentation/account_header.dart';
import 'package:vikunja_mobile/features/tasks/presentation/task_detail_sheet.dart';

/// The nodes a screen reader can reach: neither merged into a parent, nor
/// hidden, nor of an empty size, which the engine drops.
Iterable<SemanticsNode> reachableNodes(WidgetTester tester) sync* {
  for (final view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) yield* _reachable(root);
  }
}

Iterable<SemanticsNode> _reachable(SemanticsNode node) sync* {
  if (node.isMergedIntoParent || node.isInvisible) return;
  if (!node.flagsCollection.isHidden) yield node;
  final children = <SemanticsNode>[];
  node.visitChildren((child) {
    children.add(child);
    return true;
  });
  for (final child in children) {
    yield* _reachable(child);
  }
}

String _describe(SemanticsNode node, SemanticsData data) {
  final name = accessibleName(data).replaceAll('\n', ' ');
  return 'SemanticsNode#${node.id} "$name" at ${node.rect}';
}

/// What a screen reader announces as the node's name: its label, then its
/// tooltip.
String accessibleName(SemanticsData data) => [
  data.label,
  data.tooltip,
].map((part) => part.trim()).where((part) => part.isNotEmpty).join('\n');

/// WCAG 2.5.8 (AA): the smallest target the yardstick allows.
const wcagMinimumTarget = Size(24, 24);

/// Android's 48 dp, except for the day cells of Flutter's Material date
/// picker, which the framework sizes to the dialog: 43.4 dp wide on a
/// 360 dp phone. They still meet [wcagMinimumTarget]; D68 lists them as a
/// deviation from Android's size.
final AccessibilityGuideline sweepAndroidTapTargetGuideline =
    _TapTargetGuideline(
      size: const Size(48, 48),
      link: 'https://support.google.com/accessibility/android/answer/7101858',
      nativeControl: (widget) => widget.runtimeType.toString() == '_DayPicker',
    );

/// Apple's 44 pt, except for the segments of Cupertino's sliding segmented
/// control, which keeps its native 28 pt height like UISegmentedControl's
/// 32 pt. They still meet [wcagMinimumTarget]; D68 lists them as a
/// deviation from Apple's size.
final AccessibilityGuideline sweepIOSTapTargetGuideline = _TapTargetGuideline(
  size: const Size(44, 44),
  link: 'https://developer.apple.com/design/human-interface-guidelines/buttons',
  nativeControl: (widget) => widget is CupertinoSlidingSegmentedControl,
);

final class _TapTargetGuideline extends MinimumTapTargetGuideline {
  new({required super.size, required super.link, required this.nativeControl});

  final bool Function(Widget widget) nativeControl;
  List<Rect> _nativeRects = const [];
  double _pixelRatio = 1;

  @override
  FutureOr<Evaluation> evaluate(WidgetTester tester) {
    _pixelRatio = tester.view.devicePixelRatio;
    _nativeRects = _drawnRects(find.byWidgetPredicate(nativeControl));
    return super.evaluate(tester);
  }

  @override
  bool shouldSkipNode(SemanticsNode node) {
    if (super.shouldSkipNode(node)) return true;
    if (_nativeRects.isEmpty) return false;
    final logical = _logicalRect(node, _pixelRatio);
    return logical.width >= wcagMinimumTarget.width &&
        logical.height >= wcagMinimumTarget.height &&
        _nativeRects.any((native) => _encloses(native, logical));
  }
}

/// Where [node] is on the screen, in logical pixels.
Rect _logicalRect(SemanticsNode node, double pixelRatio) {
  final rect = _globalRect(node);
  return Rect.fromLTRB(
    rect.left / pixelRatio,
    rect.top / pixelRatio,
    rect.right / pixelRatio,
    rect.bottom / pixelRatio,
  );
}

Rect _globalRect(SemanticsNode node) {
  var rect = node.rect;
  for (SemanticsNode? current = node; current != null;) {
    if (current.transform case final transform?) {
      rect = MatrixUtils.transformRect(transform, rect);
    }
    current = current.parent;
  }
  return rect;
}

/// Where the widgets [finder] finds are drawn, a pixel larger all round.
List<Rect> _drawnRects(Finder finder) => [
  for (final element in finder.evaluate())
    if (element.renderObject case final RenderBox box when box.hasSize)
      (box.localToGlobal(Offset.zero) & box.size).inflate(1),
];

bool _encloses(Rect outer, Rect inner) =>
    outer.contains(inner.topLeft) && outer.contains(inner.bottomRight);

/// Text contrast as Flutter checks it, with two differences.
///
/// Text that a scroll view cuts is skipped, as the tap target checks skip
/// a target at a scroll edge: the check samples the colours of the whole
/// text box, and the part the viewport hides shows something else. The
/// next scroll stop sees it whole.
///
/// The actions of an iOS alert are skipped: they keep Apple's system blue
/// and red on the alert's translucent material (3.0–4.4:1 measured), as
/// every iOS alert does, and turn to Apple's high-contrast variants under
/// Increase Contrast, which the app follows (decision 6). D68 lists this as
/// a deviation from 1.4.3.
final AccessibilityGuideline sweepTextContrastGuideline =
    _TextContrastGuideline();

final class _TextContrastGuideline extends MinimumTextContrastGuideline {
  Set<String> _skippedTexts = const {};

  @override
  Future<Evaluation> evaluate(WidgetTester tester) {
    final pixelRatio = tester.view.devicePixelRatio;
    _skippedTexts = {
      for (final node in reachableNodes(tester))
        for (final text in _texts(node.getSemanticsData()))
          if (_clipped(node, text, pixelRatio)) text,
      for (final element
          in find
              .descendant(
                of: find.byType(CupertinoDialogAction),
                matching: find.byType(Text),
              )
              .evaluate())
        ?(element.widget as Text).data,
    };
    return super.evaluate(tester);
  }

  @override
  bool shouldSkipNode(SemanticsData data) =>
      super.shouldSkipNode(data) || _texts(data).any(_skippedTexts.contains);

  static Iterable<String> _texts(SemanticsData data) =>
      [data.label, data.value].where((text) => text.trim().isNotEmpty);

  /// Whether the text's box reaches past its node, whose rect the
  /// semantics clip to what a scroll view shows.
  static bool _clipped(SemanticsNode node, String text, double pixelRatio) {
    final shown = _logicalRect(node, pixelRatio).inflate(1);
    for (final element in find.text(text).evaluate()) {
      if (element.renderObject case final RenderBox box when box.hasSize) {
        final drawn = box.localToGlobal(Offset.zero) & box.size;
        if (!drawn.overlaps(shown)) continue;
        if (!shown.contains(drawn.topLeft) ||
            !shown.contains(drawn.bottomRight)) {
          return true;
        }
      }
    }
    return false;
  }
}

/// Android and iOS make a node a heading only for a heading level above
/// zero; `header: true` alone gives TalkBack and VoiceOver nothing to
/// navigate by. The walk sees the framework's nodes too, such as an app
/// bar's title.
const AccessibilityGuideline headingLevelGuideline = _HeadingLevelGuideline();

/// A heading names what follows it and does nothing itself: Headings
/// navigation lands on it, and a double tap there should not open, add or
/// change anything. A group with a single tappable row would merge its
/// heading into that row (see `SectionSemantics`). Custom actions, such as
/// a board column's moves, count as nothing here: they are only reached
/// through the actions menu.
const AccessibilityGuideline headingNotControlGuideline =
    _HeadingNotControlGuideline();

/// The headings that are also the control they name, each with the
/// reason; every entry is also a deviation in D68.
final List<(Finder, String)> headingControls = [
  (
    find.byType(AccountHeader),
    "The Account tab's heading is the signed-in account, one button that "
        'opens its settings, labelled by the name and the line below it.',
  ),
  (
    find.descendant(
      of: find.byType(TaskDetailSheet),
      matching: find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_Title',
      ),
    ),
    "The task sheet's title is its level-1 heading and, where the task "
        'can be changed, opens the edit page, as a tap on it does.',
  ),
];

/// An image a screen reader stops at says what it shows.
const AccessibilityGuideline imageLabelGuideline = _ImageLabelGuideline();

/// The custom actions of a node (Move up, Move to a column…) each have a
/// label of their own. Identical labels cannot be told apart at all: the
/// framework keys an action by its label and keeps only one of them, so a
/// widget that builds two loses one before any check could see it.
const AccessibilityGuideline actionLabelGuideline = _ActionLabelGuideline();

/// Two controls on one screen announce the same name only when what
/// surrounds them tells them apart: the nearest ancestor with a label of
/// its own, such as the row a row's checkbox belongs to, or the heading
/// read before them, such as the section of each Remove button (WCAG
/// technique H80: the purpose from the text and the preceding heading).
const AccessibilityGuideline distinctTapLabelGuideline =
    _DistinctTapLabelGuideline();

final class _HeadingLevelGuideline extends AccessibilityGuideline {
  const new();

  @override
  String get description => 'Headings have a heading level from 1 to 6';

  @override
  FutureOr<Evaluation> evaluate(WidgetTester tester) {
    var result = const Evaluation.pass();
    for (final node in reachableNodes(tester)) {
      final data = node.getSemanticsData();
      if (!data.flagsCollection.isHeader) continue;
      if (data.headingLevel >= 1 && data.headingLevel <= 6) continue;
      result += Evaluation.fail(
        '${_describe(node, data)}: a header with heading level '
        '${data.headingLevel}, which TalkBack and VoiceOver do not take '
        'for a heading',
      );
    }
    return result;
  }
}

final class _HeadingNotControlGuideline extends AccessibilityGuideline {
  const new();

  @override
  String get description => 'Headings are no buttons';

  @override
  FutureOr<Evaluation> evaluate(WidgetTester tester) {
    final pixelRatio = tester.view.devicePixelRatio;
    final allowed = [
      for (final (finder, _) in headingControls) ..._drawnRects(finder),
    ];
    var result = const Evaluation.pass();
    for (final node in reachableNodes(tester)) {
      final data = node.getSemanticsData();
      if (data.headingLevel == 0 ||
          !data.hasAction(SemanticsAction.tap) &&
              !data.hasAction(SemanticsAction.longPress) &&
              !data.flagsCollection.isButton) {
        continue;
      }
      final rect = _logicalRect(node, pixelRatio);
      if (allowed.any((control) => _encloses(control, rect))) continue;
      result += Evaluation.fail(
        '${_describe(node, data)}: a level-${data.headingLevel} heading that '
        'is also a button, tapped or held through a double tap',
      );
    }
    return result;
  }
}

final class _ImageLabelGuideline extends AccessibilityGuideline {
  const new();

  @override
  String get description => 'Images have a label';

  @override
  FutureOr<Evaluation> evaluate(WidgetTester tester) {
    var result = const Evaluation.pass();
    for (final node in reachableNodes(tester)) {
      final data = node.getSemanticsData();
      if (!data.flagsCollection.isImage || accessibleName(data).isNotEmpty) {
        continue;
      }
      result += Evaluation.fail(
        '${_describe(node, data)}: an image without a label',
      );
    }
    return result;
  }
}

final class _ActionLabelGuideline extends AccessibilityGuideline {
  const new();

  @override
  String get description => 'Custom actions have distinct labels';

  @override
  FutureOr<Evaluation> evaluate(WidgetTester tester) {
    var result = const Evaluation.pass();
    for (final node in reachableNodes(tester)) {
      final data = node.getSemanticsData();
      final seen = <String>{};
      for (final id in data.customSemanticsActionIds ?? const <int>[]) {
        final action = CustomSemanticsAction.getAction(id);
        // A hint that replaces tap or long press is no action of its own.
        if (action == null || action.action != null) continue;
        final label = (action.label ?? '').trim();
        final key = label.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
        if (label.isEmpty) {
          result += Evaluation.fail(
            '${_describe(node, data)}: a custom action without a label',
          );
        } else if (!seen.add(key)) {
          result += Evaluation.fail(
            '${_describe(node, data)}: two custom actions read as "$label"',
          );
        }
      }
    }
    return result;
  }
}

const _sameListTwice =
    'The Projects tab lists a favourite saved filter in Favourites and again '
    'in Saved filters; both rows open the same list, so the same name keeps '
    'one purpose (WCAG 3.2.4), and the section headings tell them apart.';

/// Names (lines joined by a space) that may repeat on one screen in the
/// same context, each with the reason; every entry is also a deviation in
/// D68.
const Map<String, String> repeatableTapLabels = {
  'Urgent Favourite': _sameListTwice,
  'Urgent Favorit': _sameListTwice,
};

final class _DistinctTapLabelGuideline extends AccessibilityGuideline {
  const new();

  @override
  String get description =>
      'Controls that share a name differ in their labelled ancestor or '
      'their heading';

  @override
  FutureOr<Evaluation> evaluate(WidgetTester tester) {
    final byName = <(String, String, String), List<SemanticsNode>>{};
    var heading = '';
    void visit(SemanticsNode node) {
      if (node.isMergedIntoParent || node.isInvisible) return;
      final data = node.getSemanticsData();
      if (!node.flagsCollection.isHidden) {
        final name = accessibleName(data);
        if ((data.hasAction(SemanticsAction.tap) ||
                data.hasAction(SemanticsAction.longPress)) &&
            name.isNotEmpty &&
            !repeatableTapLabels.containsKey(name.replaceAll('\n', ' '))) {
          byName
              .putIfAbsent((name, _context(node), heading), () => [])
              .add(node);
        }
        if (data.headingLevel > 0) heading = data.label;
      }
      node
          .debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)
          .forEach(visit);
    }

    for (final view in tester.binding.renderViews) {
      final root = view.owner?.semanticsOwner?.rootSemanticsNode;
      if (root != null) visit(root);
    }
    var result = const Evaluation.pass();
    for (final MapEntry(key: (name, context, heading), value: nodes)
        in byName.entries) {
      if (nodes.length < 2) continue;
      final where = [
        if (context.isEmpty)
          'with no labelled ancestor'
        else
          'inside "${context.replaceAll('\n', ' ')}"',
        if (heading.isEmpty)
          'under no heading'
        else
          'under "${heading.replaceAll('\n', ' ')}"',
      ].join(' ');
      final ids = nodes.map((node) => 'SemanticsNode#${node.id}').join(', ');
      result += Evaluation.fail(
        '${nodes.length} controls read as "${name.replaceAll('\n', ' ')}" '
        '$where: $ids',
      );
    }
    return result;
  }

  static String _context(SemanticsNode node) {
    for (var parent = node.parent; parent != null; parent = parent.parent) {
      final label = parent.getSemanticsData().label.trim();
      if (label.isNotEmpty) return label;
    }
    return '';
  }
}

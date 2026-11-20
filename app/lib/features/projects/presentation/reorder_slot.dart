import 'package:material_ui/material_ui.dart';

/// Where a dragged row would go: a bar in the gap between two rows,
/// starting at [indent] to show the level it lands on and stopping [end]
/// before the far side.
class DropLine extends StatelessWidget {
  const new({this.indent = 16, this.end = 16, super.key});

  final double indent;
  final double end;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsetsDirectional.only(start: indent, end: end),
    child: SizedBox(
      height: 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );
}

/// Tells a list where a row is laid out, its context under [id] in
/// [slots], and keeps the row alive while [keepAlive], as a held row that
/// scrolls away must stay.
class SlotRegistration<K extends Object> extends StatefulWidget {
  const new({
    required this.id,
    required this.slots,
    required this.keepAlive,
    required this.child,
    super.key,
  });

  final K id;
  final Map<K, BuildContext> slots;
  final bool keepAlive;
  final Widget child;

  @override
  State<SlotRegistration<K>> createState() => _SlotRegistrationState<K>();
}

class _SlotRegistrationState<K extends Object>
    extends State<SlotRegistration<K>>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  void initState() {
    super.initState();
    widget.slots[widget.id] = context;
  }

  @override
  void didUpdateWidget(SlotRegistration<K> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id ||
        !identical(oldWidget.slots, widget.slots)) {
      _unregister(oldWidget);
      widget.slots[widget.id] = context;
    }
    if (oldWidget.keepAlive != widget.keepAlive) updateKeepAlive();
  }

  @override
  void dispose() {
    _unregister(widget);
    super.dispose();
  }

  void _unregister(SlotRegistration<K> slot) {
    if (identical(slot.slots[slot.id], context)) slot.slots.remove(slot.id);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

/// A row's place in a list whose rows can be dragged ([SlotRegistration]):
/// fades it while it is held, and paints the drop line into the gap above
/// or below it, or tints and outlines a row a drop goes into, without
/// moving any row.
class ReorderSlot<K extends Object> extends StatelessWidget {
  const new({
    required this.id,
    required this.slots,
    required this.child,
    this.held = false,
    this.lineAbove,
    this.lineBelow,
    this.dropsInto = false,
    super.key,
  });

  final K id;
  final Map<K, BuildContext> slots;
  final Widget child;
  final bool held;

  /// The indent of the drop line above or below the row; null for none.
  final double? lineAbove;
  final double? lineBelow;
  final bool dropsInto;

  @override
  Widget build(BuildContext context) {
    final lineAbove = this.lineAbove;
    final lineBelow = this.lineBelow;
    final colors = Theme.of(context).colorScheme;
    return SlotRegistration(
      id: id,
      slots: slots,
      keepAlive: held,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          // Both always there, so that holding the row keeps its subtree.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: dropsInto ? colors.primaryContainer : null,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          Opacity(opacity: held ? 0.4 : 1, child: child),
          if (dropsInto)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: colors.primary, width: 2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          if (lineAbove != null)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: DropLine(indent: lineAbove),
            ),
          if (lineBelow != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: DropLine(indent: lineBelow),
            ),
        ],
      ),
    );
  }
}

/// Scrolls a scroll view while a dragged pointer is within [edge] of its
/// start or end, along the scroll view's axis; [onScrolled] runs after each
/// step, as the rows move under a pointer that holds still.
final class DragEdgeScroller {
  new({required this.onScrolled, this.edge = 56});

  final VoidCallback onScrolled;
  final double edge;
  EdgeDraggingAutoScroller? _scroller;

  /// For the scroll view around [inside].
  void follow(BuildContext? inside, Offset pointer) => _follow(
    inside == null || !inside.mounted
        ? null
        : inside.findAncestorStateOfType<ScrollableState>(),
    pointer,
  );

  /// For the scroll view [controller] drives.
  void followController(ScrollController controller, Offset pointer) {
    if (!controller.hasClients) return;
    _follow(switch (controller.position.context) {
      final ScrollableState state => state,
      _ => null,
    }, pointer);
  }

  void _follow(ScrollableState? scrollable, Offset pointer) {
    if (scrollable == null) return;
    if (_scroller?.scrollable != scrollable) {
      _scroller?.stopAutoScroll();
      _scroller = EdgeDraggingAutoScroller(
        scrollable,
        onScrollViewScrolled: onScrolled,
        velocityScalar: 50,
      );
    }
    final position = scrollable.position;
    final viewport = position.viewportDimension;
    final extent = viewport < edge * 2 ? viewport : edge * 2;
    final vertical = position.axis == Axis.vertical;
    _scroller!.startAutoScrollIfNecessary(
      Rect.fromCenter(
        center: pointer,
        width: vertical ? 1 : extent,
        height: vertical ? extent : 1,
      ),
    );
  }

  void stop() {
    _scroller?.stopAutoScroll();
    _scroller = null;
  }
}

/// Hangs the lifted rows ([LiftedRows]) a grabbed row's height above the
/// finger, where they hide neither the drop line nor the outline of the
/// row a drop goes into, both drawn next to the finger.
Offset liftedAboveFinger(
  Draggable<Object> draggable,
  BuildContext context,
  Offset position,
) {
  final row = context.findRenderObject()! as RenderBox;
  return Offset(row.globalToLocal(position).dx, row.size.height);
}

class LiftedRows extends StatelessWidget {
  const new({required this.width, required this.child, super.key});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      width: width,
      // Up by its own height, so that with [liftedAboveFinger] its bottom
      // edge is a grabbed row's height above the finger: a group with
      // subtasks is taller than the row grabbed.
      child: FractionalTranslation(
        translation: const Offset(0, -1),
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
      ),
    ),
  );
}

/// Keeps a long press on the buttons of a row that can be lifted from
/// showing their tooltips, so that it lifts the row there too; the
/// tooltips still name the buttons for screen readers.
class LiftableRow extends StatelessWidget {
  const new({required this.child, this.liftable = true, super.key});

  final Widget child;
  final bool liftable;

  @override
  Widget build(BuildContext context) {
    final tooltips = TooltipTheme.of(context);
    return TooltipTheme(
      data: liftable
          ? tooltips.copyWith(triggerMode: TooltipTriggerMode.manual)
          : tooltips,
      child: child,
    );
  }
}

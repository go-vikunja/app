import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/layout/window_layout.dart';

final class AdaptiveDestination {
  const new({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.dot,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// A dot on the icon, such as for unread activity, and what screen
  /// readers hear for it after the label; null for none.
  final String? dot;

  Widget iconFor(BuildContext context, {required bool selected}) {
    final icon = Icon(selected ? selectedIcon : this.icon);
    final dot = this.dot;
    if (dot == null) return icon;
    // Read after the label: Android reads a hint last, iOS a value next.
    final apple = switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
    return Semantics(
      value: apple ? dot : null,
      hint: apple ? null : dot,
      child: Badge(child: icon),
    );
  }
}

/// Whether the destinations go into an [AdaptiveNavigationRail] beside the
/// content instead of an [AdaptiveNavigationBar] below it: in wide windows
/// (a tablet, a phone in landscape) except on Apple platforms, which keep
/// their tab bar.
bool usesNavigationRail(BuildContext context) =>
    switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => false,
      _ => WindowLayout.of(context).sizeClass != WindowSizeClass.compact,
    };

/// A Material 3 navigation bar, or the Cupertino tab bar on Apple platforms.
class AdaptiveNavigationBar extends StatelessWidget {
  const new({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    super.key,
  });

  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    // Both bars have a fixed height; the labels scale a little, not twice.
    return switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => _LargeLabels(
        destinations: destinations,
        onDestinationSelected: onDestinationSelected,
        maxBarScale: 1.3,
        labelSize:
            CupertinoTheme.of(context).textTheme.tabLabelTextStyle.fontSize ??
            10,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: CupertinoTabBar(
            currentIndex: selectedIndex,
            onTap: onDestinationSelected,
            // Cupertino's inactive grey reads at 2.7:1 on the bar.
            inactiveColor: Theme.of(context).colorScheme.onSurfaceVariant,
            items: [
              for (final destination in destinations)
                BottomNavigationBarItem(
                  icon: destination.iconFor(context, selected: false),
                  activeIcon: destination.iconFor(context, selected: true),
                  label: destination.label,
                ),
            ],
          ),
        ),
      ),
      // Up to this scale the longest label, bold when selected, keeps to one
      // line in a quarter of a 320 dp phone; a wrapped one would push its
      // indicator out of line with the others.
      _ => _LargeLabels(
        destinations: destinations,
        onDestinationSelected: onDestinationSelected,
        maxBarScale: 1.15,
        labelSize: _materialLabelSize(context),
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.15,
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            destinations: [
              for (final destination in destinations)
                NavigationDestination(
                  icon: destination.iconFor(context, selected: false),
                  selectedIcon: destination.iconFor(context, selected: true),
                  label: destination.label,
                  // Its tooltip would show the label at the bar's size.
                  tooltip: _beyond(context, 1.15, _materialLabelSize(context))
                      ? ''
                      : null,
                ),
            ],
          ),
        ),
      ),
    };
  }
}

/// A Material 3 navigation rail with every label shown, for wide windows,
/// with [leading] above the destinations, such as a floating button.
class AdaptiveNavigationRail extends StatelessWidget {
  const new({
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.leading,
    super.key,
  });

  final List<AdaptiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    // Like the bar's: longer labels would widen the rail into the content.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: NavigationRail(
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
        labelType: NavigationRailLabelType.all,
        // A phone in landscape is short.
        scrollable: true,
        leading: leading,
        destinations: [
          for (final destination in destinations)
            NavigationRailDestination(
              icon: destination.iconFor(context, selected: false),
              selectedIcon: destination.iconFor(context, selected: true),
              label: Text(destination.label),
            ),
        ],
      ),
    );
  }
}

// At the label's own size: Android 14 and later scale small text more than
// large text, and 100 sp not at all. Android computes in float, so the bar's
// own 115 % comes out a hair above 1.15 times the size.
bool _beyond(BuildContext context, double maxBarScale, double labelSize) =>
    MediaQuery.textScalerOf(context).scale(labelSize) >
    labelSize * maxBarScale + 0.01;

double _materialLabelSize(BuildContext context) =>
    Theme.of(context).textTheme.labelMedium?.fontSize ?? 12;

/// At a text size the bar does not follow, a long press shows the
/// destination's icon and label at the full size in the middle of the
/// screen, and lifting the finger opens it, as UIKit's large content viewer
/// does for tab bars; on Android too, whose tooltips keep the bar's size.
class _LargeLabels extends StatefulWidget {
  const new({
    required this.destinations,
    required this.onDestinationSelected,
    required this.maxBarScale,
    required this.labelSize,
    required this.child,
  });

  final List<AdaptiveDestination> destinations;
  final ValueChanged<int> onDestinationSelected;
  final double maxBarScale;
  final double labelSize;
  final Widget child;

  @override
  State<_LargeLabels> createState() => _LargeLabelsState();
}

class _LargeLabelsState extends State<_LargeLabels> {
  OverlayEntry? _entry;
  int? _shown;

  @override
  void dispose() {
    _hide();
    super.dispose();
  }

  int _indexAt(Offset position, double width) {
    final count = widget.destinations.length;
    return (position.dx / (width / count)).floor().clamp(0, count - 1);
  }

  void _show(int index) {
    if (_shown == index) return;
    _hide();
    _shown = index;
    final destination = widget.destinations[index];
    final entry = _entry = OverlayEntry(
      builder: (context) => Center(
        child: IgnorePointer(child: _LargeLabel(destination: destination)),
      ),
    );
    Overlay.of(context).insert(entry);
  }

  void _hide() {
    _entry?.remove();
    _entry = null;
    _shown = null;
  }

  @override
  Widget build(BuildContext context) {
    if (!_beyond(context, widget.maxBarScale, widget.labelSize)) {
      return widget.child;
    }
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        // Screen readers read the labels already.
        excludeFromSemantics: true,
        onLongPressStart: (details) =>
            _show(_indexAt(details.localPosition, constraints.maxWidth)),
        onLongPressMoveUpdate: (details) =>
            _show(_indexAt(details.localPosition, constraints.maxWidth)),
        onLongPressEnd: (details) {
          final index = _indexAt(details.localPosition, constraints.maxWidth);
          _hide();
          widget.onDestinationSelected(index);
        },
        onLongPressCancel: _hide,
        child: widget.child,
      ),
    );
  }
}

class _LargeLabel extends StatelessWidget {
  const new({required this.destination});

  final AdaptiveDestination destination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(destination.icon, size: 48),
              const SizedBox(height: 8),
              Text(
                destination.label,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';

final class AdaptiveDestination {
  const new({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

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
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: switch (Theme.of(context).platform) {
        TargetPlatform.iOS || TargetPlatform.macOS => CupertinoTabBar(
          currentIndex: selectedIndex,
          onTap: onDestinationSelected,
          items: [
            for (final destination in destinations)
              BottomNavigationBarItem(
                icon: Icon(destination.icon),
                activeIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
          ],
        ),
        _ => NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: onDestinationSelected,
          destinations: [
            for (final destination in destinations)
              NavigationDestination(
                icon: Icon(destination.icon),
                selectedIcon: Icon(destination.selectedIcon),
                label: destination.label,
              ),
          ],
        ),
      },
    );
  }
}

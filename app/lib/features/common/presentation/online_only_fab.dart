import 'package:material_ui/material_ui.dart';

/// The floating button of a page over the shell for a change that needs
/// the server: offline it stays visible but dimmed, with [offlineReason]
/// as its tooltip.
class OnlineOnlyFab extends StatelessWidget {
  const new({
    required this.icon,
    required this.label,
    required this.offline,
    required this.offlineReason,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool offline;
  final String offlineReason;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FloatingActionButton.extended(
      // Every tab's top route stays below this page with its own button.
      heroTag: null,
      tooltip: offline ? offlineReason : null,
      onPressed: offline ? null : onPressed,
      backgroundColor: offline
          ? colors.onSurface.withValues(alpha: 0.12)
          : null,
      foregroundColor: offline
          ? colors.onSurface.withValues(alpha: 0.38)
          : null,
      elevation: offline ? 0 : null,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

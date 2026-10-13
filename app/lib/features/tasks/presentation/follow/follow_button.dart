import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/presentation/follow/follow_controller.dart';

/// The detail sheet's bell: on while the user follows the task, through
/// its own subscription or its project's, off while not. While the state
/// is unknown (loading, offline, a task not yet synced) it is a dimmed
/// plain button, not an unselected toggle, and tells on tap why.
class FollowButton extends StatelessWidget {
  const new({required this.state, required this.onPressed, super.key});

  final FollowState state;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final following = switch (state) {
      FollowKnown(:final following) => following,
      FollowUnknown() => null,
    };
    final busy = switch (state) {
      FollowUnknown(:final loading) => loading,
      FollowKnown(:final saving) => saving,
    };
    return IconButton(
      onPressed: busy ? null : onPressed,
      tooltip: switch (state) {
        FollowUnknown(loading: true) => l10n.followChecking,
        FollowUnknown() => l10n.followTaskUnavailable,
        FollowKnown(following: true) => l10n.unfollowTask,
        FollowKnown() => l10n.followTask,
      },
      isSelected: following,
      icon: Icon(
        Icons.notifications_none,
        color: state is FollowUnknown
            ? colors.onSurfaceVariant.withValues(alpha: 0.5)
            : null,
      ),
      selectedIcon: Icon(Icons.notifications_active, color: colors.primary),
    );
  }
}

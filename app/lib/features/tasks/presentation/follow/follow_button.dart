import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/presentation/follow/follow_controller.dart';

/// The detail sheet's bell: on while the user follows the task, through
/// its own subscription or its project's, off while not. While the state
/// is unknown (loading, offline, a task not yet synced) it is a dimmed
/// plain button, not an unselected toggle, and tells on tap why. On a
/// [fixed] follow through the project a tap tells how to stop it.
class FollowButton extends StatelessWidget {
  const new({
    required this.state,
    required this.onPressed,
    this.fixed = false,
    super.key,
  });

  final FollowState state;
  final VoidCallback? onPressed;

  /// See [FollowController.fixed].
  final bool fixed;

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
        FollowKnown(following: true) when fixed => l10n.followingViaSomeProject,
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

/// That the user follows the task through a project's subscription, named
/// by [projectTitles] when they hold it; nothing otherwise.
class InheritedFollowNote extends StatelessWidget {
  const new({
    required this.follow,
    required this.taskId,
    required this.projectTitles,
    super.key,
  });

  final FollowController follow;
  final int taskId;
  final Map<int, String> projectTitles;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: follow,
    builder: (context, state, _) => switch (state) {
      FollowKnown(:final subscription?)
          when taskId > 0 && follow.inherits(subscription) =>
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _InheritedFollowNote(
            projectTitle: projectTitles[subscription.entityId],
          ),
        ),
      _ => const SizedBox.shrink(),
    },
  );
}

class _InheritedFollowNote extends StatelessWidget {
  const new({required this.projectTitle});

  final String? projectTitle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final style = theme.textTheme.bodySmall?.copyWith(
      color: colors.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.notifications_active_outlined,
            size: 16,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(switch (projectTitle) {
              final title? => l10n.followingViaProject(title),
              null => l10n.followingViaSomeProject,
            }, style: style),
          ),
        ],
      ),
    );
  }
}

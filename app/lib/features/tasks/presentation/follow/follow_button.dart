import 'package:material_ui/material_ui.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/features/tasks/presentation/follow/follow_controller.dart';

/// The detail sheet's bell: on while the user follows the task, through
/// its own subscription or its project's, off while not; a screen reader
/// hears a switch of the fixed name "Follow task", while the tooltip names
/// what a tap does. While the state is unknown (loading, offline, a task
/// not yet synced) it is a dimmed plain button, not an unselected toggle,
/// and tells on tap why. On a [fixed] follow through the project a tap
/// tells how to stop it.
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
    final button = IconButton(
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
    if (following == null) return button;
    // The button's own semantics would add its tooltip, which flips with
    // the state, and a selected state besides the toggled one.
    return Semantics(
      container: true,
      button: true,
      enabled: !busy && onPressed != null,
      toggled: following,
      label: l10n.followTask,
      onTap: busy ? null : onPressed,
      excludeSemantics: true,
      child: button,
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

/// Under the reminders of a task the user does not follow, on a server that
/// reminds only its followers: that they won't notify, and a button
/// that follows it. Nothing while the user follows it or it is unknown.
class UnfollowedRemindersNote extends StatelessWidget {
  const new({required this.follow, required this.onFollow, super.key});

  final FollowController follow;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: follow,
    builder: (context, state, _) => switch (state) {
      FollowKnown(subscription: null, :final saving) => _UnfollowedNote(
        onFollow: saving ? null : onFollow,
      ),
      _ => const SizedBox.shrink(),
    },
  );
}

class _UnfollowedNote extends StatelessWidget {
  const new({required this.onFollow});

  final VoidCallback? onFollow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    // Lines up with the rows' icons and names above it.
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 8, 4),
      child: Row(
        children: [
          Icon(Icons.notifications_off_outlined, size: 20, color: muted),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              l10n.taskRemindersNotFollowed,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onFollow, child: Text(l10n.followTask)),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/user_avatar.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comments_controller.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/details_notice.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/reaction_chips.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/rich_html.dart';

/// The rows of the comments section, for the sheet's list to build lazily:
/// the heading with the count, then "Show comments" until the first page
/// arrives, then the order toggle, the comments, and "Load more" while
/// pages remain. A button stays in place, disabled, while its page loads.
List<Widget> commentsSection({
  required int count,
  required CommentsState state,
  required CommentsController controller,
  required ValueChanged<String> onLink,
  required ValueChanged<int> onTaskLink,
  required int projectId,
}) {
  final authors = {
    for (final comment in state.comments) comment.id: comment.author,
  };
  return [
    _CommentsHeader(count: count, state: state, controller: controller),
    if (!state.shown)
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: _ShowCommentsButton(
          onPressed: state.loading ? null : controller.show,
        ),
      ),
    for (final comment in state.comments)
      CommentTile(
        key: ValueKey(('comment', comment.id)),
        comment: comment,
        onLink: onLink,
        onTaskLink: onTaskLink,
        projectId: projectId,
        replyAuthorOf: (id) => authors[id],
      ),
    if (state.shown && state.loading && !state.hasMore)
      const _CommentsLoading(),
    if (state.shown && !state.loading && state.failure != null)
      DetailsNotice(
        text: (l10n) => commentsFailureText(l10n, state.failure!),
        onRetry: () => unawaited(controller.retry()),
      ),
    if (state.shown && state.failure == null && state.hasMore)
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: _MoreCommentsButton(
          onPressed: state.loading ? null : controller.loadMore,
        ),
      ),
  ];
}

String commentsFailureText(AppLocalizations l10n, Object failure) =>
    failure is NetworkFailure
    ? l10n.commentsNeedConnection
    : l10n.commentsFailed;

/// What a screen reader hears once a page the user asked for arrived or
/// failed: the buttons that asked may be gone by then.
String? commentsResultAnnouncement(
  AppLocalizations l10n, {
  required CommentsState before,
  required CommentsState after,
}) {
  if (!before.loading || after.loading) return null;
  if (after.failure case final failure?) {
    return commentsFailureText(l10n, failure);
  }
  final known = {for (final comment in before.comments) comment.id};
  return l10n.commentsLoaded(
    after.comments.where((comment) => !known.contains(comment.id)).length,
  );
}

class _CommentsHeader extends StatelessWidget {
  const new({
    required this.count,
    required this.state,
    required this.controller,
  });

  final int count;
  final CommentsState state;
  final CommentsController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.taskDetailComments(count),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          if (state.shown)
            Semantics(
              hint: l10n.commentsChangeOrder,
              child: TextButton.icon(
                onPressed: () => unawaited(controller.toggleOrder()),
                icon: const Icon(Icons.swap_vert),
                label: Text(
                  state.newestFirst
                      ? l10n.commentsNewestFirst
                      : l10n.commentsOldestFirst,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Null [onPressed] while its page loads: disabled, with a spinner.
class _ShowCommentsButton extends StatelessWidget {
  const new({required this.onPressed});

  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: switch (onPressed) {
      final show? => () => unawaited(show()),
      null => null,
    },
    icon: onPressed == null
        ? const _ButtonSpinner()
        : const Icon(Icons.forum_outlined),
    label: Text(context.l10n.taskDetailShowComments),
  );
}

class _MoreCommentsButton extends StatelessWidget {
  const new({required this.onPressed});

  final Future<void> Function()? onPressed;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: switch (onPressed) {
      final loadMore? => () => unawaited(loadMore()),
      null => null,
    },
    icon: onPressed == null
        ? const _ButtonSpinner()
        : const Icon(Icons.expand_more),
    label: Text(context.l10n.taskDetailMoreComments),
  );
}

class _ButtonSpinner extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) => const SizedBox.square(
    dimension: 16,
    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
  );
}

class _CommentsLoading extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              context.l10n.commentsLoading,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A comment: the author's avatar and name, when it was written and
/// whether it was edited, the text and its reactions.
class CommentTile extends ConsumerWidget {
  const new({
    required this.comment,
    required this.onLink,
    required this.onTaskLink,
    required this.replyAuthorOf,
    this.projectId,
    super.key,
  });

  final TaskComment comment;
  final ValueChanged<String> onLink;
  final ValueChanged<int> onTaskLink;
  final User? Function(int commentId) replyAuthorOf;
  final int? projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final now = ref.watch(clockTickProvider);
    final formatter = MomentFormatter.watch(context, ref);
    String spoken(DateTime moment) =>
        formatter.semanticsLabel(moment) ?? formatter.absolute(moment);
    final created = comment.created;
    final updated = comment.updated;
    final when = [
      if (created != null) formatter.relative(created, now: now),
      if (comment.isEdited && updated != null)
        l10n.commentEdited(formatter.relative(updated, now: now)),
    ].join(' · ');
    final whenLabel = [
      if (created != null) spoken(created),
      if (comment.isEdited && updated != null)
        l10n.commentEdited(spoken(updated)),
    ].join(', ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(user: comment.author, radius: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 4,
              children: [
                MergeSemantics(
                  child: Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        comment.author.displayName,
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (when.isNotEmpty)
                        Semantics(
                          label: whenLabel,
                          excludeSemantics: true,
                          child: Text(
                            when,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SelectionArea(
                  child: RichHtml(
                    html: comment.html,
                    onLink: onLink,
                    onTaskLink: onTaskLink,
                    projectId: projectId,
                    replyAuthorOf: replyAuthorOf,
                  ),
                ),
                if (comment.reactions.isNotEmpty)
                  ReactionChips(reactions: comment.reactions),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

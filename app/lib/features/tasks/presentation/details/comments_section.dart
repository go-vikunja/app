import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/time/clock_tick_provider.dart';
import 'package:vikunja_mobile/features/common/presentation/section_card.dart';
import 'package:vikunja_mobile/features/common/presentation/user_avatar.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/comments_controller.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/detail_section_header.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/details_notice.dart';
import 'package:vikunja_mobile/features/tasks/presentation/details/reaction_chips.dart';
import 'package:vikunja_mobile/features/tasks/presentation/moment_formatter.dart';
import 'package:vikunja_mobile/features/tasks/presentation/rich_text/rich_html.dart';

/// What the user may do with the comments; [onReply] and the reaction
/// callbacks are null where the task can only be read, and [onEdit] and
/// [onDelete] apply to the comments of [me] alone. [offline] shows what
/// needs the server disabled.
@immutable
final class CommentActions {
  const new({
    required this.me,
    required this.onCopyLink,
    this.offline = false,
    this.onReply,
    this.onEdit,
    this.onDelete,
    this.onToggleReaction,
    this.onAddReaction,
    this.busy = const {},
    this.pendingReactions = const {},
  });

  final int? me;
  final bool offline;
  final ValueChanged<TaskComment>? onCopyLink;
  final ValueChanged<TaskComment>? onReply;
  final ValueChanged<TaskComment>? onEdit;
  final ValueChanged<TaskComment>? onDelete;
  final void Function(TaskComment comment, String reaction)? onToggleReaction;
  final ValueChanged<TaskComment>? onAddReaction;

  /// Comments whose edit or deletion is on the way.
  final Set<int> busy;

  /// Per comment, the reactions waiting for the server.
  final Map<int, Set<String>> pendingReactions;
}

/// The rows of the comments section, for the sheet's list to build lazily:
/// the heading with the count, "No comments yet" for none, else "Show
/// comments" until the first page arrives, then the order toggle, the
/// comments, and "Load more" while pages remain. A button stays in place,
/// disabled, while its page loads. [keyOf] gives a comment's row the key
/// the sheet scrolls to it by; [highlighted] is tinted for a moment.
List<Widget> commentsSection({
  required int count,
  required CommentsState state,
  required CommentsController controller,
  required ValueChanged<String> onLink,
  required ValueChanged<int> onTaskLink,
  required int projectId,
  required CommentActions actions,
  Key? headerKey,
  Key Function(int commentId)? keyOf,
  int? highlighted,
}) {
  final authors = {
    for (final comment in state.comments) comment.id: comment.author,
  };
  final comments = state.comments;
  return [
    _CommentsHeader(
      key: headerKey,
      count: count,
      state: state,
      controller: controller,
    ),
    if (comments.isEmpty && count == 0 && !state.loading)
      const _Inset(child: _NoComments())
    else if (!state.shown)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: _ShowCommentsButton(
            onPressed: state.loading ? null : controller.show,
          ),
        ),
      ),
    for (final (index, comment) in comments.indexed)
      Padding(
        key: ValueKey(('comment', comment.id)),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SectionCardItem(
          first: index == 0,
          last: index == comments.length - 1,
          child: CommentTile(
            key: keyOf?.call(comment.id),
            comment: comment,
            onLink: onLink,
            onTaskLink: onTaskLink,
            projectId: projectId,
            replyAuthorOf: (id) => authors[id],
            actions: actions,
            highlighted: comment.id == highlighted,
          ),
        ),
      ),
    if (state.shown && state.loading && !state.hasMore)
      const _Inset(child: _CommentsLoading()),
    if (state.shown && !state.loading && state.failure != null)
      _Inset(
        child: DetailsNotice(
          text: (l10n) => commentsFailureText(l10n, state.failure!),
          onRetry: () => unawaited(controller.retry()),
        ),
      ),
    if (state.shown && state.failure == null && state.hasMore)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: _MoreCommentsButton(
            onPressed: state.loading ? null : controller.loadMore,
          ),
        ),
      ),
  ];
}

class _Inset extends StatelessWidget {
  const new({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: child,
  );
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
    super.key,
  });

  final int count;
  final CommentsState state;
  final CommentsController controller;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DetailSectionHeader(
      title: count > 0 ? l10n.taskDetailComments(count) : l10n.commentsHeading,
      trailing: state.shown && state.comments.isNotEmpty
          ? Semantics(
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
            )
          : null,
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

class _NoComments extends StatelessWidget {
  const new();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Text(
        context.l10n.commentsEmpty,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
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

enum _CommentAction { reply, copyLink, edit, delete }

/// A comment: the author's avatar and name, when it was written and
/// whether it was edited, its menu, the text and its reactions.
class CommentTile extends ConsumerWidget {
  const new({
    required this.comment,
    required this.onLink,
    required this.onTaskLink,
    required this.replyAuthorOf,
    this.projectId,
    this.actions,
    this.highlighted = false,
    super.key,
  });

  final TaskComment comment;
  final ValueChanged<String> onLink;
  final ValueChanged<int> onTaskLink;
  final User? Function(int commentId) replyAuthorOf;
  final int? projectId;

  /// Null shows the comment alone, without a menu or reactions to change.
  final CommentActions? actions;

  /// Tinted, for a comment a notification opened the task at.
  final bool highlighted;

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
    final actions = this.actions;
    final busy = actions?.busy.contains(comment.id) ?? false;
    final own = actions != null && comment.author.id == actions.me;
    final menu = [
      if (actions?.onReply != null) _CommentAction.reply,
      if (actions?.onCopyLink != null) _CommentAction.copyLink,
      if (own && actions.onEdit != null) _CommentAction.edit,
      if (own && actions.onDelete != null) _CommentAction.delete,
    ];
    final onToggle = actions?.onToggleReaction;
    final onAdd = actions?.onAddReaction;
    // The menu's 48 dp start at the tile's top, its icon on the line of
    // the name; the rest keeps the inset.
    final top = EdgeInsets.only(top: menu.isEmpty ? 0 : 12);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: highlighted
          ? colors.primaryContainer.withValues(alpha: 0.6)
          : Colors.transparent,
      padding: EdgeInsetsDirectional.fromSTEB(
        16,
        menu.isEmpty ? 12 : 0,
        menu.isEmpty ? 16 : 4,
        4,
      ),
      child: Semantics(
        hint: busy ? l10n.commentWorking : null,
        child: Opacity(
          opacity: busy ? 0.5 : 1,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: top,
                child: UserAvatar(user: comment.author, radius: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: top,
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
                      ReactionChips(
                        reactions: comment.reactions,
                        offline: actions?.offline ?? false,
                        onToggle: onToggle == null || busy
                            ? null
                            : (reaction) => onToggle(comment, reaction),
                        onAdd: onAdd == null || busy
                            ? null
                            : () => onAdd(comment),
                        pending:
                            actions?.pendingReactions[comment.id] ?? const {},
                      ),
                      if (comment.reactions.isEmpty && onAdd == null)
                        const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              if (menu.isNotEmpty)
                _CommentMenu(
                  comment: comment,
                  items: menu,
                  enabled: !busy,
                  actions: actions!,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommentMenu extends StatelessWidget {
  const new({
    required this.comment,
    required this.items,
    required this.enabled,
    required this.actions,
  });

  final TaskComment comment;
  final List<_CommentAction> items;
  final bool enabled;
  final CommentActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return PopupMenuButton<_CommentAction>(
      tooltip: l10n.commentOptions(comment.author.displayName),
      enabled: enabled,
      icon: const Icon(Icons.more_vert),
      onSelected: (action) => switch (action) {
        _CommentAction.reply => actions.onReply?.call(comment),
        _CommentAction.copyLink => actions.onCopyLink?.call(comment),
        _CommentAction.edit => actions.onEdit?.call(comment),
        _CommentAction.delete => actions.onDelete?.call(comment),
      },
      itemBuilder: (context) => [
        for (final action in items)
          PopupMenuItem(
            value: action,
            enabled:
                !actions.offline ||
                action == _CommentAction.reply ||
                action == _CommentAction.copyLink,
            child: Row(
              children: [
                Icon(
                  switch (action) {
                    _CommentAction.reply => Icons.reply,
                    _CommentAction.copyLink => Icons.link,
                    _CommentAction.edit => Icons.edit_outlined,
                    _CommentAction.delete => Icons.delete_outline,
                  },
                  color: action == _CommentAction.delete ? colors.error : null,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    switch (action) {
                      _CommentAction.reply => l10n.commentReply,
                      _CommentAction.copyLink => l10n.commentCopyLink,
                      _CommentAction.edit => l10n.commentEdit,
                      _CommentAction.delete => l10n.commentDelete,
                    },
                    style: action == _CommentAction.delete
                        ? TextStyle(color: colors.error)
                        : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

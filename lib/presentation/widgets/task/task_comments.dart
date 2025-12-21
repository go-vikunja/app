import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:intl/intl.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/utils/user_extensions.dart';
import 'package:vikunja_app/domain/entities/task_comment.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/manager/task_comments_controller.dart';
import 'package:vikunja_app/presentation/pages/task/comment_edit_page.dart';

class TaskComments extends ConsumerWidget {
  final int taskId;

  const TaskComments({super.key, required this.taskId});

  Future<void> _navigateToCreatePage(BuildContext context, int taskId) async {
    await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => CommentEditPage(taskId: taskId)),
    );
  }

  Future<void> _navigateToEditPage(
    BuildContext context,
    int taskId,
    TaskComment comment,
  ) async {
    await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => CommentEditPage(taskId: taskId, comment: comment),
      ),
    );
  }

  Future<void> _deleteComment(
    BuildContext context,
    WidgetRef ref,
    int taskId,
    TaskComment comment,
  ) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteCommentTitle),
        content: Text(l10n.deleteCommentConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Check context is still valid after dialog
    if (!context.mounted) return;

    final success = await ref
        .read(taskCommentsControllerProvider(taskId).notifier)
        .deleteComment(comment.id);

    if (!success) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.commentDeleteError)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final commentsAsync = ref.watch(taskCommentsControllerProvider(taskId));
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Text(
                l10n.comments,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              IconButton(
                icon: const Icon(Icons.add),
                iconSize: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _navigateToCreatePage(context, taskId),
                tooltip: l10n.addCommentTooltip,
              ),
            ],
          ),
        ),
        commentsAsync.when(
          data: (comments) => _buildCommentsList(context, ref, comments),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text(
            l10n.commentsLoadError,
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }

  Widget _buildCommentsList(
    BuildContext context,
    WidgetRef ref,
    List<TaskComment> comments,
  ) {
    if (comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          AppLocalizations.of(context).noComments,
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: comments.length,
      itemBuilder: (context, index) =>
          _buildCommentItem(context, ref, comments[index]),
    );
  }

  Widget _buildCommentItem(
    BuildContext context,
    WidgetRef ref,
    TaskComment comment,
  ) {
    final currentUser = ref.read(currentUserProvider);
    final isOwner = currentUser?.id == comment.author.id;
    final dateFormat = DateFormat.yMd().add_jm();
    final l10n = AppLocalizations.of(context);
    final isEdited = comment.updated.isAfter(comment.created);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  comment.author.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (isOwner)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _navigateToEditPage(context, taskId, comment);
                      } else if (value == 'delete') {
                        _deleteComment(context, ref, taskId, comment);
                      }
                    },
                    itemBuilder: (context) {
                      final l10n = AppLocalizations.of(context);
                      return [
                        PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(l10n.delete),
                        ),
                      ];
                    },
                  ),
              ],
            ),
            Text(
              isEdited
                  ? '${dateFormat.format(comment.created.toLocal())} · ${l10n.commentEdited} ${dateFormat.format(comment.updated.toLocal())}'
                  : dateFormat.format(comment.created.toLocal()),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 4),
            HtmlWidget(comment.comment),
          ],
        ),
      ),
    );
  }
}

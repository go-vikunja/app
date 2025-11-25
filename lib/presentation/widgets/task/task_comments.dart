import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:intl/intl.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/domain/entities/task_comment.dart';
import 'package:vikunja_app/presentation/manager/task_comments_controller.dart';

class TaskComments extends ConsumerStatefulWidget {
  final int taskId;

  const TaskComments({super.key, required this.taskId});

  @override
  ConsumerState<TaskComments> createState() => _TaskCommentsState();
}

class _TaskCommentsState extends ConsumerState<TaskComments> {
  final _commentController = TextEditingController();
  TaskComment? _editingComment;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final success = await ref
        .read(taskCommentsControllerProvider(widget.taskId).notifier)
        .addComment(text);

    if (success) {
      _commentController.clear();
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to add comment')));
    }
  }

  Future<void> _updateComment() async {
    if (_editingComment == null) return;

    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    final success = await ref
        .read(taskCommentsControllerProvider(widget.taskId).notifier)
        .updateComment(_editingComment!, text);

    if (success) {
      _commentController.clear();
      setState(() {
        _editingComment = null;
      });
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to update comment')));
    }
  }

  Future<void> _deleteComment(TaskComment comment) async {
    final success = await ref
        .read(taskCommentsControllerProvider(widget.taskId).notifier)
        .deleteComment(comment.id);

    if (!success) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to delete comment')));
    }
  }

  void _startEditing(TaskComment comment) {
    setState(() {
      _editingComment = comment;
      _commentController.text = comment.comment;
    });
  }

  void _cancelEditing() {
    setState(() {
      _editingComment = null;
      _commentController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(
      taskCommentsControllerProvider(widget.taskId),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'Comments',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        commentsAsync.when(
          data: (comments) => _buildCommentsList(comments),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Text(
            'Failed to load comments',
            style: const TextStyle(color: Colors.red),
          ),
        ),
        const SizedBox(height: 8),
        _buildCommentInput(),
      ],
    );
  }

  Widget _buildCommentsList(List<TaskComment> comments) {
    if (comments.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text('No comments yet', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: comments.length,
      itemBuilder: (context, index) => _buildCommentItem(comments[index]),
    );
  }

  Widget _buildCommentItem(TaskComment comment) {
    final currentUser = ref.read(currentUserProvider);
    final isOwner = currentUser?.id == comment.author.id;
    final dateFormat = DateFormat.yMd().add_jm();

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
                  comment.author.name.isNotEmpty
                      ? comment.author.name
                      : comment.author.username,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    Text(
                      dateFormat.format(comment.created.toLocal()),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (isOwner)
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') {
                            _startEditing(comment);
                          } else if (value == 'delete') {
                            _deleteComment(comment);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Text('Edit'),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('Delete'),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            HtmlWidget(comment.comment),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentInput() {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _commentController,
            decoration: InputDecoration(
              hintText: _editingComment != null
                  ? 'Edit comment...'
                  : 'Add a comment...',
              border: const OutlineInputBorder(),
              suffixIcon: _editingComment != null
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _cancelEditing,
                    )
                  : null,
            ),
            maxLines: null,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: Icon(_editingComment != null ? Icons.check : Icons.send),
          onPressed: _editingComment != null ? _updateComment : _addComment,
        ),
      ],
    );
  }
}

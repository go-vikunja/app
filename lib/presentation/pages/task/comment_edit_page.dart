import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html_editor_enhanced/html_editor.dart';
import 'package:vikunja_app/domain/entities/task_comment.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/manager/task_comments_controller.dart';

class CommentEditPage extends ConsumerStatefulWidget {
  final int taskId;
  final TaskComment? comment;

  const CommentEditPage({super.key, required this.taskId, this.comment});

  @override
  ConsumerState<CommentEditPage> createState() => _CommentEditPageState();
}

class _CommentEditPageState extends ConsumerState<CommentEditPage> {
  final HtmlEditorController _controller = HtmlEditorController();
  bool _isSaving = false;

  bool get _isEditMode => widget.comment != null;

  Future<void> _save() async {
    if (_isSaving) return;

    setState(() => _isSaving = true);

    final text = await _controller.getText();

    // Check if text is empty after getting it
    if (text.trim().isEmpty) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).commentCannotBeEmpty),
        ),
      );
      return;
    }

    final controller = ref.read(
      taskCommentsControllerProvider(widget.taskId).notifier,
    );

    final bool success;
    if (_isEditMode) {
      success = await controller.updateComment(widget.comment!, text);
    } else {
      success = await controller.addComment(text);
    }

    if (!mounted) return;

    if (success) {
      Navigator.pop(context, text);
    } else {
      setState(() => _isSaving = false);
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode ? l10n.commentUpdateError : l10n.commentAddError,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? l10n.editCommentTitle : l10n.addCommentTitle),
        actions: [
          IconButton(
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            onPressed: !_isSaving ? _save : null,
          ),
        ],
      ),
      body: HtmlEditor(
        controller: _controller,
        htmlEditorOptions: HtmlEditorOptions(
          hint: l10n.commentInputHint,
          initialText: widget.comment?.comment,
        ),
      ),
    );
  }
}

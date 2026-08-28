import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/utils/date_extensions.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_attachment.dart';
import 'package:vikunja_app/domain/entities/task_reminder.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';
import 'package:vikunja_app/presentation/pages/task/task_edit_page.dart';
import 'package:vikunja_app/presentation/utils/attachment_utils.dart';
import 'package:vikunja_app/presentation/utils/html_linkify.dart';
import 'package:vikunja_app/presentation/widgets/label_widget.dart';
import 'package:vikunja_app/presentation/widgets/task/task_actions.dart';

class TaskDetailPage extends ConsumerStatefulWidget {
  final Task task;

  const TaskDetailPage({super.key, required this.task});

  @override
  ConsumerState<TaskDetailPage> createState() => _TaskDetailPageState();
}

class _TaskDetailPageState extends ConsumerState<TaskDetailPage> {
  Task? _task;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _refresh();
  }

  Future<void> _refresh() async {
    final response = await ref
        .read(taskRepositoryProvider)
        .getTask(widget.task.id);
    if (!mounted) return;
    if (response.isSuccessful) {
      setState(() => _task = response.toSuccess().body);
    }
  }

  Future<void> _uploadAttachment() async {
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final path = file.path;
    if (path == null) return;

    setState(() => _uploading = true);
    try {
      final response = await ref
          .read(taskRepositoryProvider)
          .uploadAttachment(widget.task.id, path, filename: file.name);
      if (!mounted) return;
      if (response.isSuccessful) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).attachmentUploaded),
          ),
        );
        await _refresh();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).attachmentUploadFailed),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  void _edit() {
    Navigator.push<Task?>(
      context,
      MaterialPageRoute(builder: (_) => TaskEditPage(task: _task!)),
    ).then((_) => _refresh());
  }

  Future<bool> _onLinkTap(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return false;
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).openLinkFailed)),
      );
    }
    return opened;
  }

  String priorityToStringLocalized(BuildContext context, int? priority) {
    final l10n = AppLocalizations.of(context);
    if (priority == null || priority == 0) return l10n.priorityUnset;
    switch (priority) {
      case 1:
        return l10n.priorityLow;
      case 2:
        return l10n.priorityMedium;
      case 3:
        return l10n.priorityHigh;
      case 4:
        return l10n.priorityUrgent;
      case 5:
        return l10n.priorityDoNow;
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = _task!;
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vikunja'),
        actions: [
          TaskActions(
            task: task,
            onEdit: _edit,
            variant: TaskActionsVariant.icons,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(task.title, style: theme.textTheme.headlineSmall),
            if (task.labels.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: task.labels
                    .map((label) => LabelWidget(label: label))
                    .toList(),
              ),
            ],
            const Divider(height: 24),
            // Description
            Text(l10n.description, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            HtmlWidget(
              linkifyHtml(
                task.description.isNotEmpty
                    ? task.description
                    : l10n.noDescription,
              ),
              onTapUrl: _onLinkTap,
            ),
            const SizedBox(height: 16),
            // Due date
            _infoRow(
              icon: Icons.access_time,
              text: task.hasDueDate
                  ? task.dueDate!.toLocal().formatShort()
                  : l10n.noDueDate,
            ),
            // Start date
            _infoRow(
              icon: Icons.play_arrow_rounded,
              text: task.hasStartDate
                  ? task.startDate!.toLocal().formatShort()
                  : l10n.noStartDate,
            ),
            // End date
            _infoRow(
              icon: Icons.stop_rounded,
              text: task.hasEndDate
                  ? task.endDate!.toLocal().formatShort()
                  : l10n.noEndDate,
            ),
            // Reminders
            ...task.reminderDates.map(
              (TaskReminder reminder) => _infoRow(
                icon: Icons.share_arrival_time_outlined,
                text: reminder.reminder.toLocal().formatShort(),
              ),
            ),
            // Priority
            _infoRow(
              icon: Icons.priority_high,
              text: priorityToStringLocalized(context, task.priority),
            ),
            // Progress
            _infoRow(
              icon: Icons.percent,
              text: task.percentDone != null
                  ? '${(task.percentDone! * 100).toInt()}%'
                  : l10n.percentUnset,
            ),
            const Divider(height: 24),
            _buildAttachmentsSection(theme, l10n),
          ],
        ),
      ),
    );
  }

  Widget _infoRow({required IconData icon, required String text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildAttachmentsSection(ThemeData theme, AppLocalizations l10n) {
    final task = _task!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(l10n.attachments, style: theme.textTheme.titleMedium),
            const SizedBox(width: 8),
            Text(
              '(${task.attachments.length})',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const Spacer(),
            IconButton(
              icon: _uploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.attach_file),
              tooltip: l10n.uploadAttachment,
              onPressed: _uploading ? null : _uploadAttachment,
            ),
          ],
        ),
        if (task.attachments.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.noAttachments,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          )
        else
          ...task.attachments.map(
            (attachment) => _attachmentTile(task, attachment, theme),
          ),
      ],
    );
  }

  Widget _attachmentTile(
    Task task,
    TaskAttachment attachment,
    ThemeData theme,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        attachmentIcon(attachment),
        color: theme.colorScheme.primary,
      ),
      title: Text(
        attachment.file.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(attachmentSizeLabel(attachment)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => openAttachment(context, ref, task, attachment),
    );
  }
}

import 'package:flutter/foundation.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_mobile/features/description_editor/application/editor_protocol.dart';
import 'package:vikunja_mobile/features/tasks/application/link_targets.dart';

/// Whose description the editor edits.
@immutable
sealed class DescriptionTarget {
  const new();
}

/// Saved through the outbox, so offline too.
final class TaskDescriptionTarget extends DescriptionTarget {
  const new(this.taskId);

  final int taskId;
}

/// Saved online, like the project's other fields.
final class ProjectDescriptionTarget extends DescriptionTarget {
  const new(this.projectId);

  final int projectId;
}

/// The user's own [comment] on a task in [projectId], whose people can be
/// mentioned; saved online. The edit starts from the comment as the sheet
/// showed it: only its author can change it, so nothing is compared.
final class CommentTarget extends DescriptionTarget {
  const new({
    required this.taskId,
    required this.projectId,
    required this.comment,
  });

  final int taskId;
  final int projectId;
  final TaskComment comment;
}

/// Whether [edited], the editor's HTML of a description that opened as
/// [opened], changes nothing: the editor writes an empty document as
/// `<p></p>`, which for a description never written is no edit, as on the
/// web.
bool unchangedDescription(String opened, String edited) =>
    edited == opened || (opened.isEmpty && edited == '<p></p>');

/// The account's task-link bases and the API root the web would use on
/// this server: its public URL, which `/info` names as the frontend, else
/// the server the app talks to.
EditorLinks editorLinksOf(AccountLinkBases? bases) {
  final root = bases == null ? '' : '${bases.frontendUrl ?? bases.serverRoot}';
  return EditorLinks(
    taskLinkBases: [
      for (final base in bases?.taskLinkBases ?? const <Uri>[]) '$base',
    ],
    apiRoot: root.replaceFirst(RegExp(r'/+$'), ''),
  );
}

/// Where the web points an image it inserted after uploading it: the
/// attachment's v2 address under [EditorLinks.apiRoot], the form the editor
/// page accepts for `insertImage`.
String attachmentImageSrc(
  EditorLinks links, {
  required int taskId,
  required int attachmentId,
}) => '${links.apiRoot}/api/v2/tasks/$taskId/attachments/$attachmentId';

/// The id the web gives such an image.
String attachmentImageId({required int taskId, required int attachmentId}) =>
    'tiptap-image-$taskId-$attachmentId';

import 'package:flutter/foundation.dart';
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

import 'package:flutter/material.dart';
import 'package:vikunja_app/domain/entities/task_relation.dart';
import 'package:vikunja_app/l10n/gen/app_localizations.dart';

extension RelationKindUi on RelationKind {
  String label(AppLocalizations l10n) {
    switch (this) {
      case RelationKind.copiedto:
        return l10n.relationKindCopiedTo;
      case RelationKind.copiedfrom:
        return l10n.relationKindCopiedFrom;
      case RelationKind.follows:
        return l10n.relationKindFollows;
      case RelationKind.precedes:
        return l10n.relationKindPrecedes;
      case RelationKind.blocked:
        return l10n.relationKindBlocked;
      case RelationKind.blocking:
        return l10n.relationKindBlocking;
      case RelationKind.duplicates:
        return l10n.relationKindDuplicates;
      case RelationKind.duplicateof:
        return l10n.relationKindDuplicateOf;
      case RelationKind.related:
        return l10n.relationKindRelated;
      case RelationKind.parenttask:
        return l10n.relationKindParent;
      case RelationKind.subtask:
        return l10n.relationKindSubtask;
    }
  }

  IconData get icon {
    switch (this) {
      case RelationKind.copiedto:
      case RelationKind.copiedfrom:
        return Icons.file_copy_outlined;
      case RelationKind.follows:
        return Icons.arrow_back;
      case RelationKind.precedes:
        return Icons.arrow_forward;
      case RelationKind.blocked:
        return Icons.pause_circle_outline;
      case RelationKind.blocking:
        return Icons.block;
      case RelationKind.duplicates:
      case RelationKind.duplicateof:
        return Icons.content_copy;
      case RelationKind.related:
        return Icons.link;
      case RelationKind.parenttask:
        return Icons.subdirectory_arrow_left;
      case RelationKind.subtask:
        return Icons.account_tree_outlined;
    }
  }

  Color get tint {
    switch (this) {
      case RelationKind.blocked:
        return Colors.orange;
      case RelationKind.blocking:
        return Colors.red;
      case RelationKind.subtask:
      case RelationKind.parenttask:
        return Colors.blue;
      case RelationKind.precedes:
      case RelationKind.follows:
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }
}

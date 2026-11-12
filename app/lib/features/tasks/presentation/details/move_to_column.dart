import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:vikunja_domain/vikunja_domain.dart';
import 'package:vikunja_logic/vikunja_logic.dart';
import 'package:vikunja_mobile/app/l10n/l10n.dart';
import 'package:vikunja_mobile/core/repositories/task_lists.dart';
import 'package:vikunja_mobile/core/repositories/task_repository.dart';
import 'package:vikunja_mobile/features/common/presentation/option_sheet.dart';
import 'package:vikunja_mobile/features/projects/application/board_moves.dart';

/// Where a card can go from its task's detail: the [columns] of the
/// board's [view], and [fromBucketId], the column the card is in.
@immutable
final class ColumnMoveChoice {
  const new({
    required this.view,
    required this.columns,
    required this.fromBucketId,
  });

  final ProjectView view;
  final List<BoardColumn> columns;
  final int fromBucketId;
}

/// Whether a task detail opened from a board card offers Move to column…,
/// with the board's columns built again only for a new source or view, as
/// the board itself keeps them.
final class ColumnMoves {
  BoardSource? _builtFrom;
  ProjectView? _builtFor;
  List<BoardColumn> _columns = const [];

  /// Null unless the board of [origin] is stored, may be changed and has
  /// another column, and still shows [task] in its project.
  ColumnMoveChoice? choiceFor(
    Task task, {
    required TaskBoardOrigin origin,
    required BoardSource? source,
    required bool archived,
    required bool writable,
  }) {
    final view = source?.view;
    if (source == null || view == null || view.id != origin.viewId) {
      return null;
    }
    if (task.projectId != origin.projectId) return null;
    if (boardIsReadOnly(view, archived: archived, writable: writable)) {
      return null;
    }
    final columns = _columnsOf(view, source);
    if (columns.length < 2) return null;
    final from = columns
        .where((column) => column.tasks.any((card) => card.id == task.id))
        .firstOrNull;
    if (from == null) return null;
    return ColumnMoveChoice(
      view: view,
      columns: columns,
      fromBucketId: from.bucket.id,
    );
  }

  List<BoardColumn> _columnsOf(ProjectView view, BoardSource source) {
    if (!identical(source, _builtFrom) || !identical(view, _builtFor)) {
      _builtFrom = source;
      _builtFor = view;
      _columns = boardColumnsOf(view, source);
    }
    return _columns;
  }
}

/// Asks which of the board's other columns [task]'s card goes to and puts
/// it on top there, as the board's screen-reader actions do: the column's
/// limit first, then the done column's rules. [choice] is the board as the
/// caller knows it at each call, read when the list opens and again once a
/// column is picked, null once the card may no longer move. [showMessage]
/// says where it went, or that the column is full; once [context] is gone,
/// as the pane's when the window narrows, the move is made without a word.
Future<void> moveToColumn(
  BuildContext context, {
  required TaskRepository repository,
  required Task task,
  required ColumnMoveChoice? Function() choice,
  required ValueChanged<String> showMessage,
}) async {
  final offered = choice();
  if (offered == null) return;
  final l10n = context.l10n;
  final view = offered.view;
  final names = columnNamesOf(offered.columns);
  final picked = await showOptionSheet<int>(
    context,
    title: l10n.taskMoveToColumnTitle,
    options: [
      for (final column in offered.columns)
        if (column.bucket.id != offered.fromBucketId)
          SheetOption(
            value: column.bucket.id,
            label: names[column.bucket.id]!,
            subtitle: columnIsFull(column)
                ? l10n.boardColumnFull
                : view.doneBucketId != 0 &&
                      column.bucket.id == view.doneBucketId
                ? l10n.boardDoneColumnHint
                : null,
          ),
    ],
  );
  if (picked == null) return;
  final current = choice();
  if (current == null) return;
  final move = planCardMove(
    view: current.view,
    columns: current.columns,
    task: task,
    toBucketId: picked,
    index: 0,
  );
  switch (move) {
    case null:
      return;
    case ColumnFull():
      if (!context.mounted) return;
      unawaited(HapticFeedback.heavyImpact());
      showMessage(l10n.boardColumnLimitReached);
    case MarkCardDone() || PlaceCard():
      if (context.mounted) {
        unawaited(HapticFeedback.selectionClick());
        showMessage(l10n.boardMovedTo(columnNamesOf(current.columns)[picked]!));
      }
      await queueCardMove(
        repository,
        task.id,
        viewId: current.view.id,
        move: move,
      );
  }
}

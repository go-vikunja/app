import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:provider/provider.dart';
import 'package:vikunja_app/components/label.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/pages/project/task_edit.dart';
import 'package:vikunja_app/utils/misc.dart';
import 'package:vikunja_app/theme/constants.dart';

import '../stores/project_store.dart';

enum DropLocation { above, below, none }

class TaskData {
  final Task task;
  final Size? size;
  TaskData(this.task, this.size);
}

class BucketTaskCard extends StatefulWidget {
  final Task task;
  final int index;
  final DragUpdateCallback onDragUpdate;
  final void Function(Task, int) onAccept;

  const BucketTaskCard({
    Key? key,
    required this.task,
    required this.index,
    required this.onDragUpdate,
    required this.onAccept,
  }) : super(key: key);

  @override
  State<BucketTaskCard> createState() => _BucketTaskCardState();
}

class _BucketTaskCardState extends State<BucketTaskCard>
    with AutomaticKeepAliveClientMixin {
  Size? _cardSize;
  bool _dragging = false;
  DropLocation _dropLocation = DropLocation.none;
  TaskData? _dropData;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_cardSize == null) _updateCardSize(context);

    final taskState = Provider.of<ProjectProvider>(context);
    final bucket = taskState.buckets[
        taskState.buckets.indexWhere((b) => b.id == widget.task.bucketId)];
    // default chip height: 32
    const double chipHeight = 28;
    const chipConstraints = BoxConstraints(maxHeight: chipHeight);
    final theme = Theme.of(context);

    final identifierRow = Row(
      children: <Widget>[
        Text(
          widget.task.identifier.isNotEmpty
              ? '${widget.task.identifier}'
              : '${widget.task.id}',
          style: (theme.textTheme.titleSmall ?? TextStyle()).copyWith(
            color: Colors.grey,
          ),
        ),
      ],
    );
    if (widget.task.done) {
      identifierRow.children.insert(
          0,
          Container(
            constraints: chipConstraints,
            padding: EdgeInsets.only(right: 4),
            child: FittedBox(
              child: Chip(
                label: Text('Done'),
                labelStyle:
                    (theme.textTheme.labelLarge ?? TextStyle()).copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.brightness == Brightness.dark
                      ? Colors.black
                      : Colors.white,
                ),
                backgroundColor: vGreen,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4.0),
                  side: BorderSide(style: BorderStyle.none),
                ),
              ),
            ),
          ));
    }

    final titleRow = Row(
      children: <Widget>[
        Expanded(
          child: Text(
            widget.task.title,
            style: (theme.textTheme.titleMedium ?? TextStyle(fontSize: 16))
                .copyWith(
              fontWeight: FontWeight.normal,
              color: theme.brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
            ),
          ),
        ),
      ],
    );
    if (widget.task.hasDueDate) {
      final duration = widget.task.dueDate!.difference(DateTime.now());
      final pastDue = duration.isNegative && !widget.task.done;
      titleRow.children.add(Container(
        constraints: chipConstraints,
        padding: EdgeInsets.only(left: 4),
        child: FittedBox(
          child: Chip(
            avatar: Icon(
              Icons.calendar_month,
              color: pastDue
                  ? Colors.red
                  : (theme.brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[600]),
            ),
            label: Text(durationToHumanReadable(duration)),
            labelStyle: (theme.textTheme.labelLarge ?? TextStyle()).copyWith(
              color: pastDue
                  ? Colors.red
                  : (theme.brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[600]),
            ),
            backgroundColor: theme.brightness == Brightness.dark
                ? Colors.grey[800]
                : Colors.grey[200],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4.0),
              side: BorderSide(style: BorderStyle.none),
            ),
          ),
        ),
      ));
    }

    final labelRow = Wrap(
      children: <Widget>[],
      spacing: 4,
      runSpacing: 4,
    );
    widget.task.labels.sort((a, b) => a.title.compareTo(b.title));
    widget.task.labels.asMap().forEach((i, label) {
      labelRow.children.add(LabelComponent(label: label));
    });
    if (widget.task.hasCheckboxes) {
      final checkboxStatistics = widget.task.checkboxStatistics;
      final iconSize = (theme.textTheme.labelLarge?.fontSize ?? 14) + 2;
      labelRow.children.add(Chip(
        avatar: Container(
          constraints: BoxConstraints(maxHeight: iconSize, maxWidth: iconSize),
          child: CircularProgressIndicator(
            value: checkboxStatistics.checked / checkboxStatistics.total,
            backgroundColor: Colors.grey,
          ),
        ),
        label: Text((checkboxStatistics.checked == checkboxStatistics.total
                ? ''
                : '${checkboxStatistics.checked} of ') +
            '${checkboxStatistics.total} tasks'),
        backgroundColor: theme.brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[200],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4.0),
          side: BorderSide(style: BorderStyle.none),
        ),
      ));
    }
    if (widget.task.attachments.isNotEmpty) {
      labelRow.children.add(Chip(
        label: Transform.rotate(
          angle: -pi / 4.0,
          child: Icon(Icons.attachment),
        ),
        backgroundColor: theme.brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[200],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4.0),
          side: BorderSide(style: BorderStyle.none),
        ),
      ));
    }
    if (widget.task.description.isNotEmpty) {
      labelRow.children.add(Chip(
        label: Icon(Icons.notes, size: 20.0),
        backgroundColor: theme.brightness == Brightness.dark
            ? Colors.grey[800]
            : Colors.grey[200],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4.0),
          side: BorderSide(style: BorderStyle.none),
        ),
      ));
    }

    final rowConstraints = BoxConstraints(minHeight: chipHeight);
    final card = Card(
      color: widget.task.color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5.0),
      ),
      child: InkWell(
        child: Theme(
          data: Theme.of(context).copyWith(
            // Remove enforced margins
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  constraints: rowConstraints,
                  child: identifierRow,
                ),
                Padding(
                  padding: EdgeInsets.only(
                      top: 4, bottom: labelRow.children.isNotEmpty ? 8 : 0),
                  child: Container(
                    constraints: rowConstraints,
                    child: titleRow,
                  ),
                ),
                labelRow,
              ],
            ),
          ),
        ),
        onTap: () {
          FocusScope.of(context).unfocus();
          Navigator.push<Task>(
            context,
            MaterialPageRoute(
              builder: (context) => TaskEditPage(
                task: widget.task,
                taskState: taskState,
              ),
            ),
          );
        },
      ),
    );

    return LongPressDraggable<TaskData>(
      data: TaskData(widget.task, _cardSize),
      maxSimultaneousDrags: taskState.taskDragging
          ? 0
          : 1, // only one task can be dragged at a time
      onDragStarted: () {
        taskState.taskDragging = true;
        setState(() => _dragging = true);
      },
      onDragUpdate: widget.onDragUpdate,
      onDragEnd: (_) {
        taskState.taskDragging = false;
        setState(() => _dragging = false);
      },
      feedback: (_cardSize == null)
          ? SizedBox.shrink()
          : SizedBox.fromSize(
              size: _cardSize,
              child: Card(
                color: card.color,
                child: (card.child as InkWell).child,
                elevation: (card.elevation ?? 0) + 5,
              ),
            ),
      childWhenDragging: SizedBox.shrink(),
      child: () {
        if (_dragging || _cardSize == null) return card;

        final cardSize = _cardSize!;
        final dropBoxSize = _dropData?.size ?? cardSize;
        final dropBox = DottedBorder(
          color: Colors.grey,
          child: SizedBox.fromSize(size: dropBoxSize),
        );
        final dropAbove =
            taskState.taskDragging && _dropLocation == DropLocation.above;
        final dropBelow =
            taskState.taskDragging && _dropLocation == DropLocation.below;
        final DragTargetLeave<TaskData> dragTargetOnLeave =
            (data) => setState(() {
                  _dropLocation = DropLocation.none;
                  _dropData = null;
                });
        final dragTargetOnWillAccept =
            (TaskData data, DropLocation dropLocation) {
          if (data.task.bucketId != bucket.id) if (bucket.limit != 0 &&
              bucket.tasks.length >= bucket.limit) return false;
          setState(() {
            _dropLocation = dropLocation;
            _dropData = data;
          });
          return true;
        };
        final DragTargetAccept<DragTargetDetails<TaskData>> dragTargetOnAccept =
            (data) {
          final index = bucket.tasks.indexOf(widget.task);
          widget.onAccept(data.data.task,
              _dropLocation == DropLocation.above ? index : index + 1);
          setState(() {
            _dropLocation = DropLocation.none;
            _dropData = null;
          });
        };

        return SizedBox(
          width: cardSize.width,
          height: cardSize.height +
              (dropAbove || dropBelow ? dropBoxSize.height + 4 : 0),
          child: Stack(
            children: <Widget>[
              Column(
                children: [
                  if (dropAbove) dropBox,
                  card,
                  if (dropBelow) dropBox,
                ],
              ),
              Column(
                children: <SizedBox>[
                  SizedBox(
                    height: (cardSize.height / 2) +
                        (dropAbove ? dropBoxSize.height : 0),
                    child: DragTarget<TaskData>(
                      onWillAcceptWithDetails: (data) =>
                          dragTargetOnWillAccept(data.data, DropLocation.above),
                      onAcceptWithDetails: dragTargetOnAccept,
                      onLeave: dragTargetOnLeave,
                      builder: (_, __, ___) => SizedBox.expand(),
                    ),
                  ),
                  SizedBox(
                    height: (cardSize.height / 2) +
                        (dropBelow ? dropBoxSize.height : 0),
                    child: DragTarget<TaskData>(
                      onWillAcceptWithDetails: (data) =>
                          dragTargetOnWillAccept(data.data, DropLocation.below),
                      onAcceptWithDetails: dragTargetOnAccept,
                      onLeave: dragTargetOnLeave,
                      builder: (_, __, ___) => SizedBox.expand(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }(),
    );
  }

  void _updateCardSize(BuildContext context) {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (mounted)
        setState(() {
          _cardSize = context.size;
        });
    });
  }

  @override
  bool get wantKeepAlive => _dragging;
}

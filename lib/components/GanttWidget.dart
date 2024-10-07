import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:vikunja_app/stores/project_store.dart';

import '../models/task.dart';
import 'TaskBottomSheet.dart';

class GanttWidget extends StatefulWidget {
  @override
  State<GanttWidget> createState() => _GanttWidgetState();
}

String monthName(DateTime date) {
  // this is not ideal but you'd have to scroll very far for it to be noticeable
  return DateFormat.yMMMM().format(date);
}

int daysInMonth(DateTime date) {
  int days = DateTimeRange(
          start: DateTime(date.year, date.month),
          end: DateTime(date.year, date.month + 1))
      .duration
      .inDays;
  return days;
}

class MockTask {
  final String title;
  final DateTime start;
  final DateTime end;
  final int id;

  MockTask(this.title, this.start, this.end, this.id);
}

int MONTH_OFFSET = 2;

class _GanttWidgetState extends State<GanttWidget> {
  DateTime startDateTime =
      DateTime(DateTime.now().year, DateTime.now().month - MONTH_OFFSET, 1);

  late double dayWidth;

  late ScrollController _dateScrollController;
  late ScrollController _taskScrollController;

  late double _taskHeight;
  bool inited = false;
  int taskDragging = -1;

  late ProjectProvider projectState;

  Map<int, double> taskStartOffsets = {};
  Map<int, double> taskEndOffsets = {};

  @override
  Widget build(BuildContext context) {
    _taskHeight = MediaQuery.of(context).size.height / 20;
    dayWidth = MediaQuery.of(context).size.width / 15;

    if (!inited) {
      projectState = Provider.of<ProjectProvider>(context, listen: false);
      for (Task task in projectState.ganttTasks) {
        print(task.toJSON());

        double taskStart =
            dayWidth * task.startDate!.difference(startDateTime).inDays;
      }

      double initialOffset =
          (DateTime.now().difference(startDateTime)).inDays * dayWidth;

      _dateScrollController =
          ScrollController(initialScrollOffset: initialOffset);

      _taskScrollController =
          ScrollController(initialScrollOffset: initialOffset);
      _dateScrollController.addListener(() {
        if (_dateScrollController.offset != _taskScrollController.offset) {
          _taskScrollController.jumpTo(_dateScrollController.offset);
        }
      });
      _taskScrollController.addListener(() {
        if (_dateScrollController.offset != _taskScrollController.offset) {
          _dateScrollController.jumpTo(_taskScrollController.offset);
        }
      });
      inited = true;
    }

    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            height: _taskHeight * (1.5 + 1 + projectState.ganttTasks.length),
            child: Column(
              children: [
                Container(
                  height: _taskHeight * 1.5,
                  child: ListView.builder(
                      shrinkWrap: true,
                      controller: _dateScrollController,
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) {
                        return Container(
                            color: index % 2 == 0 ? Colors.blue : Colors.green,
                            child: Container(
                              child: Column(
                                children: [
                                  Container(
                                    height: _taskHeight * 0.5,
                                    child: Text(monthName(DateTime(
                                        startDateTime.year,
                                        startDateTime.month + index,
                                        1))),
                                  ),
                                  Container(
                                    height: _taskHeight,
                                    child: ListView.builder(
                                        shrinkWrap: true,
                                        physics: NeverScrollableScrollPhysics(),
                                        itemCount: daysInMonth(DateTime(
                                            startDateTime.year,
                                            startDateTime.month + index,
                                            1)),
                                        scrollDirection: Axis.horizontal,
                                        itemBuilder: (context, index) {
                                          return Container(
                                            height: _taskHeight,
                                            width: dayWidth,
                                            child: Text((index + 1).toString()),
                                            color: index % 2 == 0
                                                ? Colors.red
                                                : Colors.yellow,
                                          );
                                        }),
                                  ),
                                ],
                              ),
                            ));
                      }),
                ),
                Container(
                  child: SingleChildScrollView(
                    controller: _taskScrollController,
                    scrollDirection: Axis.horizontal,
                    child: Container(
                      width: MediaQuery.of(context).size.width * 10,
                      height: _taskHeight * projectState.ganttTasks.length,
                      child: ListView.builder(
                        itemCount: projectState.ganttTasks.length,
                        itemBuilder: (context, index) {
                          Task task = projectState.ganttTasks[index];
                          double taskStartOffset =
                              taskStartOffsets.containsKey(task.id)
                                  ? taskStartOffsets[task.id]!
                                  : 0;
                          double taskEndOffset =
                              taskEndOffsets.containsKey(task.id)
                                  ? taskEndOffsets[task.id]!
                                  : 0;
                          double taskStart = dayWidth *
                                  task.startDate!
                                      .difference(startDateTime)
                                      .inDays +
                              taskStartOffset;
                          double taskEnd =
                              task.endDate!.difference(task.startDate!).inDays *
                                      dayWidth -
                                  taskStartOffset;

                          return Padding(
                            padding: EdgeInsets.only(left: taskStart),
                            child: Stack(
                              children: [
                                Container(
                                    height: _taskHeight,
                                    width: taskEnd + taskEndOffset,
                                    child: LongPressDraggable(
                                        onDragEnd: (details) {
                                          taskDragging = -1;
                                          DateTime newStartDate =
                                              startDateTime.add(Duration(
                                                  days: ((details.offset.dx +
                                                              _taskScrollController
                                                                  .offset) /
                                                          dayWidth)
                                                      .round()));
                                          task.endDate = task.endDate!.add(
                                              newStartDate
                                                  .difference(task.startDate!));
                                          task.startDate = newStartDate;
                                        },
                                        onDragStarted: () {
                                          taskDragging = task.id;
                                        },
                                        axis: Axis.horizontal,
                                        feedback: SizedBox(
                                            width: task.endDate!
                                                    .difference(task.startDate!)
                                                    .inDays *
                                                dayWidth,
                                            height: _taskHeight,
                                            child: buildCard(task)),
                                        child: taskDragging != task.id
                                            ? buildCard(task)
                                            : Container()))
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCard(Task task) {
    return Card(
        key: ValueKey(task.id),
        child: GestureDetector(
          onTap: () {
            showModalBottomSheet<void>(
                context: context,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(10.0)),
                ),
                builder: (BuildContext context) {
                  return TaskBottomSheet(
                      task: task, onEdit: () => {}, taskState: projectState);
                });
          },
          child: Row(
            children: [
              // handle at start to drag startDate
              LongPressDraggable(
                  onDragUpdate: (details) {
                    setState(() {
                      taskStartOffsets[task.id] = details.delta.dx +
                          (taskStartOffsets.containsKey(task.id)
                              ? taskStartOffsets[task.id]!
                              : 0);
                    });
                  },
                  child: Container(child: Icon(Icons.drag_indicator)),
                  feedback: SizedBox(),
                  onDragEnd: (details) {
                    setState(() {
                      task.startDate = task.startDate!.add(Duration(
                          days: (taskStartOffsets[task.id]!) ~/ dayWidth));
                      projectState.updateTask(context: context, task: task);
                      taskStartOffsets[task.id] = 0;
                    });
                  },
                  axis: Axis.horizontal),

              Expanded(child: Text(task.title)),
              LongPressDraggable(
                  onDragUpdate: (details) {
                    setState(() {
                      taskEndOffsets[task.id] = details.delta.dx +
                          (taskEndOffsets.containsKey(task.id)
                              ? taskEndOffsets[task.id]!
                              : 0);
                    });
                  },
                  child: Container(child: Icon(Icons.drag_indicator)),
                  feedback: SizedBox(),
                  onDragEnd: (details) {
                    setState(() {
                      task.endDate = task.endDate!.add(Duration(
                          days: (taskEndOffsets[task.id]!) ~/ dayWidth));
                      projectState.updateTask(context: context, task: task);
                      taskEndOffsets[task.id] = 0;
                    });
                    print("drag end");
                  },
                  axis: Axis.horizontal),
            ],
          ),
        ));
  }
}

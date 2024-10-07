import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:vikunja_app/stores/project_store.dart';

import '../models/task.dart';

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

  late ProjectProvider projectState;

  List<MockTask> tasks = [
    MockTask(
        "fisttask", DateTime.now(), DateTime.now().add(Duration(days: 10)), 1),
    MockTask("fisttask", DateTime.now().add(Duration(days: 15)),
        DateTime.now().add(Duration(days: 20)), 2),
    MockTask("fisttask", DateTime.now().subtract(Duration(days: 10)),
        DateTime.now().add(Duration(days: 27)), 3),
  ];

  @override
  Widget build(BuildContext context) {
    if (!inited) {
      projectState = Provider.of<ProjectProvider>(context, listen: false);
      for (Task task in projectState.ganttTasks) {
        print(task.toJSON());
      }
      _taskHeight = MediaQuery.of(context).size.height / 20;
      dayWidth = MediaQuery.of(context).size.width / 15;
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
                          double taskStart = dayWidth *
                              task.startDate!.difference(startDateTime).inDays;
                          return UnconstrainedBox(
                            alignment: Alignment.topLeft,
                            child: Container(
                              padding: EdgeInsets.only(left: taskStart),
                              height: _taskHeight,
                              width: taskStart +
                                  dayWidth *
                                      task.endDate!
                                          .difference(task.startDate!)
                                          .inDays,
                              child: Container(
                                  decoration: BoxDecoration(
                                      border: Border.all(color: Colors.red)),
                                  child: Text(task.title +
                                      "" +
                                      task.endDate!
                                          .difference(task.startDate!)
                                          .inDays
                                          .toString())),
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
          /*Container(
            height: MediaQuery.of(context).size.height / 8,
            width: MediaQuery.of(context).size.width * 10,
            child: Flex(
              direction: Axis.horizontal,
              children: [
                SingleChildScrollView(
                controller: _taskScrollController,
                scrollDirection: Axis.horizontal,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: Column(
                      children: [
                        Text("1"),
                        Text("1"),
                        Text("1"),
                        Text("1"),
                      ],
                    )
                  ),
              ),
            ]
            ),
          )*/
        ],
      ),
    );
  }
}

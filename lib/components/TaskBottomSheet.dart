import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:vikunja_app/components/label.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/pages/list/task_edit.dart';
import 'package:vikunja_app/stores/project_store.dart';
import 'package:vikunja_app/theme/constants.dart';
import 'package:vikunja_app/utils/priority.dart';

class TaskBottomSheet extends StatefulWidget {
  final Task task;
  final bool showInfo;
  final bool loading;
  final Function onEdit;
  final ValueSetter<bool>? onMarkedAsDone;
  final ProjectProvider taskState;

  const TaskBottomSheet({
    Key? key,
    required this.task,
    required this.onEdit,
    required this.taskState,
    this.loading = false,
    this.showInfo = false,
    this.onMarkedAsDone,
  }) : super(key: key);

  @override
  TaskBottomSheetState createState() => TaskBottomSheetState();
}

class TaskBottomSheetState extends State<TaskBottomSheet> {
  late Task _currentTask;

  @override
  void initState() {
    super.initState();
    _currentTask = widget.task;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _currentTask.title,
                  style: theme.textTheme.headline6,
                ),
                IconButton(
                  onPressed: _editTask,
                  icon: Icon(Icons.edit),
                ),
              ],
            ),
            SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _currentTask.labels.map((label) {
                return LabelComponent(label: label);
              }).toList(),
            ),
            HtmlWidget(
              _currentTask.description.isNotEmpty
                  ? _currentTask.description
                  : 'No description',
            ),
            SizedBox(height: 16),
            _buildRowWithIconAndText(
              Icons.access_time,
              _currentTask.dueDate != null
                  ? vDateFormatShort.format(_currentTask.dueDate!.toLocal())
                  : 'No due date',
            ),
            _buildRowWithIconAndText(
              Icons.play_arrow_rounded,
              _currentTask.startDate != null
                  ? vDateFormatShort.format(_currentTask.startDate!.toLocal())
                  : 'No start date',
            ),
            _buildRowWithIconAndText(
              Icons.stop_rounded,
              _currentTask.endDate != null
                  ? vDateFormatShort.format(_currentTask.endDate!.toLocal())
                  : 'No end date',
            ),
            _buildRowWithIconAndText(
              Icons.priority_high,
              _currentTask.priority != null
                  ? priorityToString(_currentTask.priority)
                  : 'No priority',
            ),
            _buildRowWithIconAndText(
              Icons.percent,
              _currentTask.percent_done != null
                  ? '${(_currentTask.percent_done! * 100).toInt()}%'
                  : 'Unset',
            ),
          ],
        ),
      ),
    );
  }

  void _editTask() {
    Navigator.push<Task>(
      context,
      MaterialPageRoute(
        builder: (buildContext) => TaskEditPage(
          task: _currentTask,
          taskState: widget.taskState,
        ),
      ),
    ).then((task) {
      if (task != null) {
        setState(() {
          _currentTask = task;
        });
      }
      widget.onEdit();
    });
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    );
  }

  Widget _buildRowWithIconAndText(IconData icon, String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon),
          SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}

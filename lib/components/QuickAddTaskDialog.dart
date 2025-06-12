import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:vikunja_app/components/datetimePicker.dart';
import 'package:vikunja_app/models/label.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/global.dart';

enum NewTaskDue { day, week, month, custom }

// TODO: add to enum above
Map<NewTaskDue, Duration> newTaskDueToDuration = {
  NewTaskDue.day: Duration(days: 1),
  NewTaskDue.week: Duration(days: 7),
  NewTaskDue.month: Duration(days: 30),
};

class QuickAddTaskDialog extends StatefulWidget {
  final void Function(Task task)? onAddTask;
  final String? prefilledTitle;
  final int? defaultProjectId;
  
  const QuickAddTaskDialog({
    Key? key,
    this.onAddTask,
    this.prefilledTitle,
    this.defaultProjectId,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => QuickAddTaskDialogState();
}

class QuickAddTaskDialogState extends State<QuickAddTaskDialog>
    with AfterLayoutMixin<QuickAddTaskDialog> {
  NewTaskDue newTaskDue = NewTaskDue.day;
  DateTime? customDueDate;
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  List<Label> selectedLabels = [];
  List<Label> availableLabels = [];
  bool isLoadingLabels = false;

  @override
  void initState() {
    super.initState();
    _loadLabels();
  }

  @override
  void afterFirstLayout(BuildContext context) {
    setState(() {
      titleController.text = widget.prefilledTitle ?? "";
    });
  }

  void _loadLabels() async {
    setState(() {
      isLoadingLabels = true;
    });
    
    try {
      final labels = await VikunjaGlobal.of(context).labelService.getAll();
      setState(() {
        availableLabels = labels.body ?? [];
        isLoadingLabels = false;
      });
    } catch (e) {
      setState(() {
        isLoadingLabels = false;
      });
      print('Error loading labels: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (newTaskDue != NewTaskDue.custom) {
      customDueDate = DateTime.now().add(newTaskDueToDuration[newTaskDue]!);
    }
    
    return AlertDialog(
      title: Text('Quick Add Task'),
      contentPadding: const EdgeInsets.all(16.0),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title field
            TextField(
              autofocus: true,
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Task Name *',
                hintText: 'Enter task name',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            
            // Description field
            TextField(
              controller: descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Optional description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              minLines: 1,
            ),
            SizedBox(height: 16),
            
            // Due date section
            Text(
              'Due Date',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            SizedBox(height: 8),
            taskDueList("1 Day", NewTaskDue.day),
            taskDueList("1 Week", NewTaskDue.week),
            taskDueList("1 Month", NewTaskDue.month),
            VikunjaDateTimePicker(
              label: "Custom Date",
              onChanged: (value) {
                setState(() => newTaskDue = NewTaskDue.custom);
                customDueDate = value;
              },
            ),
            SizedBox(height: 16),
            
            // Labels section
            Text(
              'Labels',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            SizedBox(height: 8),
            isLoadingLabels
                ? CircularProgressIndicator()
                : availableLabels.isEmpty
                    ? Text('No labels available')
                    : Container(
                        height: 120,
                        child: ListView.builder(
                          itemCount: availableLabels.length,
                          itemBuilder: (context, index) {
                            final label = availableLabels[index];
                            final isSelected = selectedLabels.contains(label);
                            return CheckboxListTile(
                              title: Text(label.title),
                              value: isSelected,
                              activeColor: label.color,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true && !isSelected) {
                                    selectedLabels.add(label);
                                  } else if (value == false && isSelected) {
                                    selectedLabels.remove(label);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      ),
            
            // Selected labels preview
            if (selectedLabels.isNotEmpty) ..[
              SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: selectedLabels.map((label) {
                  return Chip(
                    label: Text(label.title),
                    backgroundColor: label.color?.withOpacity(0.3),
                    deleteIcon: Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() {
                        selectedLabels.remove(label);
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          child: const Text('CANCEL'),
          onPressed: () => Navigator.pop(context),
        ),
        ElevatedButton(
          child: const Text('ADD TASK'),
          onPressed: () {
            if (titleController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Please enter a task name')),
              );
              return;
            }
            
            final task = Task(
              title: titleController.text.trim(),
              description: descriptionController.text.trim(),
              dueDate: customDueDate,
              labels: selectedLabels,
              createdBy: VikunjaGlobal.of(context).currentUser!,
              projectId: widget.defaultProjectId ?? 1,
            );
            
            if (widget.onAddTask != null) {
              widget.onAddTask!(task);
            }
            
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  Widget taskDueList(String name, NewTaskDue thisNewTaskDue) {
    return Row(
      children: [
        Radio<NewTaskDue>(
          value: thisNewTaskDue,
          groupValue: newTaskDue,
          onChanged: (NewTaskDue? value) {
            if (value != null) {
              setState(() {
                newTaskDue = value;
                customDueDate = DateTime.now().add(newTaskDueToDuration[value]!);
              });
            }
          },
        ),
        Text(name),
      ],
    );
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }
}
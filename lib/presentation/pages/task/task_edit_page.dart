import 'package:background_downloader/background_downloader.dart'
    show TaskStatus, FileDownloader;
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:vikunja_app/core/di/network_provider.dart';
import 'package:vikunja_app/core/di/repository_provider.dart';
import 'package:vikunja_app/core/utils/priority.dart';
import 'package:vikunja_app/core/utils/repeat_after_parse.dart';
import 'package:vikunja_app/domain/entities/label.dart';
import 'package:vikunja_app/domain/entities/task.dart';
import 'package:vikunja_app/domain/entities/task_reminder.dart';
import 'package:vikunja_app/presentation/manager/task_page_controller.dart';
import 'package:vikunja_app/presentation/pages/task/edit_description.dart';
import 'package:vikunja_app/presentation/widgets/date_time_field.dart';
import 'package:vikunja_app/presentation/widgets/label_widget.dart';
import 'package:vikunja_app/presentation/widgets/task/color_picker_dialog.dart';
import 'package:vikunja_app/presentation/widgets/task/task_delete_dialog.dart';
import 'package:vikunja_app/presentation/widgets/task/task_save_dialog.dart';

class TaskEditPage extends ConsumerStatefulWidget {
  final Task task;

  TaskEditPage({required this.task}) : super(key: Key(task.toString()));

  @override
  TaskEditPageState createState() => TaskEditPageState();
}

class TaskEditPageState extends ConsumerState<TaskEditPage> {
  final _formKey = GlobalKey<FormState>();

  String? _title, _description;
  DateTime? _dueDate, _startDate, _endDate;
  int _repeatAfterValue = 0;
  String _repeatAfterType = "Days";
  int? _priority;
  List<TaskReminder>? _reminderDates;
  List<Label>? _labels;
  Color? _color;

  // we use this to find the label object after a user taps on the suggestion, because the typeahead only uses strings, not full objects.
  List<Label>? _suggestedLabels;
  final _labelTypeAheadController = TextEditingController();

  bool changed = false;

  @override
  void initState() {
    _reminderDates = List.of(widget.task.reminderDates);
    _labels = List.of(widget.task.labels);

    _priority = widget.task.priority;
    _description = widget.task.description;
    _color = widget.task.color;

    _dueDate = widget.task.dueDate;
    _startDate = widget.task.startDate;
    _endDate = widget.task.endDate;

    _repeatAfterValue =
        getRepeatAfterValueFromDuration(widget.task.repeatAfter) ?? 0;
    _repeatAfterType =
        getRepeatAfterTypeFromDuration(widget.task.repeatAfter) ?? "Days";

    super.initState();
  }

  @override
  Widget build(BuildContext ctx) {
    return PopScope(
      canPop: !changed,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) {
          _showConfirmationDialog();
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(),
        body: _buildForm(context),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            if (_formKey.currentState?.validate() == true) {
              _saveTask(ctx);
            }
          },
          child: Icon(Icons.save),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: Text('Edit Task'),
      actions: [
        IconButton(
          icon: Icon(Icons.delete),
          onPressed: () {
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return TaskDeleteDialog(
                  widget.task.id,
                  onConfirm: () async {
                    var success = await ref
                        .read(taskPageControllerProvider.notifier)
                        .deleteTask(widget.task.id);

                    if (success) {
                      Navigator.of(context).pop();
                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error deleting the task!')),
                      );
                    }
                  },
                  onCancel: () {
                    Navigator.of(context).pop();
                  },
                );
              },
            );
          },
        ),
      ],
    );
  }

  Form _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).size.height / 2,
        ),
        children: <Widget>[
          _buildTitle(),
          _buildDescription(context),
          _buildDueDate(),
          _buildStartDate(),
          _buildEndDate(),
          _buildRepeatAfter(),
          _buildReminderList(),
          _buildAddReminderButton(context),
          _buildPriority(),
          _buildAddLabel(context),
          _buildLabelList(),
          _buildColor(),
          _buildAttachments(),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.0),
      child: TextFormField(
        maxLines: null,
        keyboardType: TextInputType.multiline,
        initialValue: widget.task.title,
        onChanged: (title) {
          _title = title;
          _checkChanged();
        },
        decoration: InputDecoration(
          labelText: 'Title',
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildDescription(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.0),
      child: GestureDetector(
        onTap: () async {
          var description = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (buildContext) =>
                  EditDescription(initialText: _description),
            ),
          );
          setState(() {
            if (description != null) {
              _description = description;
              _checkChanged();
            }
          });
        },
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.only(right: 15, left: 2),
              child: Icon(Icons.description, color: Colors.grey),
            ),
            Flexible(
              child: HtmlWidget(
                _description != null ? _description! : "No description",
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDueDate() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.0),
      child: VikunjaDateTimeField(
        icon: Icon(Icons.access_time),
        label: 'Due Date',
        initialValue: widget.task.dueDate,
        onChanged: (duedate) {
          _dueDate = duedate;
          _checkChanged();
        },
      ),
    );
  }

  Widget _buildStartDate() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.0),
      child: VikunjaDateTimeField(
        label: 'Start Date',
        initialValue: widget.task.startDate,
        onChanged: (startDate) {
          _startDate = startDate;
          _checkChanged();
        },
      ),
    );
  }

  Widget _buildEndDate() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.0),
      child: VikunjaDateTimeField(
        label: 'End Date',
        initialValue: widget.task.endDate,
        onChanged: (endDate) {
          _endDate = endDate;
          _checkChanged();
        },
      ),
    );
  }

  Widget _buildRepeatAfter() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        children: [
          Flexible(
            flex: 65,
            child: TextFormField(
              keyboardType: TextInputType.number,
              initialValue: getRepeatAfterValueFromDuration(
                widget.task.repeatAfter,
              )?.toString(),
              onChanged: (newValue) {
                _repeatAfterValue = int.tryParse(newValue) ?? 0;
                _checkChanged();
              },
              decoration: InputDecoration(
                labelText: 'Repeat after',
                border: InputBorder.none,
                icon: Icon(Icons.repeat),
                contentPadding: EdgeInsets.fromLTRB(0, 0, 0, 0),
              ),
            ),
          ),
          Spacer(),
          Flexible(
            flex: 30,
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.fromLTRB(0, 0, 0, 0),
              ),
              isExpanded: true,
              initialValue: _repeatAfterType,
              onChanged: (String? newType) {
                if (newType != null) {
                  _repeatAfterType = newType;
                }
                _checkChanged();
              },
              items: <String>['Hours', 'Days', 'Weeks', 'Months', 'Years']
                  .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  })
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderList() {
    return Padding(
      padding: EdgeInsets.only(top: 15.0),
      child: Column(
        children:
            _reminderDates?.map((e) {
              return VikunjaDateTimeField(
                label: "Reminder",
                initialValue: e.reminder,
                onChanged: (date) {
                  if (date != null) {
                    e.reminder = date;
                  } else {
                    _reminderDates?.remove(e);
                  }
                },
              );
            }).toList() ??
            [],
      ),
    );
  }

  Widget _buildAddReminderButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: GestureDetector(
        child: Row(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.only(right: 15, left: 2),
              child: Icon(Icons.alarm_add, color: Colors.grey),
            ),
            Text(
              'Add a reminder',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ],
        ),
        onTap: () => _addNewReminder(context),
      ),
    );
  }

  Widget _buildPriority() {
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        icon: const Icon(Icons.flag),
        labelText: 'Priority',
        border: InputBorder.none,
      ),
      initialValue: priorityToString(_priority),
      isExpanded: true,
      onChanged: (String? newValue) {
        _priority = priorityFromString(newValue);
        _checkChanged();
      },
      items: ['Unset', 'Low', 'Medium', 'High', 'Urgent', 'DO NOW'].map((
        String value,
      ) {
        return DropdownMenuItem(value: value, child: Text(value));
      }).toList(),
    );
  }

  Widget _buildAddLabel(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10.0, bottom: 10),
      child: Row(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 15, left: 2),
            child: Icon(Icons.label, color: Colors.grey),
          ),
          SizedBox(
            width:
                MediaQuery.of(context).size.width -
                80 -
                ((IconTheme.of(context).size ?? 0) * 2),
            child: TypeAheadField(
              //FIXME test compoonent - seems not to work as expected
              suggestionsCallback: (pattern) => _searchLabel(pattern),
              debounceDuration: Duration(seconds: 1),
              builder: (builder, controller, focusnode) {
                return TextFormField(
                  controller: _labelTypeAheadController,
                  focusNode: focusnode,
                  decoration: InputDecoration(
                    labelText: 'Add a new label',
                    border: InputBorder.none,
                  ),
                );
              },
              itemBuilder: (context, suggestion) {
                return ListTile(title: Text(suggestion.toString()));
              },
              onSelected: (suggestion) {
                _addLabel(suggestion.toString());
              },
            ),
          ),
          IconButton(
            onPressed: () => _createAndAddLabel(_labelTypeAheadController.text),
            icon: Icon(Icons.add),
          ),
        ],
      ),
    );
  }

  Widget _buildColor() {
    return Padding(
      padding: const EdgeInsets.only(top: 15),
      child: Row(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 15, left: 2),
            child: Icon(Icons.palette, color: Colors.grey),
          ),
          ElevatedButton(
            style: (_color == null || _color == Colors.black)
                ? null
                : ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (_) => _color,
                    ),
                  ),
            onPressed: _onColorEdit,
            child: Text(
              'Set Color',
              style: (_color == null || _color == Colors.black)
                  ? null
                  : TextStyle(
                      color: (_color)!.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 15),
            child: () {
              Color? color = (_color == null || _color == Colors.black)
                  ? null
                  : _color;

              return Text(
                color != null ? "#${color.toHexString()}" : "None",
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              );
            }(),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachments() {
    return ListView.separated(
      separatorBuilder: (context, index) => Divider(),
      padding: const EdgeInsets.all(16.0),
      shrinkWrap: true,
      itemCount: widget.task.attachments.length,
      itemBuilder: (context, index) {
        return ListTile(
          title: Text(widget.task.attachments[index].file.name),
          trailing: IconButton(
            icon: Icon(Icons.download),
            onPressed: () async {
              var taskId = await ref
                  .read(taskRepositoryProvider)
                  .downloadAttachment(
                    widget.task.id,
                    widget.task.attachments[index],
                  );
              if (taskId.status == TaskStatus.complete) {
                FileDownloader().openFile(task: taskId.task);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildLabelList() {
    return Wrap(
      spacing: 10,
      children:
          _labels?.map((label) {
            return LabelWidget(
              label: label,
              onDelete: () => _removeLabel(label),
            );
          }).toList() ??
          [],
    );
  }

  Future<List<String>> _searchLabel(String query) async {
    var labelsResponse = await ref
        .read(labelRepositoryProvider)
        .getAll(query: query);

    if (labelsResponse.isSuccessful) {
      var labels = labelsResponse.toSuccess().body;

      labels.removeWhere(
        (labelToRemove) => _labels?.contains(labelToRemove) == true,
      );
      _suggestedLabels = labels;

      return labels.map((e) => e.title).toList();
    }
    return [];
  }

  void _addLabel(String labelTitle) {
    var label = _suggestedLabels?.firstWhereOrNull(
      (e) => e.title == labelTitle,
    );

    if (label != null) {
      setState(() {
        _labels?.add(label);
        _labelTypeAheadController.clear();
      });
    }

    _checkChanged();
  }

  void _removeLabel(Label label) {
    setState(() {
      _labels?.removeWhere((l) => l.id == label.id);
    });
  }

  void _createAndAddLabel(String labelTitle) async {
    // Only add a label if there are none to add
    if (labelTitle.isEmpty ||
        _suggestedLabels?.firstWhereOrNull(
              (label) => label.title == labelTitle,
            ) !=
            null) {
      return;
    }

    final currentUser = ref.read(currentUserProvider);

    if (currentUser != null) {
      final newLabel = Label(title: labelTitle, createdBy: currentUser);

      ref.read(labelRepositoryProvider).create(newLabel).then((createdLabel) {
        if (createdLabel.isSuccessful) {
          setState(() {
            _labels?.add(createdLabel.toSuccess().body);
            _labelTypeAheadController.clear();
          });
        }
      });

      _checkChanged();
    }
  }

  Future<void> _addNewReminder(BuildContext context) async {
    var selectedDate = await showDialog<DateTime>(
      context: context,
      builder: (_) => DatePickerDialog(
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime(2100),
        initialCalendarMode: DatePickerMode.day,
      ),
    );

    if (selectedDate != null) {
      var selectedTime = await showDialog<TimeOfDay>(
        context: context,
        builder: (_) =>
            TimePickerDialog(initialTime: TimeOfDay.fromDateTime(selectedDate)),
      );

      if (selectedTime != null) {
        setState(() {
          _reminderDates?.add(
            TaskReminder(
              selectedDate.copyWith(
                hour: selectedTime.hour,
                minute: selectedTime.minute,
              ),
            ),
          );

          _checkChanged();
        });
      }
    }
  }

  void _onColorEdit() {
    var pickerColor = _color ?? Colors.black;
    showDialog(
      context: context,
      builder: (context) => ColorPickerDialog(
        pickerColor,
        (color) {
          if (color != Colors.black) {
            setState(() {
              _color = color;
            });
          } else {
            setState(() {
              _color = null;
            });
          }
          Navigator.of(context).pop();

          _checkChanged();
        },
        () {
          Navigator.of(context).pop();
        },
      ),
    );
  }

  Future<void> _showConfirmationDialog() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return TaskSaveDialog(
          onConfirm: () {
            Navigator.pop(context);
            Navigator.pop(context);
          },
          onCancel: () {
            Navigator.pop(context);
          },
        );
      },
    );
  }

  void _checkChanged() {
    setState(() {
      var repeatAfterValue =
          getRepeatAfterValueFromDuration(widget.task.repeatAfter) ?? 0;
      var repeatAfterType =
          getRepeatAfterTypeFromDuration(widget.task.repeatAfter) ?? "Days";

      var repeatAfter = getDurationFromType(repeatAfterValue, repeatAfterType);

      changed =
          widget.task.title != _title ||
          widget.task.description != _description ||
          widget.task.dueDate != _dueDate ||
          widget.task.startDate != _startDate ||
          widget.task.endDate != _endDate ||
          widget.task.repeatAfter != repeatAfter ||
          widget.task.priority != _priority ||
          widget.task.reminderDates != _reminderDates ||
          widget.task.labels != _labels ||
          widget.task.color != _color;
    });
  }

  Future<void> _saveTask(BuildContext context) async {
    // Removes all reminders with no value set.
    _reminderDates?.removeWhere((d) => d.reminder == DateTime(0));

    final updatedTask =
        widget.task.copyWith(
            title: _title,
            description: _description,
            reminderDates: _reminderDates,
            priority: _priority,
            labels: _labels,
            repeatAfter: getDurationFromType(
              _repeatAfterValue,
              _repeatAfterType,
            ),
          )
          //Need to be here as they can be null
          ..dueDate = _dueDate
          ..startDate = _startDate
          ..endDate = _endDate
          ..color = _color;

    // update the labels
    if (_labels != null) {
      var updateLabelSuccess = await ref
          .read(taskLabelBulkRepositoryProvider)
          .update(updatedTask, _labels!);

      if (!updateLabelSuccess.isSuccessful) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving the task!')));
        return;
      }
    }

    var saveSuccess = await ref
        .read(taskPageControllerProvider.notifier)
        .updateTask(updatedTask);
    if (saveSuccess) {
      Navigator.of(context).pop(updatedTask);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('The task was updated successfully!')),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving the task!')));
    }
  }
}

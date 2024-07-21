import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:vikunja_app/components/datetimePicker.dart';
import 'package:vikunja_app/components/label.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/label.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/utils/repeat_after_parse.dart';
import 'package:vikunja_app/utils/priority.dart';

import '../../stores/project_store.dart';
import '../task/edit_description.dart';

class TaskEditPage extends StatefulWidget {
  final Task task;
  final ProjectProvider taskState;

  TaskEditPage({
    required this.task,
    required this.taskState,
  }) : super(key: Key(task.toString()));

  @override
  State<StatefulWidget> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends State<TaskEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _listKey = GlobalKey();
  bool _loading = false;
  bool _changed = false;

  int? _priority;
  DateTime? _dueDate, _startDate, _endDate;
  late final List<TaskReminder> _reminderDates;
  String? _title, _description, _repeatAfterType;
  Duration? _repeatAfter;
  late final List<Label> _labels;
  // we use this to find the label object after a user taps on the suggestion, because the typeahead only uses strings, not full objects.
  List<Label>? _suggestedLabels;
  final _reminderInputs = <Widget>[];
  final _labelTypeAheadController = TextEditingController();
  Color? _color;
  Color? _pickerColor;
  bool _resetColor = false;

  @override
  void initState() {
    _repeatAfter = widget.task.repeatAfter;
    if (_repeatAfterType == null)
      _repeatAfterType = getRepeatAfterTypeFromDuration(_repeatAfter);

    _reminderDates = widget.task.reminderDates;
    for (var i = 0; i < _reminderDates.length; i++) {
      _reminderInputs.add(Padding(
        padding: EdgeInsets.symmetric(vertical: 10.0),
        child: VikunjaDateTimePicker(
          initialValue: _reminderDates[i].reminder,
          label: 'Reminder',
          onSaved: (reminder) {
            _reminderDates[i].reminder = reminder ?? DateTime(0);
            return null;
          },
        ),
      ));
    }

    _labels = widget.task.labels;
    _priority = widget.task.priority;
    _description = widget.task.description;

    super.initState();
  }

  @override
  Widget build(BuildContext ctx) {
    return WillPopScope(
      onWillPop: () {
        if (_changed) {
          return (_showConfirmationDialog());
        }
        return new Future(() => true);
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          appBar: AppBar(
            title: Text('Edit Task'),
            actions: [
              IconButton(
                icon: Icon(Icons.delete),
                onPressed: () {
                  showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text('Delete Task'),
                          content: Text(
                              'Are you sure you want to delete this task?'),
                          actions: [
                            TextButton(
                              child: Text('Cancel'),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            TextButton(
                              child: Text('Delete'),
                              onPressed: () {
                                _delete(widget.task.id);
                                Navigator.of(context).pop();
                              },
                            ),
                          ],
                        );
                      });
                },
              ),
            ],
          ),
          body: Builder(
            builder: (BuildContext context) => SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  key: _listKey,
                  padding: EdgeInsets.fromLTRB(
                      16, 16, 16, MediaQuery.of(context).size.height / 2),
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 10.0),
                      child: TextFormField(
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        initialValue: widget.task.title,
                        onSaved: (title) => _title = title,
                        onChanged: (_) => _changed = true,
                        validator: (title) {
                          //if (title.length < 3 || title.length > 250) {
                          //  return 'The title needs to have between 3 and 250 characters.';
                          //}
                          return null;
                        },
                        decoration: new InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    Padding(
                        padding: EdgeInsets.symmetric(vertical: 10.0),
                        child: GestureDetector(
                          onTap: () {
                            // open editdescription
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (buildContext) => EditDescription(
                                        initialText: _description,
                                      )),
                            ).then((description) => setState(() {
                                  if (description != null)
                                    _description = description;
                                  _changed = true;
                                }));
                          },
                          child: Row(
                            children: [
                              Padding(
                                  padding: EdgeInsets.only(right: 15, left: 2),
                                  child: Icon(
                                    Icons.description,
                                    color: Colors.grey,
                                  )),
                              Flexible(
                                child: HtmlWidget(_description != null
                                    ? _description!
                                    : "No description"),
                              ),
                            ],
                          ),
                        )),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 10.0),
                      child: VikunjaDateTimePicker(
                        icon: Icon(Icons.access_time),
                        label: 'Due Date',
                        initialValue: widget.task.dueDate,
                        onSaved: (duedate) => _dueDate = duedate,
                        onChanged: (_) => _changed = true,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 10.0),
                      child: VikunjaDateTimePicker(
                        label: 'Start Date',
                        initialValue: widget.task.startDate,
                        onSaved: (startDate) => _startDate = startDate,
                        onChanged: (_) => _changed = true,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 10.0),
                      child: VikunjaDateTimePicker(
                        label: 'End Date',
                        initialValue: widget.task.endDate,
                        onSaved: (endDate) => _endDate = endDate,
                        onChanged: (_) => _changed = true,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 10.0),
                      child: Row(
                        children: [
                          Flexible(
                            flex: 65,
                            child: TextFormField(
                              keyboardType: TextInputType.number,
                              initialValue:
                                  getRepeatAfterValueFromDuration(_repeatAfter)
                                      ?.toString(),
                              onSaved: (repeatAfter) => _repeatAfter =
                                  getDurationFromType(
                                      repeatAfter, _repeatAfterType),
                              onChanged: (_) => _changed = true,
                              decoration: new InputDecoration(
                                  labelText: 'Repeat after',
                                  border: InputBorder.none,
                                  icon: Icon(Icons.repeat),
                                  contentPadding:
                                      EdgeInsets.fromLTRB(0, 0, 0, 0)),
                            ),
                          ),
                          Spacer(),
                          Flexible(
                            flex: 30,
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding:
                                      EdgeInsets.fromLTRB(0, 0, 0, 0)),
                              isExpanded: true,
                              value: _repeatAfterType ??
                                  getRepeatAfterTypeFromDuration(_repeatAfter),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _repeatAfterType = newValue;
                                });
                              },
                              items: <String>[
                                'Hours',
                                'Days',
                                'Weeks',
                                'Months',
                                'Years'
                              ].map<DropdownMenuItem<String>>((String value) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(top: 15.0),
                      child: Column(
                        children: _reminderInputs,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: GestureDetector(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: <Widget>[
                                Padding(
                                    padding:
                                        EdgeInsets.only(right: 15, left: 2),
                                    child: Icon(
                                      Icons.alarm_add,
                                      color: Colors.grey,
                                    )),
                                Text(
                                  'Add a reminder',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          onTap: () {
                            _changed = true;
                            // We add a new entry every time we add a new input, to make sure all inputs have a place where they can put their value.
                            _reminderDates.add(TaskReminder(DateTime(0)));
                            var currentIndex = _reminderDates.length - 1;

                            // FIXME: Why does putting this into a row fail?
                            setState(() => _reminderInputs.add(
                                  VikunjaDateTimePicker(
                                    label: 'Reminder',
                                    onSaved: (reminder) =>
                                        _reminderDates[currentIndex].reminder =
                                            reminder ?? DateTime(0),
                                    onChanged: (_) => _changed = true,
                                    initialValue: DateTime.now(),
                                  ),
                                ));
                          }),
                    ),
                    new DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        icon: const Icon(Icons.flag),
                        labelText: 'Priority',
                        border: InputBorder.none,
                      ),
                      value: priorityToString(_priority),
                      isExpanded: true,
                      isDense: true,
                      onChanged: (String? newValue) {
                        setState(() {
                          _priority = priorityFromString(newValue);
                        });
                      },
                      items: [
                        'Unset',
                        'Low',
                        'Medium',
                        'High',
                        'Urgent',
                        'DO NOW'
                      ].map((String value) {
                        return new DropdownMenuItem(
                          value: value,
                          child: new Text(value),
                        );
                      }).toList(),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 10.0, bottom: 10),
                      child: Row(
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.only(right: 15, left: 2),
                            child: Icon(
                              Icons.label,
                              color: Colors.grey,
                            ),
                          ),
                          Container(
                            width: MediaQuery.of(context).size.width -
                                80 -
                                ((IconTheme.of(context).size ?? 0) * 2),
                            child: TypeAheadField(
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
                              suggestionsCallback: (pattern) =>
                                  _searchLabel(pattern),
                              itemBuilder: (context, suggestion) {
                                return new ListTile(
                                    title: Text(suggestion.toString()));
                              },
                              //transitionBuilder:
                              //    (context, suggestionsBox, controller) {
                              //  return suggestionsBox;
                              //},
                              onSelected: (suggestion) {
                                _addLabel(suggestion.toString());
                              },
                            ),
                          ),
                          IconButton(
                            onPressed: () => _createAndAddLabel(
                                _labelTypeAheadController.text),
                            icon: Icon(Icons.add),
                          )
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        Wrap(
                            spacing: 10,
                            children: _labels.map((Label label) {
                              return LabelComponent(
                                label: label,
                                onDelete: () {
                                  _removeLabel(label);
                                },
                              );
                            }).toList()),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: Row(
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.only(right: 15, left: 2),
                            child: Icon(
                              Icons.palette,
                              color: Colors.grey,
                            ),
                          ),
                          ElevatedButton(
                            child: Text(
                              'Set Color',
                              style: (_resetColor ||
                                      (_color ?? widget.task.color) == null)
                                  ? null
                                  : TextStyle(
                                      color: (_color ?? widget.task.color)!
                                                  .computeLuminance() >
                                              0.5
                                          ? Colors.black
                                          : Colors.white,
                                    ),
                            ),
                            style: _resetColor
                                ? null
                                : ButtonStyle(
                                    backgroundColor:
                                        WidgetStateProperty.resolveWith(
                                            (_) => _color ?? widget.task.color),
                                  ),
                            onPressed: _onColorEdit,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 15),
                            child: () {
                              String? colorString = (_resetColor
                                      ? null
                                      : (_color ?? widget.task.color))
                                  ?.toString();
                              colorString = colorString
                                  ?.substring(10, colorString.length - 1)
                                  .toUpperCase();
                              colorString = colorString != null
                                  ? '#$colorString'
                                  : 'None';
                              return Text(
                                '$colorString',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              );
                            }(),
                          ),
                        ],
                      ),
                    ),
                    ListView.separated(
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
                              String url =
                                  VikunjaGlobal.of(context).client.base;
                              url +=
                                  '/tasks/${widget.task.id}/attachments/${widget.task.attachments[index].id}';
                              print(url);
                              final taskId = await FlutterDownloader.enqueue(
                                url: url,
                                fileName:
                                    widget.task.attachments[index].file.name,
                                headers: VikunjaGlobal.of(context)
                                    .client
                                    .headers, // optional: header send with url (auth token etc)
                                savedDir: '/storage/emulated/0/Download/',
                                showNotification:
                                    true, // show download progress in status bar (for Android)
                                openFileFromNotification:
                                    true, // click on notification to open downloaded file (for Android)
                              );
                              if (taskId == null) return;
                              FlutterDownloader.open(taskId: taskId);
                            },
                          ),
                        );
                      },
                    )
                  ],
                ),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: !_loading
                ? () {
                    if (_formKey.currentState!.validate()) {
                      Form.of(_listKey.currentContext!).save();
                      _saveTask(_listKey.currentContext!);
                    }
                  }
                : null,
            child: Icon(Icons.save),
          ),
        ),
      ),
    );
  }

  _saveTask(BuildContext context) async {
    setState(() => _loading = true);

    // Removes all reminders with no value set.
    _reminderDates.removeWhere((d) => d.reminder == DateTime(0));

    final updatedTask = widget.task.copyWith(
      title: _title,
      description: _description,
      reminderDates: _reminderDates,
      priority: _priority,
      labels: _labels,
      repeatAfter: _repeatAfter,
    )
      ..dueDate = _dueDate
      ..startDate = _startDate
      ..endDate = _endDate
      ..color = _resetColor ? null : (_color ?? widget.task.color)
      ..repeatAfter = _repeatAfter;

    // update the labels
    await VikunjaGlobal.of(context)
        .labelTaskBulkService
        .update(updatedTask, _labels)
        .catchError((err) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Something went wrong: ' + err.toString()),
        ),
      );
    });

    widget.taskState
        .updateTask(
      context: context,
      task: updatedTask,
    )
        .then((task) {
      setState(() {
        _loading = false;
        _changed = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('The task was updated successfully!'),
      ));
      Navigator.of(context).pop(task);
    }).catchError((err) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Something went wrong: ' + err.toString()),
          action: SnackBarAction(
              label: 'CLOSE',
              onPressed: ScaffoldMessenger.of(context).hideCurrentSnackBar),
        ),
      );
    });
  }

  _removeLabel(Label label) {
    setState(() {
      _labels.removeWhere((l) => l.id == label.id);
    });
  }

  _delete(int taskId) {
    VikunjaGlobal.of(context).taskService.delete(taskId);
    Navigator.pop(context);
  }

  _searchLabel(String query) {
    return VikunjaGlobal.of(context)
        .labelService
        .getAll(query: query)
        .then((labels) {
      // Only show those labels which aren't already added to the task
      if (labels == null) return [];
      labels.removeWhere((labelToRemove) => _labels.contains(labelToRemove));
      _suggestedLabels = labels;
      List<String?> labelText = labels.map((label) => label.title).toList();
      return labelText;
    });
  }

  _addLabel(String labelTitle) {
    // FIXME: This is not an optimal solution...
    bool found = false;
    _suggestedLabels?.forEach((label) {
      if (label.title == labelTitle) {
        _labels.add(label);
        found = true;
      }
    });

    if (found) {
      _labelTypeAheadController.clear();
    }
    setState(() {});
  }

  void _createAndAddLabel(String labelTitle) {
    // Only add a label if there are none to add
    if (labelTitle.isEmpty || (_suggestedLabels?.isNotEmpty ?? false)) {
      return;
    }

    final currentUser = VikunjaGlobal.of(context).currentUser;
    if (currentUser == null) {
      return;
    }

    final newLabel = Label(
      title: labelTitle,
      createdBy: currentUser,
    );
    VikunjaGlobal.of(context)
        .labelService
        .create(newLabel)
        .then((createdLabel) {
      if (createdLabel == null) return null;
      setState(() {
        _labels.add(createdLabel);
        _labelTypeAheadController.clear();
      });
    });
  }

  _onColorEdit() {
    _pickerColor = _resetColor || (_color ?? widget.task.color) == null
        ? Colors.black
        : _color ?? widget.task.color;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Task Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: _pickerColor!,
            enableAlpha: false,
            labelTypes: const [ColorLabelType.hsl, ColorLabelType.rgb],
            paletteType: PaletteType.hslWithLightness,
            hexInputBar: true,
            onColorChanged: (color) => setState(() => _pickerColor = color),
          ),
        ),
        actions: <TextButton>[
          TextButton(
            child: Text('CANCEL'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text('RESET'),
            onPressed: () {
              setState(() {
                _color = null;
                _resetColor = true;
                _changed = _color != widget.task.color;
              });
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: Text('OK'),
            onPressed: () {
              if (_pickerColor != Colors.black)
                setState(() {
                  _color = _pickerColor;
                  _resetColor = false;
                  _changed = _color != widget.task.color;
                });
              else
                setState(() {
                  _color = null;
                  _resetColor = true;
                  _changed = _color != widget.task.color;
                });
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('You have unsaved changes!'),
              content: SingleChildScrollView(
                child: Column(
                  children: <Widget>[
                    Text('Would you like to dismiss those changes?'),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: Text('Dismiss'),
                  onPressed: () {
                    Navigator.pop(context);
                    // make sure the list is refreshed
                    Navigator.pop(context);
                  },
                ),
                TextButton(
                  child: Text('Keep editing'),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            );
          },
        ) ??
        false;
  }
}

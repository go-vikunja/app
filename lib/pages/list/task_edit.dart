import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:vikunja_app/components/datetimePicker.dart';
import 'package:vikunja_app/components/label.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/label.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/utils/repeat_after_parse.dart';

class TaskEditPage extends StatefulWidget {
  final Task task;

  TaskEditPage({this.task}) : super(key: Key(task.toString()));

  @override
  State<StatefulWidget> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends State<TaskEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _listKey = GlobalKey();
  bool _loading = false;
  bool _changed = false;

  int _priority;
  DateTime _dueDate, _startDate, _endDate;
  List<DateTime> _reminderDates;
  String _title, _description, _repeatAfterType;
  Duration _repeatAfter;
  List<Label> _labels;
  // we use this to find the label object after a user taps on the suggestion, because the typeahead only uses strings, not full objects.
  List<Label> _suggestedLabels;
  var _reminderInputs = <Widget>[];
  final _labelTypeAheadController = TextEditingController();
  Color _color;
  Color _pickerColor;
  bool _resetColor = false;

  @override
  Widget build(BuildContext ctx) {
    // This builds the initial list of reminder inputs only once.
    if (_reminderDates == null) {
      _reminderDates = widget.task.reminderDates ?? [];

      _reminderDates?.asMap()?.forEach((i, time) =>
          setState(() => _reminderInputs?.add(VikunjaDateTimePicker(
            initialValue: time,
            label: 'Reminder',
            onSaved: (reminder) => _reminderDates[i] = reminder,
          )))
      );
    }

    if (_labels == null) {
      _labels = widget.task.labels ?? [];
    }

    return WillPopScope(
      onWillPop: () {
        if(_changed) {
          return _showConfirmationDialog();
        }
        return new Future(() => true);
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          appBar: AppBar(
            title: Text('Edit Task'),
          ),
          body: Builder(
            builder: (BuildContext context) => SafeArea(
              child: Form(
                key: _formKey,
                child: ListView(
                  key: _listKey,
                  padding: const EdgeInsets.all(16.0),
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
                          if (title.length < 3 || title.length > 250) {
                            return 'The title needs to have between 3 and 250 characters.';
                          }
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
                      child: TextFormField(
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        initialValue: widget.task.description,
                        onSaved: (description) => _description = description,
                        onChanged: (_) => _changed = true,
                        validator: (description) {
                          if (description.length > 1000) {
                            return 'The description can have a maximum of 1000 characters.';
                          }
                          return null;
                        },
                        decoration: new InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    VikunjaDateTimePicker(
                      icon: Icon(Icons.access_time),
                      label: 'Due Date',
                      initialValue: widget.task.dueDate,
                      onSaved: (duedate) => _dueDate = duedate,
                      onChanged: (_) => _changed = true,
                    ),
                    VikunjaDateTimePicker(
                      label: 'Start Date',
                      initialValue: widget.task.startDate,
                      onSaved: (startDate) => _startDate = startDate,
                      onChanged: (_) => _changed = true,
                    ),
                    VikunjaDateTimePicker(
                      label: 'End Date',
                      initialValue: widget.task.endDate,
                      onSaved: (endDate) => _endDate = endDate,
                      onChanged: (_) => _changed = true,
                    ),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            keyboardType: TextInputType.number,
                            initialValue: getRepeatAfterValueFromDuration(
                                widget.task.repeatAfter)?.toString(),
                            onSaved: (repeatAfter) => _repeatAfter =
                                getDurationFromType(repeatAfter, _repeatAfterType),
                            onChanged: (_) => _changed = true,
                            decoration: new InputDecoration(
                              labelText: 'Repeat after',
                              border: InputBorder.none,
                              icon: Icon(Icons.repeat),
                            ),
                          ),
                        ),
                        Expanded(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            isDense: true,
                            value: _repeatAfterType ??
                                getRepeatAfterTypeFromDuration(
                                    widget.task.repeatAfter),
                            onChanged: (String newValue) {
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
                    Column(
                      children: _reminderInputs,
                    ),
                    GestureDetector(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: <Widget>[
                              Padding(
                                  padding: EdgeInsets.only(right: 15, left: 2),
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
                          // We add a new entry every time we add a new input, to make sure all inputs have a place where they can put their value.
                          _reminderDates.add(null);
                          var currentIndex = _reminderDates.length - 1;

                          // FIXME: Why does putting this into a row fails?
                          setState(() => _reminderInputs.add(
                            VikunjaDateTimePicker(
                              label: 'Reminder',
                              onSaved: (reminder) =>
                              _reminderDates[currentIndex] = reminder,
                              onChanged: (_) => _changed = true,
                              initialValue: DateTime.now(),
                            ),
                          ));
                        }),
                    InputDecorator(
                      isEmpty: _priority == null,
                      decoration: InputDecoration(
                        icon: const Icon(Icons.flag),
                        labelText: 'Priority',
                        border: InputBorder.none,
                      ),
                      child: new DropdownButton<String>(
                        value: _priorityToString(_priority),
                        isExpanded: true,
                        isDense: true,
                        onChanged: (String newValue) {
                          setState(() {
                            _priority = _priorityFromString(newValue);
                          });
                        },
                        items: ['Unset', 'Low', 'Medium', 'High', 'Urgent', 'DO NOW']
                            .map((String value) {
                          return new DropdownMenuItem(
                            value: value,
                            child: new Text(value),
                          );
                        }).toList(),
                      ),
                    ),
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
                    Row(
                      children: <Widget>[
                        Container(
                          width: MediaQuery.of(context).size.width - 80,
                          child: TypeAheadFormField(
                            textFieldConfiguration: TextFieldConfiguration(
                                controller: _labelTypeAheadController,
                                decoration:
                                InputDecoration(labelText: 'Add a new label')),
                            suggestionsCallback: (pattern) => _searchLabel(pattern),
                            itemBuilder: (context, suggestion) {
                              return Text(suggestion);
                            },
                            transitionBuilder: (context, suggestionsBox, controller) {
                              return suggestionsBox;
                            },
                            onSuggestionSelected: (suggestion) {
                              _addLabel(suggestion);
                            },
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              _createAndAddLabel(_labelTypeAheadController.text),
                          icon: Icon(Icons.add),
                        )
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
                              'Color',
                              style: _resetColor || (_color ?? widget.task.color) == null ? null : TextStyle(
                                color: (_color ?? widget.task.color)
                                    .computeLuminance() > 0.5 ? Colors.black : Colors.white,
                              ),
                            ),
                            style: _resetColor ? null : ButtonStyle(
                              backgroundColor: MaterialStateProperty
                                  .resolveWith((_) => _color ?? widget.task.color),
                            ),
                            onPressed: _onColorEdit,
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 15),
                            child: () {
                              String colorString = (_resetColor ? null : (_color ?? widget.task.color))?.toString();
                              colorString = colorString?.substring(10, colorString.length - 1)?.toUpperCase();
                              colorString = colorString != null ? '#$colorString' : 'None';
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
                  ],
                ),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: !_loading ? () {
              if (_formKey.currentState.validate()) {
                Form.of(_listKey.currentContext).save();
                _saveTask(_listKey.currentContext);
              }
            } : null,
            child: Icon(Icons.save),
          ),
        ),
      ),
    );
  }

  _saveTask(BuildContext context) async {
    setState(() => _loading = true);

    // Removes all reminders with no value set.
    _reminderDates.removeWhere((d) => d == null);

    Task updatedTask = widget.task.copyWith(
      title: _title,
      description: _description,
      reminderDates: _reminderDates,
      dueDate: _dueDate,
      startDate: _startDate,
      endDate: _endDate,
      priority: _priority,
      repeatAfter: _repeatAfter,
      color: _resetColor ? null : (_color ?? widget.task.color),
      resetColor: _resetColor,
    );

    // update the labels
    VikunjaGlobal.of(context)
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

    VikunjaGlobal.of(context).taskService.update(updatedTask).then((result) {
      setState(() { _loading = false; _changed = false;});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('The task was updated successfully!'),
      ));
      Navigator.of(context).pop(result);
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

  _searchLabel(String query) {
    return VikunjaGlobal.of(context)
        .labelService.getAll(query: query).then((labels) {
          log("searched");
          // Only show those labels which aren't already added to the task
          labels.removeWhere((labelToRemove) => _labels.contains(labelToRemove));
          _suggestedLabels = labels;
          return labels.map((label) => label.title).toList();
        });
  }

  _addLabel(String labelTitle) {
    // FIXME: This is not an optimal solution...
    bool found = false;
    _suggestedLabels.forEach((label) {
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

  _createAndAddLabel(String labelTitle) {
    // Only add a label if there are none to add
    if (labelTitle.isEmpty || (_suggestedLabels?.isNotEmpty ?? false)) {
      return;
    }

    Label newLabel = Label(title: labelTitle);
    VikunjaGlobal.of(context)
        .labelService
        .create(newLabel)
        .then((createdLabel) {
      setState(() {
        _labels.add(createdLabel);
        _labelTypeAheadController.clear();
      });
    });
  }

  // FIXME: Move the following two functions to an extra class or type.
  _priorityFromString(String priority) {
    switch (priority) {
      case 'Low':
        return 1;
      case 'Medium':
        return 2;
      case 'High':
        return 3;
      case 'Urgent':
        return 4;
      case 'DO NOW':
        return 5;
      default:
        // unset
        return 0;
    }
  }

  _priorityToString(int priority) {
    switch (priority) {
      case 0:
        return 'Unset';
      case 1:
        return 'Low';
      case 2:
        return 'Medium';
      case 3:
        return 'High';
      case 4:
        return 'Urgent';
      case 5:
        return 'DO NOW';
      default:
        return null;
    }
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
            pickerColor: _pickerColor,
            enableAlpha: false,
            labelTypes: const [ColorLabelType.hsl, ColorLabelType.rgb],
            paletteType: PaletteType.hslWithLightness,
            hexInputBar: true,
            onColorChanged: (color) => setState(() => _pickerColor = color),
          ),
        ),
        actions: <TextButton>[
          TextButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text('Reset'),
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
            child: Text('Ok'),
            onPressed: () {
              if (_pickerColor != Colors.black) setState(() {
                _color = _pickerColor;
                _resetColor = false;
                _changed = _color != widget.task.color;
              });
              else setState(() {
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
    return showDialog<bool>(
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
    );
  }
}

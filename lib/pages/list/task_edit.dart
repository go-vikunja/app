import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:vikunja_app/components/datetimePicker.dart';
import 'package:vikunja_app/components/label.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/label.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/theme/button.dart';
import 'package:vikunja_app/theme/buttonText.dart';
import 'package:vikunja_app/utils/repeat_after_parse.dart';

class TaskEditPage extends StatefulWidget {
  final Task task;

  TaskEditPage({this.task}) : super(key: Key(task.toString()));

  @override
  State<StatefulWidget> createState() => _TaskEditPageState();
}

class _TaskEditPageState extends State<TaskEditPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

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
              ))));
    }

    if (_labels == null) {
      _labels = widget.task.labels ?? [];
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Task'),
      ),
      body: Builder(
        builder: (BuildContext context) => SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(padding: const EdgeInsets.all(16.0), children: <
                Widget>[
              Padding(
                padding: EdgeInsets.symmetric(vertical: 10.0),
                child: TextFormField(
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  initialValue: widget.task.title,
                  onSaved: (title) => _title = title,
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
              ),
              VikunjaDateTimePicker(
                label: 'Start Date',
                initialValue: widget.task.startDate,
                onSaved: (startDate) => _startDate = startDate,
              ),
              VikunjaDateTimePicker(
                label: 'End Date',
                initialValue: widget.task.endDate,
                onSaved: (endDate) => _endDate = endDate,
              ),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      keyboardType: TextInputType.number,
                      initialValue: getRepeatAfterValueFromDuration(
                              widget.task.repeatAfter)
                          ?.toString(),
                      onSaved: (repeatAfter) => _repeatAfter =
                          getDurationFromType(repeatAfter, _repeatAfterType),
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
                    setState(() => _reminderInputs.add(Row(
                          children: <Widget>[
                            VikunjaDateTimePicker(
                              label: 'Reminder',
                              onSaved: (reminder) =>
                                  _reminderDates[currentIndex] = reminder,
                            ),
                            GestureDetector(
                              onTap: () => print('tapped'),
                              child: Icon(Icons.close),
                            )
                          ],
                        )));
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
                      suggestionsCallback: (pattern) {
                        return _searchLabel(pattern);
                      },
                      itemBuilder: (context, suggestion) {
                        return ListTile(
                          title: Text(suggestion),
                        );
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
              Builder(
                  builder: (context) => Padding(
                      padding: EdgeInsets.symmetric(vertical: 10.0),
                      child: FancyButton(
                        onPressed: !_loading
                            ? () {
                                if (_formKey.currentState.validate()) {
                                  Form.of(context).save();
                                  _saveTask(context);
                                }
                              }
                            : null,
                        child: _loading
                            ? CircularProgressIndicator()
                            : VikunjaButtonText('Save'),
                      ))),
            ]),
          ),
        ),
      ),
    );
  }

  _saveTask(BuildContext context) async {
    setState(() => _loading = true);

    // Removes all reminders with no value set.
    _reminderDates.removeWhere((d) => d == null);

    Task updatedTask = Task(
      id: widget.task.id,
      title: _title,
      description: _description,
      done: widget.task.done,
      reminderDates: _reminderDates,
      createdBy: widget.task.createdBy,
      dueDate: _dueDate,
      startDate: _startDate,
      endDate: _endDate,
      priority: _priority,
      repeatAfter: _repeatAfter,
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

    VikunjaGlobal.of(context).taskService.update(updatedTask).then((_) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('The task was updated successfully!'),
      ));
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
        .labelService
        .getAll(query: query)
        .then((labels) {
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
}

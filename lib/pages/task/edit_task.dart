/*
import 'dart:developer';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/task.dart';
import 'package:vikunja_app/theme/button.dart';
import 'package:vikunja_app/theme/buttonText.dart';

class TaskEditPage extends StatefulWidget {
  final Task task;

  TaskEditPage({this.task}) : super(key: Key(task.toString()));

  @override
  State<StatefulWidget> createState() => _TaskEditPageState();
}



class _TaskEditPageState extends State<TaskEditPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String _title, _description;
  bool _done;
  bool changed = false;
  DateTime _due;
  TextEditingController titleController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();

  @override
  void initState() {
    log("In init state: " + widget.task.dueDate.toIso8601String());
      titleController.text = widget.task.title;
    descriptionController.text = widget.task.description;
    _done = widget.task.done;
    _due = widget.task.dueDate;
    super.initState();
  }

  @override
  Widget build(BuildContext ctx) {
    return WillPopScope(onWillPop: () {
      if(changed) {
        return _showConfirmationDialog();
      }
      return Future(() => true);
    },
    child: Scaffold(
      appBar: AppBar(
        title: Text('Edit Task'),
      ),
      body: Builder(
        builder: (BuildContext context) => SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.0),
                    child: TextFormField(
                      controller: titleController,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      onSaved: (title) {_title = title; changed = true;},
                      validator: (name) {
                        if (name.length < 3 || name.length > 250) {
                          return 'The name needs to have between 3 and 250 characters.';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.0),
                    child: TextFormField(
                      controller: descriptionController,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      onSaved: (description) {_description = description; changed = true;},
                      validator: (description) {
                        if (description.length > 1000) {
                          return 'The description can have a maximum of 1000 characters.';
                        }
                        return null;
                      },
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Padding(
                      padding: EdgeInsets.symmetric(vertical: 10.0),
                      child: CheckboxListTile(
                          controlAffinity: ListTileControlAffinity.leading,
                          title: const Text("Done"),
                          value: _done,
                          onChanged: (done) {
                            setState(() {
                            _done = done;
                            changed = true;
                            });
                          }),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Text(DateFormat('dd/MM/yy hh:mm a').format(_due).toString()),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
                              child: FancyButton(
                            child: const VikunjaButtonText("Pick Due Date"),
                            onPressed: () => _showDatePicker(context),
                      )))],
                    )
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
                  Builder(
                      builder: (context) => Padding(
                          padding: EdgeInsets.symmetric(vertical: 10.0),
                          child: FancyButton(
                            onPressed: () {_deleteTask(context);},
                            child:  VikunjaButtonText('Delete'),
                          ))),
                ]),
          ),
        ),
      ),
    )
    );
  }

  _showDatePicker(context) async {
    DateTime date = await showDialog(
        context: context,
        builder: (_) => DatePickerDialog(
          initialDate: _due.year > 1 ? _due : DateTime.now(),
          firstDate: DateTime(0),
          lastDate: DateTime(9999),
          initialCalendarMode: DatePickerMode.day,
    ));
    TimeOfDay time = await showDialog(
            context: context,
            builder: (_) => TimePickerDialog(
                initialTime: TimeOfDay.fromDateTime(_due),
            )
        );
    if(date != null && time != null)
      setState(() {
        _due = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      });
  }

  _deleteTask(BuildContext context) async {
    await VikunjaGlobal.of(context).taskService.delete(widget.task.id).then(
            (value) {
              navigatorKey.currentState?.pop(context);
            });
  }

  _saveTask(BuildContext context) async {
    setState(() => _loading = true);
    Task updatedTask = widget.task;
    updatedTask.title = _title;
    updatedTask.description = _description;
    updatedTask.done = _done;
    updatedTask.dueDate = _due.toUtc();

    VikunjaGlobal.of(context)
        .taskService
        .update(updatedTask)
        .then((_) {
      setState(()  {_loading = false; changed = false;});
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
                log("Dismiss");
                navigatorKey.currentState?.pop(context);
                // make sure the list is refreshed
                navigatorKey.currentState?.pop(context);
              },
            ),
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                log("cancel");
                navigatorKey.currentState?.pop(context);
              },
            ),
          ],
        );
      },
    );
  }
}
*/

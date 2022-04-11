import 'dart:developer';
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
  TextEditingController titleController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();

  @override
  void initState() {
    titleController.text = widget.task.title;
    descriptionController.text = widget.task.description;
    if(widget.task.done == null)
      widget.task.done = false;
    _done = widget.task.done;
    super.initState();
  }

  @override
  Widget build(BuildContext ctx) {
    return new WillPopScope(onWillPop: () {
      if(changed) {
        return _showConfirmationDialog();
      }
      return new Future(() => true);
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
                      decoration: new InputDecoration(
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
                      decoration: new InputDecoration(
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
    )
    );
  }

  _saveTask(BuildContext context) async {
    setState(() => _loading = true);
    Task updatedTask = widget.task;
    updatedTask.title = _title;
    updatedTask.description = _description;
    updatedTask.done = _done;

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
                Navigator.pop(context);
                // make sure the list is refreshed
                Navigator.pop(context);
              },
            ),
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                log("cancel");
                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }
}

import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/theme/button.dart';
import 'package:vikunja_app/theme/buttonText.dart';

import '../../models/project.dart';

class ProjectEditPage extends StatefulWidget {
  final Project project;

  ProjectEditPage({required this.project})
      : super(key: Key(project.toString()));

  @override
  State<StatefulWidget> createState() => _ProjectEditPageState();
}

class _ProjectEditPageState extends State<ProjectEditPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String _title = '', _description = '';
  bool? displayDoneTasks;
  late int listId;

  @override
  void initState() {
    listId = widget.project.id;
    super.initState();
  }

  @override
  Widget build(BuildContext ctx) {
    if (displayDoneTasks == null)
      VikunjaGlobal.of(context)
          .projectService
          .getDisplayDoneTasks(listId)
          .then((value) => setState(() => displayDoneTasks = value == "1"));
    else
      log("Display done tasks: " + displayDoneTasks.toString());
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Project'),
      ),
      body: Builder(
        builder: (BuildContext context) => SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
                //reverse: true,
                padding: const EdgeInsets.all(16.0),
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.0),
                    child: TextFormField(
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      initialValue: widget.project.title,
                      onSaved: (title) => _title = title ?? '',
                      validator: (title) {
                        //if (title?.length < 3 || title.length > 250) {
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
                    child: TextFormField(
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      initialValue: widget.project.description,
                      onSaved: (description) =>
                          _description = description ?? '',
                      validator: (description) {
                        if (description == null) return null;
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
                      value: displayDoneTasks ?? false,
                      title: Text("Show done tasks"),
                      onChanged: (value) {
                        value ??= false;
                        VikunjaGlobal.of(context)
                            .projectService
                            .setDisplayDoneTasks(listId, value ? "1" : "0");
                        setState(() => displayDoneTasks = value);
                      },
                    ),
                  ),
                  Builder(
                      builder: (context) => Padding(
                          padding: EdgeInsets.symmetric(vertical: 10.0),
                          child: FancyButton(
                            onPressed: !_loading
                                ? () {
                                    if (_formKey.currentState!.validate()) {
                                      Form.of(context).save();
                                      _saveList(context);
                                    }
                                  }
                                : () {},
                            child: _loading
                                ? CircularProgressIndicator()
                                : VikunjaButtonText('Save'),
                          ))),
                  /*ExpansionTile(
                    title: Text("Sharing"),
                    children: [
                      TypeAheadFormField(
                          onSuggestionSelected: (suggestion) {},
                          itemBuilder: (BuildContext context, Object? itemData) {
                            return Card(
                              child: Container(
                                  padding: EdgeInsets.all(10),
                                  child: Text(itemData.toString())),
                            );},
                          suggestionsCallback: (String pattern) {
                            List<String> matches = <String>[];
                            matches.addAll(["test", "test2", "test3"]);
                            matches.retainWhere((s){
                              return s.toLowerCase().contains(pattern.toLowerCase());
                            });
                            return matches;
                          },)
                    ],
                  )*/
                ]),
          ),
        ),
      ),
    );
  }

  _saveList(BuildContext context) async {
    setState(() => _loading = true);
    // FIXME: is there a way we can update the list without creating a new list object?
    //  aka updating the existing list we got from context (setters?)
    Project newProject =
        widget.project.copyWith(title: _title, description: _description);
    VikunjaGlobal.of(context).projectService.update(newProject).then((_) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('The project was updated successfully!'),
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
}

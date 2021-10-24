import 'package:flutter/material.dart';
import 'package:vikunja_app/global.dart';
import 'package:vikunja_app/models/list.dart';
import 'package:vikunja_app/theme/button.dart';
import 'package:vikunja_app/theme/buttonText.dart';

class ListEditPage extends StatefulWidget {
  final TaskList list;

  ListEditPage({this.list}) : super(key: Key(list.toString()));

  @override
  State<StatefulWidget> createState() => _ListEditPageState();
}

class _ListEditPageState extends State<ListEditPage> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String _title, _description;

  @override
  Widget build(BuildContext ctx) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit List'),
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
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      initialValue: widget.list.title,
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
                      initialValue: widget.list.description,
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
                  Builder(
                      builder: (context) => Padding(
                          padding: EdgeInsets.symmetric(vertical: 10.0),
                          child: FancyButton(
                            onPressed: !_loading
                                ? () {
                                    if (_formKey.currentState.validate()) {
                                      Form.of(context).save();
                                      _saveList(context);
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

  _saveList(BuildContext context) async {
    setState(() => _loading = true);
    // FIXME: is there a way we can update the list without creating a new list object?
    //  aka updating the existing list we got from context (setters?)
    TaskList updatedList =
        TaskList(id: widget.list.id, title: _title, description: _description);

    VikunjaGlobal.of(context).listService.update(updatedList).then((_) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('The list was updated successfully!'),
      ));
    }).catchError((err) {
      setState(() => _loading = false);
      ScaffoldMessengerState scaffoldState = ScaffoldMessenger.of(context);
      scaffoldState.showSnackBar(
        SnackBar(
          content: Text('Something went wrong: ' + err.toString()),
          action: SnackBarAction(
              label: 'CLOSE',
              onPressed: (() => scaffoldState.hideCurrentSnackBar(
                  reason: SnackBarClosedReason.action))),
        ),
      );
    });
  }
}
